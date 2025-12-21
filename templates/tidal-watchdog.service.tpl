[Unit]
Description=Tidal Connect Watchdog
Documentation=https://github.com/TonyTromp/tidal-connect-docker
After=tidal.service docker.service
Wants=tidal.service

[Service]
Type=simple
ExecStart=${PWD}/tidal-watchdog.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Run with lower priority to not interfere with audio
Nice=10

[Install]
WantedBy=multi-user.target

