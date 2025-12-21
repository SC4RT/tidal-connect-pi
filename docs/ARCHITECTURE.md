# TIDAL Connect Docker - Defensive Architecture

## Design Philosophy

This implementation follows **defensive programming** principles with retry logic, state verification, and graceful degradation instead of relying on fixed delays.

### Key Principles

1. **Verify State, Don't Assume** - Always check actual state rather than waiting arbitrary amounts of time
2. **Retry with Backoff** - Failed operations retry with exponential backoff
3. **Graceful Degradation** - Services continue operating even when dependencies are temporarily unavailable
4. **Fail Loudly** - Errors are logged with context for debugging
5. **Race Condition Awareness** - All inter-service dependencies handle timing issues

---

## Component Architecture

### 1. Main Service (`tidal.service`)

**Purpose**: Manages the Docker container lifecycle with defensive mDNS handling.

**Flow**:
```
Start → Ensure Avahi Running → Wait for mDNS Clear → Start Container → Verify Healthy
Stop  → Stop Container (10s timeout) → Verify Stopped
```

**Defensive Features**:
- `wait-for-avahi.sh`: Polls Avahi until actually running (not just started)
- `wait-for-mdns-clear.sh`: Checks if old mDNS registration cleared (with fallback timeout)
- `wait-for-container.sh`: Verifies container is not just running, but healthy

**Why No Fixed Sleeps**:
- ❌ Old: `sleep 5` - Blindly waits, might be too short or too long
- ✅ New: Poll until actual state achieved, with timeout safety

### 2. Container Health Verification (`wait-for-container.sh`)

**Three Levels of Readiness**:

1. **Stopped**: Container not in `docker ps` and state != running
2. **Running**: Container exists and Docker reports `State.Running = true`
3. **Healthy**: Container running AND `tidal_connect_application` process alive

**Usage**:
```bash
./wait-for-container.sh <name> <max_wait_sec> <check_interval> <stopped|running|healthy>
```

**Why This Matters**:
- Container might be "running" but app crashed
- mDNS registration happens after app starts
- Need to verify actual application health, not just container state

### 3. mDNS Collision Prevention (`wait-for-mdns-clear.sh`)

**Problem**: mDNS announcements have ~120s TTL. Rapid restarts cause self-collision.

**Solution**:
```bash
# Try to actively verify clearance
if avahi-browse available:
    Poll until name disappears from mDNS
    Wait for 2 consecutive "clear" checks
else:
    Fallback to safe minimum delay (5s)
```

**Defensive Features**:
- Active verification when possible
- Fallback to safe default if tools unavailable
- Timeout prevents infinite hangs
- Reads FRIENDLY_NAME from config automatically

### 4. Watchdog Service (`tidal-watchdog.sh`)

**Purpose**: Monitors for errors and performs intelligent restart with full verification.

**Error Detection**:
```bash
check_for_errors() {
    # Only recent logs (last CHECK_INTERVAL seconds)
    - Token expired
    - Connection errors (excluding normal EOFs)
    - Container down
}
```

**Restart Logic**:
```
1. Check cooldown (prevent restart loops)
2. Stop service
3. Wait for actual stop (not just command completion)
4. Clean up stale containers
5. Start service
6. Wait for healthy state (verify app running)
7. Verify no immediate mDNS collision
8. Restart volume bridge
```

**Key Improvements**:
- ❌ Old: `systemctl restart` (no control over timing)
- ✅ New: `stop` + verify stopped + `start` + verify healthy
- ❌ Old: `sleep 3` then check
- ✅ New: Poll with timeout until health confirmed

**Defensive Features**:
- `wait_for_service_stopped()`: Polls both systemctl and Docker state
- `wait_for_service_started()`: Verifies systemctl active, container running, AND app process alive
- Post-restart collision check
- Detailed logging for debugging

### 5. Volume Bridge (`volume-bridge.sh`)

**Purpose**: Monitors speaker controller and syncs volume/metadata.

**Challenge**: Container restarts while bridge is running.

**Solution**:
```bash
is_container_ready() {
    Container running AND speaker_controller_application process alive
}

Main loop:
    if ! is_container_ready:
        Track consecutive errors
        After N errors: wait_for_container() with retry
        Resume when available
```

**Defensive Features**:
- Detects container unavailability immediately
- Exponential backoff (errors trigger longer waits)
- Automatic recovery when container returns
- Doesn't crash/restart, just waits
- Logs connection status changes

**Why This Matters**:
- Volume bridge must survive container restarts
- systemd `Restart=on-failure` only helps if service crashes
- Better to detect unavailability and wait than crash

---

## Failure Scenarios & Handling

### Scenario 1: Token Expiration

**Flow**:
```
Watchdog detects "token expired" in logs
→ Cooldown check (don't restart too often)
→ Stop service + verify stopped
→ Clear stale containers
→ Start service + verify healthy (up to 45s)
→ Check for mDNS collision
→ Restart volume bridge
```

**Fallback**: If restart fails, watchdog logs error and waits for next check cycle.

### Scenario 2: Rapid Manual Restarts

**Problem**: User runs `systemctl restart` multiple times quickly.

**Protection**:
- systemctl enforces service dependency order
- `wait-for-mdns-clear.sh` delays start until safe
- `TimeoutStartSec=45` prevents systemd timeout
- Watchdog cooldown prevents interference

### Scenario 3: Network Glitch

**Flow**:
```
Container temporarily loses network
→ Watchdog sees connection errors
→ Cooldown active? Wait
→ Else: Restart with full verification
→ Volume bridge detects container down
→ Waits for recovery
→ Resumes when healthy
```

