# TIDAL Connect Documentation

## Quick Start

See the main [README.md](../README.md) for installation and basic usage.

---

## Documentation Index

### Problem Solving
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
  - Device not appearing in TIDAL app
  - mDNS collision errors
  - Service failures
  - Complete diagnostic procedures

### Technical Deep Dives
- **[MDNS_COLLISION_FIX.md](MDNS_COLLISION_FIX.md)** - Root cause analysis of mDNS collision issue
  - Why the service was colliding with itself
  - Evolution of the solution from fixed delays to state verification
  - Testing and verification procedures

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design
  - Component overview
  - Defensive programming principles
  - Race condition handling
  - Failure scenarios and recovery
  - Configuration tuning guide

- **[DEFENSIVE_DESIGN_SUMMARY.md](DEFENSIVE_DESIGN_SUMMARY.md)** - Why state verification over fixed delays
  - Problem with brittle timers
  - Comparison of old vs new approaches
  - Performance characteristics
  - Testing commands

### Feature Documentation
- **[WATCHDOG.md](WATCHDOG.md)** - Connection watchdog system
  - Auto-recovery from token expiration
  - Error detection logic
  - Manual testing procedures

### Change History
- **[CHANGELOG.md](CHANGELOG.md)** - All changes and version history

---

## Document Purpose Guide

| Need to... | Read this |
|------------|-----------|
| Fix an issue | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| Understand mDNS collision | [MDNS_COLLISION_FIX.md](MDNS_COLLISION_FIX.md) |
| Understand system design | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Understand why no fixed delays | [DEFENSIVE_DESIGN_SUMMARY.md](DEFENSIVE_DESIGN_SUMMARY.md) |
| Learn about auto-recovery | [WATCHDOG.md](WATCHDOG.md) |
| See what changed | [CHANGELOG.md](CHANGELOG.md) |

---

## Development

### Key Components

**Scripts** (in project root):
- `install_hifiberry.sh` - Main installation script
- `check-tidal-status.sh` - Diagnostic tool
- `fix-name-collision.sh` - Helper for name conflicts
- `tidal-watchdog.sh` - Auto-recovery service
- `volume-bridge.sh` - Volume/metadata sync
- `wait-for-*.sh` - State verification helpers

**Service Templates** (`templates/`):
- `tidal.service.tpl` - Main service definition
- `tidal-watchdog.service.tpl` - Watchdog service
- `tidal-volume-bridge.service.tpl` - Volume bridge service

**Container** (`Docker/`):
- `Dockerfile` - Container image definition
- `entrypoint.sh` - Container startup script
- `src/` - Binaries and certificates

### Testing Checklist

See [ARCHITECTURE.md](ARCHITECTURE.md#testing-checklist) for complete testing procedures.

---

## Contributing

When adding features:
1. Follow defensive programming principles (see [ARCHITECTURE.md](ARCHITECTURE.md))
2. Add retry logic with timeouts, not fixed delays
3. Verify state transitions explicitly
4. Update relevant documentation
5. Test all failure scenarios

---

## Getting Help

1. Run diagnostics: `./check-tidal-status.sh`
2. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
3. Review logs:
   ```bash
   docker logs tidal_connect --tail 50
   journalctl -u tidal-watchdog -n 50
   tail -50 /var/log/tidal-watchdog.log
   ```

