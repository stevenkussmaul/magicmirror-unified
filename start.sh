#!/bin/bash

# ==========================================
# MagicMirror + MMPM Unified Startup Script
# ==========================================
# This script runs every time the container starts.
# On first boot, it initializes the mounted volumes
# with default files. On every boot, it ensures MMPM
# is configured and starts all services via PM2.
# ==========================================

echo "=========================================="
echo "  MagicMirror + MMPM Container Starting"
echo "=========================================="

# ------------------------------------------
# Define paths
# ------------------------------------------
MM_ROOT="${MAGICMIRROR_ROOT:-/opt/magicmirror}"
MM_DEFAULTS="/opt/mm_defaults"
MMPM_CONFIG_DIR="/home/mmuser/.config/mmpm"
MMPM_ENV="$MMPM_CONFIG_DIR/mmpm-env.json"

# Locate MMPM's static UI files from the installed package
MMPM_UI_DIR=$(python3 -c "import mmpm, os; print(os.path.join(os.path.dirname(mmpm.__file__), 'ui'))")

echo "MagicMirror Root: $MM_ROOT"
echo "MMPM Config Dir:  $MMPM_CONFIG_DIR"
echo "MMPM UI Dir:      $MMPM_UI_DIR"
echo "------------------------------------------"

# ------------------------------------------
# 1. Initialize Config Directory
# ------------------------------------------
if [ ! -f "$MM_ROOT/config/config.js" ]; then
    echo "[INIT] First boot detected: config.js not found."
    echo "[INIT] Populating config directory from defaults..."

    cp -r "$MM_DEFAULTS"/config/* "$MM_ROOT"/config/
    cp "$MM_ROOT"/config/config.js.sample "$MM_ROOT"/config/config.js

    echo "[INIT] Config directory initialized!"
else
    echo "[OK] config.js found. Skipping config initialization."
fi

# ------------------------------------------
# 2. Initialize CSS Directory
# ------------------------------------------
if [ -z "$(ls -A "$MM_ROOT"/css 2>/dev/null)" ]; then
    echo "[INIT] First boot detected: CSS directory is empty."
    echo "[INIT] Populating CSS directory from defaults..."

    cp -r "$MM_DEFAULTS"/css/* "$MM_ROOT"/css/

    echo "[INIT] CSS directory initialized!"
else
    echo "[OK] CSS directory is populated. Skipping CSS initialization."
fi

# ------------------------------------------
# 3. Initialize Modules Directory
# ------------------------------------------
if [ ! -d "$MM_ROOT/modules/default" ]; then
    echo "[INIT] First boot detected: Default modules not found."
    echo "[INIT] Populating modules directory from defaults..."

    cp -r "$MM_DEFAULTS"/modules/* "$MM_ROOT"/modules/

    echo "[INIT] Modules directory initialized!"
else
    echo "[OK] Default modules found. Skipping module initialization."
fi

# ------------------------------------------
# 4. Verify MMM-mmpm Module
# ------------------------------------------
if [ ! -d "$MM_ROOT/modules/MMM-mmpm" ]; then
    echo "[WARN] MMM-mmpm module is missing!"
    echo "[INIT] Restoring MMM-mmpm module from defaults..."

    cp -r "$MM_DEFAULTS"/modules/MMM-mmpm "$MM_ROOT"/modules/MMM-mmpm

    echo "[INIT] MMM-mmpm module restored!"
else
    echo "[OK] MMM-mmpm module found."
fi

# ------------------------------------------
# 5. Initialize MMPM Config (first boot)
# ------------------------------------------
if [ ! -f "$MMPM_ENV" ]; then
    echo "[INIT] First boot detected: mmpm-env.json not found."
    echo "[INIT] Copying default MMPM config..."
    mkdir -p "$MMPM_CONFIG_DIR"/log
    cp /opt/mmpm/mmpm-env.json "$MMPM_ENV"
    echo "[INIT] MMPM config initialized!"
else
    echo "[OK] mmpm-env.json found."
fi

# ------------------------------------------
# 6. Configure MMPM Docker Flag
# ------------------------------------------
if grep -q '"MMPM_IS_DOCKER_IMAGE": true' "$MMPM_ENV"; then
    echo "[OK] MMPM_IS_DOCKER_IMAGE already set to true."
else
    echo "[INIT] Setting MMPM_IS_DOCKER_IMAGE to true..."
    sed -i -r 's|"MMPM_IS_DOCKER_IMAGE": .*|"MMPM_IS_DOCKER_IMAGE": true,|g' "$MMPM_ENV"
fi

# ------------------------------------------
# 7. Configure PM2 Process Name
# ------------------------------------------
if grep -q '"MMPM_MAGICMIRROR_PM2_PROCESS_NAME": "magicmirror"' "$MMPM_ENV"; then
    echo "[OK] MMPM_MAGICMIRROR_PM2_PROCESS_NAME already set."
else
    echo "[INIT] Setting MMPM_MAGICMIRROR_PM2_PROCESS_NAME..."
    sed -i -r 's|"MMPM_MAGICMIRROR_PM2_PROCESS_NAME": .*|"MMPM_MAGICMIRROR_PM2_PROCESS_NAME": "magicmirror",|g' "$MMPM_ENV"
fi

echo "[INFO] Current MMPM config:"
cat "$MMPM_ENV"
echo ""

# ------------------------------------------
# 8. Symlink MMPM UI directory for PM2
# ------------------------------------------
# PM2 needs a stable path for the UI static files.
# Create a symlink so the ecosystem config doesn't
# need to know the Python version-specific path.
if [ ! -L /tmp/mmpm-ui ] || [ "$(readlink /tmp/mmpm-ui)" != "$MMPM_UI_DIR" ]; then
    ln -sfn "$MMPM_UI_DIR" /tmp/mmpm-ui
    echo "[INIT] Symlinked MMPM UI: /tmp/mmpm-ui -> $MMPM_UI_DIR"
else
    echo "[OK] MMPM UI symlink is correct."
fi

# ------------------------------------------
# 9. Start all services via PM2
# ------------------------------------------
echo "=========================================="
echo "  All checks passed. Starting services!"
echo "=========================================="

# pm2-runtime keeps the container alive and forwards
# signals for graceful shutdown. It starts all apps
# defined in the ecosystem config.
exec pm2-runtime /opt/mmpm/ecosystem.config.js
