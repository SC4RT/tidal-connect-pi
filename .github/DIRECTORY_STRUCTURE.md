# Directory Structure

```
tidal-connect-docker/
│
├── README.md                      # Main documentation and installation guide
│
├── Installation & Control Scripts
│   ├── install_hifiberry.sh       # Main installer
│   ├── start-tidal-service.sh     # Start services
│   ├── stop-tidal-service.sh      # Stop services
│   └── restart_beocreate2         # Restart Beocreate UI
│
├── Core Service Scripts
│   ├── tidal-watchdog.sh          # Auto-recovery watchdog
│   ├── volume-bridge.sh           # Volume/metadata sync
│   ├── wait-for-avahi.sh          # Avahi readiness check
│   ├── wait-for-container.sh      # Container health verification
│   └── wait-for-mdns-clear.sh     # mDNS collision prevention
│
├── Diagnostic & Helper Scripts
│   ├── check-tidal-status.sh      # System diagnostics
│   ├── fix-name-collision.sh      # Name collision resolver
│   ├── select-playback-device     # Audio device selector
│   ├── show-speaker-controller    # Speaker controller viewer
│   └── speaker-controller-service # Speaker controller service
│
├── Configuration Templates
│   └── templates/
│       ├── tidal.service.tpl              # Main systemd service
│       ├── tidal-watchdog.service.tpl     # Watchdog service
│       ├── tidal-volume-bridge.service.tpl # Volume bridge service
│       └── docker-compose.yml.tpl         # Docker Compose config
│
├── Docker Container
│   └── Docker/
│       ├── Dockerfile                 # Container image
│       ├── entrypoint.sh              # Container startup
│       ├── build_docker.sh            # Image builder
│       └── src/                       # Binaries, certificates, licenses
│
├── UI Integration
│   ├── beocreate/                     # Beocreate UI extension
│   └── work-in-progress/
│       ├── audiocontrol2/             # AudioControl2 integration
│       └── cmd/                       # CLI control scripts
│
├── Documentation
│   └── docs/
│       ├── README.md                  # Documentation index
│       ├── TROUBLESHOOTING.md         # Problem solving guide
│       ├── ARCHITECTURE.md            # System design
│       ├── DEFENSIVE_DESIGN_SUMMARY.md # State verification rationale
│       ├── MDNS_COLLISION_FIX.md      # Collision issue deep dive
│       ├── WATCHDOG.md                # Watchdog documentation
│       └── CHANGELOG.md               # Version history
│
└── Assets
    └── img/                           # Screenshots
```

## File Categorization

### User-Facing Scripts
Files users typically interact with:
- `install_hifiberry.sh`
- `check-tidal-status.sh`
- `fix-name-collision.sh`
- `start-tidal-service.sh` / `stop-tidal-service.sh`

### System Services
Background services (run by systemd):
- `tidal-watchdog.sh`
- `volume-bridge.sh`

### Helper Scripts
Called by services, not directly by users:
- `wait-for-*.sh` scripts

### Configuration
Templates expanded during installation:
- `templates/*.tpl`

### Development
For developers and contributors:
- `docs/` - All technical documentation
- `Docker/` - Container build files
- `work-in-progress/` - Experimental features

