[Unit]
Description=Tidal Connect Volume Bridge
After=tidal.service
Requires=tidal.service

[Service]
ExecStart=${PWD}/volume-bridge.sh
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
