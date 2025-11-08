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

# Check if import is present
if ! grep -q "from ac2.players.tidalcontrol import TidalControl" "$AC_CONTROL_FILE"; then
    echo "ERROR: TidalControl import not found in $AC_CONTROL_FILE."
    echo "Please ensure 'from ac2.players.tidalcontrol import TidalControl' is added."
    exit 1
fi

# Insert after Spotify registration line (use a temp file for compatibility)
TEMP_FILE=$(mktemp)
if ! head -n "${SPOTIFY_LINE}" "$AC_CONTROL_FILE" > "$TEMP_FILE" 2>/dev/null; then
    echo "ERROR: Failed to read first part of file"
    rm -f "$TEMP_FILE"
    exit 1
fi

echo "$REGISTRATION_CODE" >> "$TEMP_FILE"

if ! tail -n +$((SPOTIFY_LINE + 1)) "$AC_CONTROL_FILE" >> "$TEMP_FILE" 2>/dev/null; then
    echo "ERROR: Failed to read remaining part of file"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Verify the temp file looks correct before replacing
if ! grep -q "tdctl = TidalControl()" "$TEMP_FILE"; then
    echo "ERROR: Registration code not found in temp file. Aborting."
    rm -f "$TEMP_FILE"
    exit 1
fi

# Backup original file
cp "$AC_CONTROL_FILE" "${AC_CONTROL_FILE}.bak"

# Replace original with temp file
if ! mv "$TEMP_FILE" "$AC_CONTROL_FILE"; then
    echo "ERROR: Failed to replace file. Restoring backup..."
    mv "${AC_CONTROL_FILE}.bak" "$AC_CONTROL_FILE"
    exit 1
fi

# Verify it was actually added
if grep -q "tdctl = TidalControl()" "$AC_CONTROL_FILE"; then
    echo "✓ Tidal registration added to AudioControl2"
    echo "Please restart AudioControl2: systemctl restart audiocontrol2"
    rm -f "${AC_CONTROL_FILE}.bak"
else
    echo "ERROR: Registration code not found after insertion. Restoring backup..."
    mv "${AC_CONTROL_FILE}.bak" "$AC_CONTROL_FILE"
    exit 1
fi

