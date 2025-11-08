#!/bin/bash
echo ""
echo "Starting TIDAL Connect Service."
systemctl start tidal.service
echo "Finished starting TIDAL Connect Service."
echo ""
echo "Starting TIDAL Connect Volume Bridge."
systemctl start tidal-volume-bridge.service
echo "Finished starting TIDAL Connect Volume Bridge."
echo ""
echo "Starting TIDAL Connect Watchdog."
systemctl start tidal-watchdog.service
echo "Finished starting TIDAL Connect Watchdog."