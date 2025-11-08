#!/bin/bash

# Tidal Connect Watchdog: Monitors for connection issues and auto-recovers
# This script detects token expiration and connection errors, then restarts the service

LOG_FILE="/var/log/tidal-watchdog.log"
CHECK_INTERVAL=30  # Check every 30 seconds
RESTART_COOLDOWN=60  # Don't restart more than once per minute
LAST_RESTART=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_container_status() {
    docker inspect -f '{{.State.Running}}' tidal_connect 2>/dev/null
}

check_for_errors() {
    # Get logs from the last CHECK_INTERVAL seconds
    RECENT_LOGS=$(docker logs --since ${CHECK_INTERVAL}s tidal_connect 2>&1)
    
    # Check for critical errors
    if echo "$RECENT_LOGS" | grep -q "invalid_grant\|token has expired"; then
        echo "token_expired"
        return
    fi
    
    if echo "$RECENT_LOGS" | grep -q "handle_read_frame error\|async_shutdown error"; then
        echo "connection_lost"
        return
    fi
    
    # Check if container is running but not responsive
    if [ "$(get_container_status)" != "true" ]; then
        echo "container_down"
        return
    fi
    
    echo "ok"
}

restart_service() {
    local reason="$1"
    local current_time=$(date +%s)
    
    # Enforce cooldown to prevent restart loops
    if [ $((current_time - LAST_RESTART)) -lt $RESTART_COOLDOWN ]; then
        log "⏳ Restart requested but cooldown active (${RESTART_COOLDOWN}s)"
        return 1
    fi
    
    log "🔄 Restarting Tidal Connect service (Reason: $reason)"
    
    # Restart the service
    systemctl restart tidal.service
    
    # Wait for container to start
    sleep 10
    
    if [ "$(get_container_status)" = "true" ]; then
        log "✓ Service restarted successfully"
        LAST_RESTART=$current_time
        
        # Also restart volume bridge to ensure it reconnects
        systemctl restart tidal-volume-bridge.service 2>/dev/null
        
        return 0
    else
        log "✗ Service restart failed"
        return 1
    fi
}

# Main monitoring loop
log "=========================================="
log "Tidal Connect Watchdog started"
log "Check interval: ${CHECK_INTERVAL}s"
log "Restart cooldown: ${RESTART_COOLDOWN}s"
log "=========================================="

while true; do
    # Check if container exists
    if ! docker ps -a | grep -q tidal_connect; then
        log "⚠ Tidal Connect container not found, waiting..."
        sleep $CHECK_INTERVAL
        continue
    fi
    
    # Check for errors
    STATUS=$(check_for_errors)
    
    case "$STATUS" in
        token_expired)
            log "⚠ Detected: Token expired"
            restart_service "token_expired"
            ;;
        connection_lost)
            log "⚠ Detected: Connection lost"
            restart_service "connection_lost"
            ;;
        container_down)
            log "⚠ Detected: Container down"
            restart_service "container_down"
            ;;
        ok)
            # Silently continue
            ;;
    esac
    
    sleep $CHECK_INTERVAL
done

