# mDNS Collision Issue - Root Cause Analysis & Fix

## Problem Description

Users reported that TIDAL Connect devices couldn't be found in the TIDAL app, with error logs showing:
```
[tisoc] [error] [avahiImpl.cpp:113]  avahiClientCallback() AVAHI_CLIENT_S_COLLISION/AVAHI_CLIENT_FAILURE
```

Initially, this appeared to be a name collision with another device on the network, but **the real issue was the service colliding with itself during restarts**.

## Root Cause

### The Race Condition

When the watchdog detected token expiration and triggered a service restart, the following sequence occurred:

1. **Stop Phase**:
   ```systemd
   ExecStop=/bin/docker-compose down
   ExecStopPost=/bin/systemctl restart avahi-daemon   # ← Restart Avahi immediately
   ```

2. **Start Phase** (happens within 1-2 seconds):
   ```systemd
   ExecStartPre=/bin/systemctl restart avahi-daemon   # ← Restart Avahi AGAIN!
   ExecStartPre=wait-for-avahi.sh                     # ← Only checks if running
   ExecStart=/bin/docker-compose up -d
   ```

### Why This Caused Collisions

**mDNS (Multicast DNS) announcements have a Time-To-Live (TTL) of ~120 seconds.**

When the service restarted rapidly:

1. Old `tidal_connect_application` tells Avahi to unregister "hifiberry.local"
2. Avahi daemon restarts (clearing its internal state)
3. **BUT** - the mDNS announcement is still cached throughout the network!
4. New `tidal_connect_application` starts **2-3 seconds later**
5. Tries to register "hifiberry.local" again
6. **COLLISION** - the network/Avahi still sees the old registration

### Why Restarting Avahi Made It Worse

Restarting Avahi **twice** in rapid succession prevented the graceful mDNS goodbye message from being sent:

- When you restart Avahi, it doesn't send proper mDNS "goodbye" packets
- The old registration lingers on the network
- The new registration immediately conflicts with it

## The Fix

### Evolution of the Solution

#### Version 1: Removed Aggressive Avahi Restarts (Initial Fix)

Removed double Avahi restarts and added fixed delays.

**Problem with V1**: Fixed delays are brittle - too short on slow systems, too long on fast ones.

#### Version 2: Defensive State Verification (Current)

Replaced fixed delays with actual state checking and retry logic.

**Changes Made**:

##### 1. New Helper Scripts

**`wait-for-container.sh`**: Verifies container is actually healthy
```bash
# Not just running, but healthy
- Container exists in docker ps
- Docker reports State.Running = true
- tidal_connect_application process is alive
- Double-check after 2s (catch immediate crashes)
```

**`wait-for-mdns-clear.sh`**: Actively verifies mDNS cleared
```bash
# Try to verify clearance
if avahi-browse available:
    Poll until FRIENDLY_NAME disappears from mDNS
    Require 2 consecutive clear checks
else:
    Fallback to safe 5s minimum delay
```

##### 2. `templates/tidal.service.tpl` - State-Based Startup

**Before:**
```systemd
ExecStartPre=/bin/systemctl restart avahi-daemon  # ← Blind restart
ExecStartPre=wait-for-avahi.sh
ExecStartPre=/bin/sleep 5                         # ← Fixed delay
ExecStart=/bin/docker-compose up -d
ExecStop=/bin/docker-compose down
ExecStopPost=/bin/sleep 2                         # ← Fixed delay
```

**After:**
```systemd
# Ensure Avahi running (don't restart if already up)
ExecStartPre=/bin/bash -c 'systemctl is-active --quiet avahi-daemon || systemctl start avahi-daemon'
ExecStartPre=wait-for-avahi.sh

# Wait for mDNS to actually clear (with active verification)
ExecStartPre=wait-for-mdns-clear.sh

# Start container
ExecStart=/bin/docker-compose up -d

# Wait for container to be truly healthy before declaring success
ExecStartPost=wait-for-container.sh tidal_connect 30 1 healthy

# Stop with proper cleanup
ExecStop=/bin/docker-compose down --timeout 10

# Verify container actually stopped
ExecStopPost=wait-for-container.sh tidal_connect 10 1 stopped
```

**Key improvements:**
- **No blind delays** - Everything verified by actual state
- **Fast when possible** - No waiting if already clear
- **Safe when needed** - Will wait full time if necessary
- **Fail explicitly** - Timeout if state never achieved

#### 2. `tidal-watchdog.sh` - Graceful Restart Logic

**Before:**
```bash
systemctl restart tidal.service
```

**After:**
```bash
# Use stop+start instead of restart
systemctl stop tidal.service
sleep 3  # Let mDNS clear
systemctl start tidal.service
```

**Why this helps:**
- Explicit delay between stop and start
- Gives mDNS time to clear from network cache
- Combined with service file delays, provides ~8 seconds of clearance time

### Why This Works

1. **No unnecessary Avahi restarts** - Let Avahi handle registrations/unregistrations properly
2. **Sufficient delay** - 5-8 seconds gives mDNS cache time to clear (not full TTL, but enough)
3. **Graceful shutdown** - Container has time to send proper mDNS goodbye messages
4. **Separate stop+start** - More control over timing than `systemctl restart`

## Testing & Verification

To verify the fix works:

1. Update to latest version:
   ```bash
   cd /data/tidal-connect-docker
   git pull
   eval "echo \"$(cat templates/tidal.service.tpl)\"" >/etc/systemd/system/tidal.service
   systemctl daemon-reload
   ```

2. Do a clean restart:
   ```bash
   systemctl stop tidal.service
   sleep 5
   systemctl start tidal.service
   ```

3. Check for collisions:
   ```bash
   ./check-tidal-status.sh
   docker logs tidal_connect 2>&1 | grep -i collision
   ```

4. Trigger token expiration (wait ~1 hour) and check watchdog logs:
   ```bash
   tail -f /var/log/tidal-watchdog.log
   ```

## Alternative Solutions Considered

### Option A: Randomize Device Name on Restart
**Rejected**: Would confuse users when device name changes

### Option B: Increase mDNS TTL
**Rejected**: Can't control mDNS TTL from application

### Option C: Wait for full TTL expiry (120s)
**Rejected**: Too slow for automatic recovery

### Option D: Use different mDNS instance ID
**Rejected**: Would require modifying tidal_connect_application binary

### Option E: Current Solution ✓
- Minimal delay (5-8 seconds)
- No code changes to binaries
- Works within systemd constraints
- Preserves automatic recovery

## Additional Notes

- If collision still occurs, user can change `FRIENDLY_NAME` in `Docker/.env`
- The `fix-name-collision.sh` script is still useful for actual multi-device conflicts
- Documentation updated in `TROUBLESHOOTING.md` to explain both scenarios

## Related Issues

- Token expiration causing rapid restarts
- Avahi cache not clearing fast enough
- systemd `Type=oneshot` restart behavior
- Docker network mode `host` mDNS propagation

## References

- mDNS RFC 6762: https://datatracker.ietf.org/doc/html/rfc6762
- Avahi documentation: https://www.avahi.org/
- Systemd service documentation: https://www.freedesktop.org/software/systemd/man/systemd.service.html

