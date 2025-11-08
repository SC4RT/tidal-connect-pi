# Tidal Connect Watchdog

The Tidal Connect Watchdog automatically monitors and recovers from connection issues, making your Tidal Connect installation more resilient.

## What It Does

The watchdog continuously monitors the Tidal Connect container for:

1. **Token Expiration**: Detects when Tidal's authentication token expires
2. **Connection Loss**: Monitors for network connection errors
3. **Container Crashes**: Detects if the Docker container stops unexpectedly

When any of these issues are detected, the watchdog automatically restarts the Tidal Connect service.

## How It Works

```
┌─────────────────┐
│  Tidal Connect  │
│     Service     │
└────────┬────────┘
         │
         │ monitors every 30s
         ▼
┌─────────────────┐
│     Watchdog    │◄─── Checks Docker logs for errors
│     Service     │
└────────┬────────┘
         │
         │ on error detection
         ▼
┌─────────────────┐
│ Auto Restart    │
│   + Cooldown    │
└─────────────────┘
```

### Detection Patterns

The watchdog looks for these specific error patterns in the Docker logs:

- **Token Expiration**: `invalid_grant`, `token has expired`
- **Connection Loss**: `handle_read_frame error`, `async_shutdown error`
- **Container Down**: Container not running

### Safety Features

- **Restart Cooldown**: Won't restart more than once per minute to prevent restart loops
- **Graceful Recovery**: Also restarts the volume bridge service to ensure everything reconnects
- **Logging**: All actions are logged to `/var/log/tidal-watchdog.log`

## Installation

The watchdog is automatically installed when you run `install_hifiberry.sh`.

### Manual Installation

If you've already installed Tidal Connect and want to add the watchdog:

```bash
# On your HifiBerry system
cd /data/tidal-connect-docker

# Install the watchdog service
eval "echo \"$(cat templates/tidal-watchdog.service.tpl)\"" >/etc/systemd/system/tidal-watchdog.service

# Enable and start it
systemctl enable tidal-watchdog.service
systemctl start tidal-watchdog.service
```

## Usage

### Check Watchdog Status

```bash
systemctl status tidal-watchdog
```

### View Watchdog Logs

```bash
# Real-time monitoring
journalctl -u tidal-watchdog -f

# Or check the log file
tail -f /var/log/tidal-watchdog.log
```

### Manually Trigger a Check

The watchdog runs automatically, but you can restart the service to force an immediate check:

```bash
systemctl restart tidal-watchdog
```

## Configuration

You can customize the watchdog by editing `/data/tidal-connect-docker/tidal-watchdog.sh`:

- `CHECK_INTERVAL`: How often to check for errors (default: 30 seconds)
- `RESTART_COOLDOWN`: Minimum time between restarts (default: 60 seconds)

After making changes:

```bash
systemctl restart tidal-watchdog
```

## Troubleshooting

### Watchdog not starting

Check the logs:
```bash
journalctl -u tidal-watchdog -n 50
```

### Too many restarts

If you see frequent restarts, there might be an underlying issue:

```bash
# Check what's triggering the restarts
grep "Restarting" /var/log/tidal-watchdog.log

# Check the Tidal Connect logs
docker logs tidal_connect | tail -100
```

### Disable the watchdog

If you need to disable automatic recovery:

```bash
systemctl stop tidal-watchdog
systemctl disable tidal-watchdog
```

## What Gets Restarted

When the watchdog detects an issue, it restarts:

1. **tidal.service** - The main Tidal Connect Docker container
2. **tidal-volume-bridge.service** - The volume/metadata bridge

This ensures a complete, clean restart of the entire Tidal Connect stack.

## Performance Impact

The watchdog has minimal performance impact:
- Runs with `Nice=10` (lower priority than audio services)
- Checks logs every 30 seconds (configurable)
- Only active monitoring, no continuous processing

## Common Recovery Scenarios

### Scenario 1: Token Expiration

```
[2025-11-08 12:00:00] ⚠ Detected: Token expired
[2025-11-08 12:00:00] 🔄 Restarting Tidal Connect service (Reason: token_expired)
[2025-11-08 12:00:10] ✓ Service restarted successfully
```

**What happens**: Your Tidal app will need to reconnect to the device, but it should appear in the available devices list immediately.

### Scenario 2: Connection Lost

```
[2025-11-08 12:15:00] ⚠ Detected: Connection lost
[2025-11-08 12:15:00] 🔄 Restarting Tidal Connect service (Reason: connection_lost)
[2025-11-08 12:15:10] ✓ Service restarted successfully
```

**What happens**: The device will automatically reconnect. If you're playing music, you'll need to resume from your Tidal app.

## Integration with Other Services

The watchdog works seamlessly with:
- ✅ Volume Bridge - Automatically restarted with Tidal
- ✅ AudioControl2 - Will detect Tidal when it comes back online
- ✅ Avahi/mDNS - Service name remains available during restart

## Limitations

The watchdog cannot fix:
- ❌ Network connectivity issues (WiFi down, router issues)
- ❌ Tidal API outages
- ❌ Hardware problems
- ❌ Docker daemon issues

For these issues, you'll need to address the underlying problem.

## Future Improvements

Potential enhancements being considered:
- Pre-emptive token refresh before expiration
- Notification system (email/webhook on recovery)
- Metrics collection (uptime, restart frequency)
- Integration with system health monitoring

## Contributing

Found an edge case or have a suggestion? Contributions welcome!

