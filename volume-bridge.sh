#!/bin/bash

# Tidal Connect Bridge: Syncs volume and exports metadata for AudioControl2
# This enables phone volume control and HifiBerry UI metadata display

ALSA_MIXER="Digital"  # HifiBerry DAC+ uses the Digital mixer
STATUS_FILE="/tmp/tidal-status.json"
PREV_VOLUME=-1
PREV_HASH=""

echo "Starting Tidal Connect bridge..."
echo "Monitoring speaker controller and syncing to ALSA mixer: $ALSA_MIXER"
echo "Exporting metadata to: $STATUS_FILE"

while true; do
    # Capture tmux output from speaker_controller_application
    TMUX_OUTPUT=$(docker exec -t tidal_connect /usr/bin/tmux capture-pane -pS -50 2>/dev/null | tr -d '\r')
    
    if [ -z "$TMUX_OUTPUT" ]; then
        sleep 0.5
        continue
    fi
    
    # Parse playback state (PLAYING, PAUSED, IDLE, BUFFERING)
    STATE=$(echo "$TMUX_OUTPUT" | grep -o 'PlaybackState::[A-Z]*' | cut -d: -f3)
    [ -z "$STATE" ] && STATE="IDLE"
    
    # Parse metadata fields
    ARTIST=$(echo "$TMUX_OUTPUT" | grep '^xartists:' | sed 's/^xartists: \(.*\)x*$/\1/' | sed 's/ *x*$//')
    ALBUM=$(echo "$TMUX_OUTPUT" | grep '^xalbum name:' | sed 's/^xalbum name: \(.*\)x*$/\1/' | sed 's/ *x*$//')
    TITLE=$(echo "$TMUX_OUTPUT" | grep '^xtitle:' | sed 's/^xtitle: \(.*\)x*$/\1/' | sed 's/ *x*$//')
    DURATION=$(echo "$TMUX_OUTPUT" | grep '^xduration:' | sed 's/^xduration: \(.*\)x*$/\1/' | sed 's/ *x*$//')
    SHUFFLE=$(echo "$TMUX_OUTPUT" | grep '^xshuffle:' | sed 's/^xshuffle: \(.*\)x*$/\1/' | sed 's/ *x*$//')
    
    # Parse position (e.g., "38 / 227")
    POSITION_LINE=$(echo "$TMUX_OUTPUT" | grep -E '^ *[0-9]+ */ *[0-9]+$' | tr -d ' ')
    POSITION=$(echo "$POSITION_LINE" | cut -d'/' -f1)
    [ -z "$POSITION" ] && POSITION=0
    
    # Parse volume from volume bar (count # symbols)
    VOLUME=$(echo "$TMUX_OUTPUT" | grep 'l.*#.*k$' | tr -cd '#' | wc -c)
    
    # Convert duration from milliseconds to seconds if present
    if [ -n "$DURATION" ] && [ "$DURATION" -gt 0 ]; then
        DURATION_SEC=$((DURATION / 1000))
    else
        DURATION_SEC=0
    fi
    
    # Create status hash to detect changes
    STATUS_HASH="${STATE}|${ARTIST}|${TITLE}|${ALBUM}|${POSITION}|${VOLUME}"
    
    # Update ALSA volume if changed
    if [ "$VOLUME" != "$PREV_VOLUME" ] && [ -n "$VOLUME" ] && [ "$VOLUME" -ge 0 ]; then
        # Map volume: speaker controller shows 0-38 # symbols
        # Map to ALSA Digital mixer range 0-207
        ALSA_VALUE=$((VOLUME * 207 / 38))
        
        # Clamp to valid range
        if [ "$ALSA_VALUE" -gt 207 ]; then
            ALSA_VALUE=207
        fi
        
        echo "[$(date '+%H:%M:%S')] Volume changed: $VOLUME/38 -> Setting ALSA $ALSA_MIXER to $ALSA_VALUE/207"
        docker exec tidal_connect amixer set "$ALSA_MIXER" "$ALSA_VALUE" > /dev/null 2>&1
        
        PREV_VOLUME=$VOLUME
    fi
    
    # Export metadata to JSON file if anything changed
    if [ "$STATUS_HASH" != "$PREV_HASH" ]; then
        # Get current timestamp
        TIMESTAMP=$(date +%s)
        
        # Escape quotes in strings for JSON
        ARTIST_JSON=$(echo "$ARTIST" | sed 's/"/\\"/g')
        TITLE_JSON=$(echo "$TITLE" | sed 's/"/\\"/g')
        ALBUM_JSON=$(echo "$ALBUM" | sed 's/"/\\"/g')
        
        # Write JSON status file (atomic write via temp file)
        cat > "${STATUS_FILE}.tmp" <<EOF
{
  "state": "$STATE",
  "artist": "$ARTIST_JSON",
  "title": "$TITLE_JSON",
  "album": "$ALBUM_JSON",
  "duration": $DURATION_SEC,
  "position": $POSITION,
  "volume": $VOLUME,
  "shuffle": "$SHUFFLE",
  "timestamp": $TIMESTAMP
}
EOF
        mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
        
        echo "[$(date '+%H:%M:%S')] Updated metadata: $STATE - $ARTIST - $TITLE"
        PREV_HASH=$STATUS_HASH
    fi
    
    sleep 0.5  # Check twice per second
done

