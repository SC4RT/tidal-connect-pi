[Unit]
Description=Tidal Connect Docker Service
After=docker.service network-online.target avahi-daemon.service
Requires=docker.service network-online.target
Wants=avahi-daemon.service

[Service]
WorkingDirectory=${PWD}/Docker/
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=45
TimeoutStopSec=20

# Ensure Avahi is running before we start
ExecStartPre=/bin/bash -c 'systemctl is-active --quiet avahi-daemon || systemctl start avahi-daemon'
ExecStartPre=${PWD}/wait-for-avahi.sh

# Clean up stale containers from hard shutdown (critical for power-off scenarios)
ExecStartPre=/bin/bash -c 'docker rm -f tidal_connect 2>/dev/null || true'
ExecStartPre=/bin/bash -c 'docker ps -a | grep tidal_connect | awk "{print \\$1}" | xargs -r docker rm -f 2>/dev/null || true'

# Wait for mDNS from previous instance to clear (defensive, with verification)
ExecStartPre=${PWD}/wait-for-mdns-clear.sh

# Start container
#ExecStartPre=/bin/docker-compose pull --quiet
ExecStart=/bin/docker-compose up -d

# Wait for container to actually be healthy before considering service started
ExecStartPost=${PWD}/wait-for-container.sh tidal_connect 30 1 healthy

# Properly stop the container (gives it time to unregister from mDNS)
ExecStop=/bin/docker-compose down --timeout 10
# Wait for container to actually stop before proceeding
ExecStopPost=${PWD}/wait-for-container.sh tidal_connect 10 1 stopped

#ExecReload=/bin/docker-compose pull --quiet
ExecReload=/bin/docker-compose up -d

[Install]
WantedBy=multi-user.target

