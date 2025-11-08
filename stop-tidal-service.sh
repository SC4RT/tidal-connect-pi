#!/bin/bash
echo ""
echo "Stopping TIDAL Connect Watchdog."
systemctl stop tidal-watchdog.service
echo "Finished stopping TIDAL Connect Watchdog."
echo ""
echo "Stopping TIDAL Connect Volume Bridge."
systemctl stop tidal-volume-bridge.service
echo "Finished stopping TIDAL Connect Volume Bridge."
echo ""
echo "Stopping TIDAL Connect Service."
systemctl stop tidal.service
echo "Finished stopping TIDAL Connect Service."