### Scenario 4: Docker Daemon Restart

**Flow**:
```
Docker restarts, all containers stop
→ Watchdog detects container down
→ Attempts restart
→ Might fail if Docker still initializing
→ Watchdog retries after CHECK_INTERVAL
→ Eventually succeeds when Docker ready
→ Volume bridge survives, reconnects automatically
```

### Scenario 5: Avahi Daemon Crash

**Flow**:
```
Avahi crashes
→ TIDAL Connect loses mDNS registration
→ Device disappears from app
→ Watchdog might not detect (depends on logs)
→ Next restart will start Avahi if needed
→ Manual intervention: systemctl restart avahi-daemon && systemctl restart tidal.service
```

---

## Race Conditions Addressed

### Race #1: mDNS Self-Collision

**Problem**: Service restart before old mDNS TTL expires.

**Solutions Applied**:
1. Don't restart Avahi (preserve mDNS state)
2. Wait for mDNS clearance before starting
3. Verify no collision after start
4. Watchdog cooldown prevents rapid restarts

### Race #2: Container Started But App Not Ready

**Problem**: Service considers itself "up" but app isn't running.

**Solutions Applied**:
1. `ExecStartPost` waits for "healthy" not just "running"
2. Check actual process (`pgrep tidal_connect_application`)
3. Double-check after 2s to catch immediate crashes

### Race #3: Volume Bridge Connects Before Container Ready

**Problem**: Bridge starts, container not ready yet.

**Solutions Applied**:
1. `After=tidal.service Requires=tidal.service` (systemd ordering)
2. Bridge has `wait_for_container()` on startup
3. Retries if container goes away

### Race #4: Watchdog Interferes with Manual Restart

**Problem**: User restarts service, watchdog also triggers restart.

**Solutions Applied**:
1. 60-second cooldown in watchdog
2. Watchdog checks service state before acting
3. Only restarts if actually failed/crashed

### Race #5: Stop Incomplete Before Start

**Problem**: `systemctl stop` returns but container still cleaning up.

**Solutions Applied**:
1. `ExecStopPost` waits for actual stop
2. Watchdog `wait_for_service_stopped()` polls state
3. Force cleanup if graceful stop fails

---

## Configuration Tuning

### Timeouts

```systemd
TimeoutStartSec=45    # Container might take time to pull image/start
TimeoutStopSec=20     # 10s for docker-compose down + 10s for verification
```

### Watchdog

```bash
CHECK_INTERVAL=30     # How often to check logs (balance responsiveness vs CPU)
RESTART_COOLDOWN=60   # Minimum time between restarts (prevent loops)
```

### Wait Scripts

```bash
# wait-for-container.sh
MAX_WAIT=30          # Fail after 30s if not ready
CHECK_INTERVAL=1     # Check every second

# wait-for-mdns-clear.sh
MAX_WAIT=15          # Most mDNS caches clear within 15s
CHECK_INTERVAL=2     # Check every 2s

# volume-bridge.sh
MAX_CONSECUTIVE_ERRORS=5  # Tolerate 5 errors before long wait
wait_for_container: 60 attempts × 2s = 2 minutes max
```

### Trade-offs

**Faster Restarts** (aggressive):
```bash
# Reduce waits (risk: more collisions)
MAX_WAIT=10 in wait-for-mdns-clear.sh
RESTART_COOLDOWN=30 in watchdog
```

**More Reliable** (conservative):
```bash
# Increase waits (trade-off: slower recovery)
MAX_WAIT=20 in wait-for-mdns-clear.sh
RESTART_COOLDOWN=90 in watchdog
```

---

## Debugging

### Enable Verbose Logging

**Watchdog**:
```bash
# Add to tidal-watchdog.sh
set -x  # Print all commands
```

**Service**:
```bash
journalctl -u tidal.service -f
journalctl -u tidal-watchdog.service -f
journalctl -u tidal-volume-bridge.service -f
```

### Manual State Checks

```bash
# Check all states
./check-tidal-status.sh

# Container health
./wait-for-container.sh tidal_connect 5 1 healthy && echo "Healthy" || echo "Not healthy"

# mDNS status
avahi-browse -t _tidal._tcp

# Service dependencies
systemctl list-dependencies tidal.service
```

### Common Issues

**Container never becomes healthy**:
```bash
docker logs tidal_connect --tail 50
docker exec tidal_connect ps aux
```

**mDNS never clears**:
```bash
avahi-browse -a | grep hifiberry
# If stuck, restart: systemctl restart avahi-daemon
```

**Watchdog not restarting**:
```bash
tail -50 /var/log/tidal-watchdog.log
# Check cooldown timing
```

---

## Future Improvements

1. **Health Endpoint**: Have tidal_connect expose HTTP health endpoint
2. **Metrics**: Export timing metrics for monitoring
3. **Adaptive Cooldown**: Increase cooldown after multiple failures
4. **mDNS Goodbye**: Ensure container sends goodbye on stop
5. **Preemptive Token Refresh**: Refresh token before expiry

---

## Testing Checklist

- [ ] Cold start (service never run before)
- [ ] Normal restart (`systemctl restart`)
- [ ] Rapid restarts (5x within 30s)
- [ ] Token expiration (wait 1 hour)
- [ ] Docker daemon restart
- [ ] Avahi daemon restart
- [ ] Network disconnect/reconnect
- [ ] Container crash (kill -9 tidal_connect_application)
- [ ] Volume bridge survives container restart
- [ ] No mDNS collisions after restart


