#!/bin/bash

set -e

echo "=========================================="
echo "Tidal Connect AudioControl2 Integration"
echo "=========================================="
echo ""

# File paths
AC_CONTROL_FILE="/opt/audiocontrol2/audiocontrol2.py"
DST_PLAYER_FILE="/opt/audiocontrol2/ac2/players/tidalcontrol.py"
AC_UNIT_FILE="/usr/lib/systemd/system/audiocontrol2.service"
AC_OVERRIDE_DIR="/etc/systemd/system/audiocontrol2.service.d"

# Check if running on HifiBerryOS
if [ ! -f "$AC_CONTROL_FILE" ]; then
    echo "ERROR: AudioControl2 not found at $AC_CONTROL_FILE"
    echo "This script must be run on HifiBerryOS"
    exit 1
fi

echo "1. Installing Tidal player plugin..."
# Create symlink to tidalcontrol.py
rm -f "$DST_PLAYER_FILE"
ln -s "${PWD}/tidalcontrol.py" "$DST_PLAYER_FILE"
echo "   ✓ Player plugin installed"

echo ""
echo "2. Configuring AudioControl2..."

# Check if already configured
if grep -q "from ac2.players.tidalcontrol import TidalControl" "$AC_CONTROL_FILE"; then
    echo "   ⚠ Tidal integration already configured in audiocontrol2.py"
else
    # Add import
    sed -i '/^from ac2\.players\.vollibrespot import MYNAME as SPOTIFYNAME$/a from ac2.players.tidalcontrol import TidalControl' "$AC_CONTROL_FILE"
    
    # Add registration
    PLACEHOLDER="$(sed -nE 's/^(.*)mpris\.register_nonmpris_player\(SPOTIFYNAME,vlrctl\)$/\1/p' "$AC_CONTROL_FILE")"
    sed -i "/mpris.register_nonmpris_player(SPOTIFYNAME,vlrctl)/a \\\n${PLACEHOLDER}# TidalControl\n${PLACEHOLDER}tdctl = TidalControl()\n${PLACEHOLDER}tdctl.start()\n${PLACEHOLDER}mpris.register_nonmpris_player(tdctl.playername,tdctl)" "$AC_CONTROL_FILE"
    echo "   ✓ AudioControl2 configured"
fi

echo ""
echo "3. Updating service dependencies..."

# Create override directory if it doesn't exist
mkdir -p "$AC_OVERRIDE_DIR"

# Create/update service override to ensure audiocontrol2 starts after tidal
cat > "$AC_OVERRIDE_DIR/tidal-integration.conf" <<EOF
[Unit]
# Ensure AudioControl2 starts after Tidal Connect
After=tidal.service
Wants=tidal.service
EOF

echo "   ✓ Service dependencies configured"

echo ""
echo "4. Reloading systemd and restarting services..."
systemctl daemon-reload
systemctl restart audiocontrol2

echo "   ✓ Services restarted"

echo ""
echo "=========================================="
echo "✓ Installation complete!"
echo "=========================================="
echo ""
echo "Tidal metadata should now appear in the HifiBerry UI"
echo "when playing music through Tidal Connect."
echo ""
echo "To verify:"
echo "  curl http://127.0.0.1:81/api/player/status"
echo "  curl http://127.0.0.1:81/api/track/metadata"
echo ""
