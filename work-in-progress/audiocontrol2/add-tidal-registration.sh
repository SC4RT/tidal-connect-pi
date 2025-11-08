#!/bin/bash

# Script to manually add Tidal registration to AudioControl2
# This is a fallback if the sed command in install_hifiberry.sh fails

AC_CONTROL_FILE="/opt/audiocontrol2/audiocontrol2.py"

if [ ! -f "$AC_CONTROL_FILE" ]; then
    echo "ERROR: AudioControl2 not found at $AC_CONTROL_FILE"
    exit 1
fi

# Check if already registered
if grep -q "tdctl = TidalControl()" "$AC_CONTROL_FILE"; then
    echo "Tidal is already registered in AudioControl2"
    exit 0
fi

# Find the line with Spotify registration (try multiple patterns)
SPOTIFY_LINE=$(grep -n "register_nonmpris_player.*vlrctl\|register_nonmpris_player.*SPOTIFYNAME\|register_nonmpris_player.*vollibrespot" "$AC_CONTROL_FILE" | head -1 | cut -d: -f1)

if [ -z "$SPOTIFY_LINE" ]; then
    echo "ERROR: Could not find Spotify registration line"
    echo "Searching for registration patterns..."
    grep -n "register_nonmpris_player" "$AC_CONTROL_FILE" | head -5
    echo ""
    echo "Please manually add the registration code after the Spotify registration line."
    exit 1
fi

# Get indentation from that line
INDENT=$(sed -n "${SPOTIFY_LINE}p" "$AC_CONTROL_FILE" | sed 's/^\([[:space:]]*\).*/\1/')

# Create registration code with proper indentation
REGISTRATION_CODE="${INDENT}# TidalControl
${INDENT}tdctl = TidalControl()
${INDENT}tdctl.start()
${INDENT}mpris.register_nonmpris_player(tdctl.playername,tdctl)"

# Insert after Spotify registration line
sed -i "${SPOTIFY_LINE}a\\
${REGISTRATION_CODE}" "$AC_CONTROL_FILE"

echo "✓ Tidal registration added to AudioControl2"
echo "Please restart AudioControl2: systemctl restart audiocontrol2"

