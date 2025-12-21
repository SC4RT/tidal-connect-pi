# TIDAL Connect Troubleshooting Guide

## Device Not Showing Up in TIDAL App

### 1. Check Avahi Name Collision (Most Common Issue)

**Symptom**: Device was working before, now can't be found in TIDAL app

**Error in logs**:
```
[tisoc] [error] [avahiImpl.cpp:113]  avahi ClientCallback() AVAHI_CLIENT_S_COLLISION/AVAHI_CLIENT_FAILURE
```

**Causes** (in order of likelihood):
1. **Rapid restarts** - Service restarting too fast, colliding with its own mDNS registration (mDNS has ~120s TTL)
2. **Another device** - Actually two devices with same name on network (rare)

**Solution A - Fix Rapid Restart Issue** (try this first):

Update to latest version with collision fixes:
```bash
cd /data/tidal-connect-docker
git pull
eval "echo \"$(cat templates/tidal.service.tpl)\"" >/etc/systemd/system/tidal.service
systemctl daemon-reload
systemctl stop tidal.service
sleep 5  # Let mDNS clear
systemctl start tidal.service
```

**Solution B - Change Device Name** (if Solution A doesn't work):

```bash
cd /data/tidal-connect-docker
./fix-name-collision.sh
```

Or manually:
1. Edit `Docker/.env`:
   ```bash
   nano Docker/.env
   ```

2. Change `FRIENDLY_NAME` to something unique:
   ```bash
   FRIENDLY_NAME=MyHifiBerry-Living-Room
   MODEL_NAME=MyHifiBerry-Living-Room
   ```

3. Restart with delay:
   ```bash
   systemctl stop tidal.service
   sleep 5  # Important: Let mDNS TTL expire!
   systemctl start tidal.service
   ```

4. Wait 15 seconds and refresh TIDAL app

### 2. Service Not Running

**Check status**:
```bash
./check-tidal-status.sh
```

**If container not running**:
```bash
systemctl restart tidal.service
docker logs tidal_connect
```

**Common causes**:
- Avahi not running: `systemctl status avahi-daemon`
- Docker not running: `systemctl status docker`
- Wrong playback device configured

### 3. Token Expired

**Symptom**: Device was working, stopped after ~1 hour

**Check watchdog logs**:
```bash
tail -20 /var/log/tidal-watchdog.log
```

**Solution**: Watchdog should auto-restart. If not:
```bash
systemctl restart tidal.service
```

Then reconnect from TIDAL app.

### 4. Wrong Audio Device

**Symptom**: Device appears in TIDAL but no sound

**Check current device**:
```bash
cat Docker/.env | grep PLAYBACK_DEVICE
```

**List available devices**:
```bash
docker exec tidal_connect /app/ifi-tidal-release/bin/ifi-pa-devs-get 2>/dev/null | grep device#
```

**Change device**:
```bash
nano Docker/.env
# Update PLAYBACK_DEVICE line
systemctl restart tidal.service
```

### 5. Network/DNS Issues

**Check connectivity**:
```bash
docker exec tidal_connect ping -c 3 8.8.8.8
```

**Check DNS in docker-compose**:
```bash
cat Docker/docker-compose.yml | grep dns
```

**Change DNS**:
```bash
nano Docker/.env
# Add or change: DOCKER_DNS=8.8.8.8
systemctl restart tidal.service
```

### 6. Avahi Configuration Issues

**Restart Avahi**:
```bash
systemctl restart avahi-daemon
systemctl restart tidal.service
```

**Check Avahi status**:
```bash
systemctl status avahi-daemon
avahi-browse -t _tidalconnect._tcp
```

### 7. Volume Control Not Working

**Check volume bridge**:
```bash
systemctl status tidal-volume-bridge.service
journalctl -u tidal-volume-bridge -n 50
```

**Restart volume bridge**:
```bash
systemctl restart tidal-volume-bridge.service
```

**Check ALSA mixer**:
```bash
docker exec tidal_connect amixer
```

## Complete Reset Procedure

If nothing works, try a complete reset:

```bash
cd /data/tidal-connect-docker

# Stop everything
systemctl stop tidal-volume-bridge.service
systemctl stop tidal-watchdog.service
systemctl stop tidal.service
docker stop tidal_connect
docker rm tidal_connect

# Clean up
systemctl restart avahi-daemon

# Restart with unique name
FRIENDLY_NAME="MyUniqueHifiBerry-$(date +%s | tail -c 5)" ./install_hifiberry.sh
```

## Diagnostic Commands

### Quick Status Check
```bash
./check-tidal-status.sh
```

### Check All Logs
```bash
# Container logs
docker logs tidal_connect --tail 50

# Service logs
journalctl -u tidal.service -n 50
journalctl -u tidal-volume-bridge.service -n 50

# Watchdog logs
tail -50 /var/log/tidal-watchdog.log

# Avahi logs
journalctl -u avahi-daemon -n 50
```

### Check mDNS Advertisement
```bash
avahi-browse -a | grep -i tidal
avahi-browse -t _tidalconnect._tcp
```

### Check Configuration
```bash
# Current settings
cat Docker/.env

# Service file
cat /etc/systemd/system/tidal.service

# Docker compose
cat Docker/docker-compose.yml
```

## Getting Help

When reporting issues, please provide:

1. Output of `./check-tidal-status.sh`
2. Docker logs: `docker logs tidal_connect --tail 100`
3. Your configuration: `cat Docker/.env` (remove any sensitive info)
4. Avahi status: `systemctl status avahi-daemon`

## Common Error Messages Explained

| Error | Meaning | Solution |
|-------|---------|----------|
| `AVAHI_CLIENT_S_COLLISION` | Name conflict | Change FRIENDLY_NAME |
| `Token expired` | Session timeout | Wait for watchdog to restart |
| `No such container` | Container not running | `systemctl start tidal.service` |
| `Connection refused` | Network issue | Check network/DNS |
| `Invalid certificate` | Cert file missing | Reinstall or rebuild image |
| `Device not found` | Wrong audio device | Update PLAYBACK_DEVICE in .env |

## Prevention Tips

1. **Use unique device names** - Include room name or random suffix
2. **Monitor watchdog** - Check `/var/log/tidal-watchdog.log` periodically
3. **Keep services enabled** - Don't disable the watchdog or volume bridge
4. **Stable network** - Ensure WiFi power management is disabled
5. **Regular updates** - `git pull` to get latest fixes

