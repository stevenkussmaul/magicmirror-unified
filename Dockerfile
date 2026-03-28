# Start with official Node.js Engine
FROM node:24-bookworm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    git \
    tini \
    curl \
    procps \
    ca-certificates \
    nano \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install PM2 globally (manages both MagicMirror and MMPM processes)
RUN npm install -g pm2

# Install MMPM globally
RUN pip3 install mmpm --break-system-packages

# Define working directory and paths
ARG APP_PATH=/opt/magicmirror
ENV MAGICMIRROR_ROOT=$APP_PATH
ENV MMPM_MAGICMIRROR_ROOT=$APP_PATH
WORKDIR $MAGICMIRROR_ROOT

# Clone MagicMirror and install dependencies
RUN git clone https://github.com/MagicMirrorOrg/MagicMirror . && \
    npm install --no-audit --no-fund

# Create staging directories for the startup script
RUN mkdir -p /opt/mm_defaults/config \
             /opt/mm_defaults/css \
             /opt/mm_defaults/modules

# Copy built-in defaults into the staging area
RUN cp -r $MAGICMIRROR_ROOT/config/* /opt/mm_defaults/config/ && \
    cp -r $MAGICMIRROR_ROOT/css/* /opt/mm_defaults/css/ && \
    cp -r $MAGICMIRROR_ROOT/modules/* /opt/mm_defaults/modules/

# Clone the MMM-mmpm module into staging and install its dependencies
RUN git clone https://github.com/Bee-Mar/MMM-mmpm.git /opt/mm_defaults/modules/MMM-mmpm && \
    cd /opt/mm_defaults/modules/MMM-mmpm && npm install --no-audit --no-fund

# --- AUTOMATING THE CONFIG.JS SETTINGS ---
# 1. Update the Address and clear the IP Whitelist
RUN sed -i 's/address: "localhost"/address: "0.0.0.0"/' /opt/mm_defaults/config/config.js.sample && \
    sed -i 's/ipWhitelist: \[.*\]/ipWhitelist: \[\]/' /opt/mm_defaults/config/config.js.sample

# 2. Inject the MMM-mmpm module configuration
RUN printf "        {\n            module: \"MMM-mmpm\",\n            position: \"top_center\"\n        },\n" > /tmp/mmpm_config.txt && \
    sed -i '/modules: \[/r /tmp/mmpm_config.txt' /opt/mm_defaults/config/config.js.sample && \
    rm /tmp/mmpm_config.txt
# ------------------------------------------

# Setup TrueNAS apps user (UID/GID 568)
RUN groupadd -g 568 apps && \
    useradd -u 568 -g 568 -m -s /bin/bash apps

# Create the MMPM config directory
RUN mkdir -p /home/apps/.config/mmpm/log

# Copy the default MMPM environment config
COPY mmpm-env.json /opt/mmpm/mmpm-env.json

# Copy the PM2 ecosystem config and service scripts
COPY ecosystem.config.js /opt/mmpm/ecosystem.config.js
COPY pm2-scripts/ /opt/mmpm/
RUN chmod +x /opt/mmpm/*.sh

# Copy the startup and health check scripts
COPY start.sh /opt/start.sh
COPY health.sh /opt/health.sh
RUN chmod +x /opt/start.sh /opt/health.sh

# Transfer ownership of ALL application and staging files to apps user
RUN chown -R apps:apps $MAGICMIRROR_ROOT /opt/mm_defaults /opt/mmpm /opt/start.sh /opt/health.sh /home/apps

# Drop privileges: Lock the container to apps user
USER apps:apps

EXPOSE 8080 7890 7891 6789 8907

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 CMD /opt/health.sh

# Use tini as PID 1 for proper signal handling and zombie reaping
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/opt/start.sh"]
