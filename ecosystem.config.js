module.exports = {
    apps: [
        {
            name: "magicmirror",
            cwd: process.env.MAGICMIRROR_ROOT || "/opt/magicmirror",
            script: "./serveronly",
            watch: false,
        },
        {
            name: "mmpm-api",
            script: "/opt/mmpm/start-api.sh",
            interpreter: "/bin/bash",
            watch: false,
        },
        {
            name: "mmpm-log",
            script: "/opt/mmpm/start-log.sh",
            interpreter: "/bin/bash",
            watch: false,
        },
        {
            name: "mmpm-repeater",
            script: "/opt/mmpm/start-repeater.sh",
            interpreter: "/bin/bash",
            watch: false,
        },
        {
            name: "mmpm-ui",
            script: "/opt/mmpm/start-ui.sh",
            interpreter: "/bin/bash",
            watch: false,
        },
    ],
};
