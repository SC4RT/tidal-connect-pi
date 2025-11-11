#!/bin/bash
# Reset script for Tidal Connect - clears all state and restarts cleanly
# Use this when things get stuck or after updates

set -e

echo "=========================================="
echo "Tidal Connect State Reset"
echo "=========================================="

# Stop all services
echo "1. Stopping all Tidal services..."
systemctl stop tidal-watchdog.service 2>/dev/null || true
systemctl stop tidal-volume-bridge.service 2>/dev/null || true
systemctl stop tidal.service 2>/dev/null || true
echo "   ✓ Services stopped"

# Force remove any containers
echo "2. Removing Docker containers..."
docker rm -f tidal_connect 2>/dev/null || true
docker ps -a | grep tidal_connect | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
echo "   ✓ Containers removed"

# Clean up Docker networks
echo "3. Cleaning Docker networks..."
docker network prune -f 2>/dev/null || true
echo "   ✓ Networks cleaned"

# Restart Avahi to clear mDNS cache
echo "4. Restarting Avahi (clears mDNS cache)..."
systemctl restart avahi-daemon
sleep 2
echo "   ✓ Avahi restarted"

# Reload ALSA if it's available
if command -v alsactl &> /dev/null; then
    echo "5. Reloading ALSA state..."
    alsactl restore 2>/dev/null || true
    echo "   ✓ ALSA reloaded"
else
    echo "5. ALSA tools not available, skipping..."
fi

# Reset systemd failed states
echo "6. Resetting systemd failed states..."
systemctl reset-failed tidal.service 2>/dev/null || true
systemctl reset-failed tidal-volume-bridge.service 2>/dev/null || true
systemctl reset-failed tidal-watchdog.service 2>/dev/null || true
echo "   ✓ Failed states reset"

# Wait for mDNS to clear
echo "7. Waiting for mDNS to clear..."
sleep 5
echo "   ✓ Wait complete"

# Start services in order
echo "8. Starting Tidal Connect service..."
systemctl start tidal.service
sleep 3

echo "9. Starting Volume Bridge..."
systemctl start tidal-volume-bridge.service
sleep 2

echo "10. Starting Watchdog..."
systemctl start tidal-watchdog.service
sleep 2

echo ""
echo "=========================================="
echo "Reset Complete!"
echo "=========================================="
echo ""
echo "Checking status..."
echo ""

# Show status
systemctl status tidal.service --no-pager -l | head -10
echo ""
docker ps | grep tidal_connect || echo "⚠ Container not running"
echo ""

# Check for immediate errors
sleep 3
if docker logs tidal_connect --tail 20 2>&1 | grep -i error; then
    echo ""
    echo "⚠ WARNING: Errors detected in container logs"
    echo "Run: docker logs tidal_connect"
else
    echo "✓ No immediate errors detected"
fi

echo ""
echo "Your device should now be visible in TIDAL"
echo "If not, run: ./check-tidal-status.sh"

