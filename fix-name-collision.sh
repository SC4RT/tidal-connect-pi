#!/bin/bash

echo "=========================================="
echo "TIDAL Connect Name Collision Fixer"
echo "=========================================="
echo ""

# Check if running on actual device
if ! command -v docker &> /dev/null; then
    echo "❌ This script must be run on the HifiBerry device, not your Mac"
    echo ""
    echo "To fix the name collision:"
    echo "1. SSH to your HifiBerry: ssh root@hifiberry.local"
    echo "2. cd /data/tidal-connect-docker"
    echo "3. Run: ./fix-name-collision.sh"
    exit 1
fi

ENV_FILE="Docker/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: $ENV_FILE not found"
    echo "Please run install_hifiberry.sh first"
    exit 1
fi

# Show current config
echo "Current Configuration:"
echo "----------------------"
cat "$ENV_FILE"
echo ""

# Check for collisions
echo "Checking for mDNS name collisions..."
if docker logs tidal_connect 2>&1 | grep -q "AVAHI_CLIENT_S_COLLISION\|AVAHI_CLIENT_FAILURE"; then
    echo "⚠️  COLLISION DETECTED!"
    echo ""
    echo "Another device on your network has the same name."
    echo "This prevents TIDAL from discovering your device."
    echo ""
else
    echo "✓ No collisions detected in recent logs"
    echo ""
fi

# Suggest unique names
CURRENT_NAME=$(grep "^FRIENDLY_NAME=" "$ENV_FILE" | cut -d= -f2)
echo "Current name: $CURRENT_NAME"
echo ""
echo "Suggested unique names:"
echo "  1. ${CURRENT_NAME}-2"
echo "  2. ${CURRENT_NAME}-tidal"
echo "  3. HifiBerry-$(hostname | tail -c 5)"
echo "  4. TidalConnect-$(date +%s | tail -c 5)"
echo ""

read -p "Enter new unique FRIENDLY_NAME (or press Enter to skip): " NEW_NAME

if [ -z "$NEW_NAME" ]; then
    echo "No changes made"
    exit 0
fi

# Update .env file
echo ""
echo "Updating configuration..."
sed -i "s/^FRIENDLY_NAME=.*/FRIENDLY_NAME=${NEW_NAME}/" "$ENV_FILE"
sed -i "s/^MODEL_NAME=.*/MODEL_NAME=${NEW_NAME}/" "$ENV_FILE"

echo "✓ Updated $ENV_FILE"
echo ""
echo "New Configuration:"
echo "------------------"
cat "$ENV_FILE"
echo ""

# Restart services
echo "Restarting services..."
systemctl stop tidal-volume-bridge.service
systemctl stop tidal.service
systemctl restart avahi-daemon
sleep 2
systemctl start tidal.service
systemctl start tidal-volume-bridge.service

echo ""
echo "=========================================="
echo "✓ Name changed to: $NEW_NAME"
echo "=========================================="
echo ""
echo "Wait 10-15 seconds, then:"
echo "1. Open TIDAL app on your phone"
echo "2. Look for device named: $NEW_NAME"
echo "3. Start playing music!"
echo ""
echo "To verify: ./check-tidal-status.sh"
echo ""

