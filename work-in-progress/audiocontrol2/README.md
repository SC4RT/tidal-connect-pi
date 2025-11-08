# Tidal Connect AudioControl2 Integration

This integration enables Tidal Connect metadata to display in the HifiBerry UI, showing:
- Now playing information (artist, title, album)
- Playback state (playing/paused/stopped)
- Track position and duration
- Web UI playback controls (play/pause, next, previous)

## Architecture

The integration uses a two-component approach:

1. **volume-bridge.sh**: Scrapes metadata from `speaker_controller_application` tmux output and exports to `/tmp/tidal-status.json`
2. **tidalcontrol.py**: AudioControl2 plugin that reads the JSON file and registers as a player

This avoids threading issues and provides fast, reliable metadata updates.

## Prerequisites

- HifiBerryOS with AudioControl2 installed
- Tidal Connect Docker container running (with volume-bridge service)
## Quick Installation

**On your HifiBerry system:**

```bash
cd /data/tidal-connect-docker/work-in-progress/audiocontrol2
./install.sh
```

The script will:
1. Install the Tidal player plugin
2. Configure AudioControl2 to load the plugin
3. Set up service dependencies
4. Restart AudioControl2

## Manual Installation

If you prefer to install manually or troubleshoot issues

   ```
1. Create symbolic link to add TidalController to AudioControl2 daemon
   ln -s ${PWD}/tidalcontrol.py /opt/audiocontrol2/ac2/players/tidalcontrol.py
   ```
2. go and edit the file and initialize the player
   ```
   nano /opt/audiocontrol2/audiocontrol2.py
   ```

3. Look for the following section and import the TidalControl class
   ```
   from ac2.players.vollibrespot import VollibspotifyControl
   from ac2.players.vollibrespot import MYNAME as SPOTIFYNAME
   ```

   and add the following line so it looks like
   ```
   from ac2.players.vollibrespot import VollibspotifyControl
   from ac2.players.vollibrespot import MYNAME as SPOTIFYNAME
   from ac2.players.tidalcontrol import TidalControl
   ```

4. Look for the following section and add code to add and initialize the TidalController
   ```
   # Vollibrespot
   vlrctl = VollibspotifyControl()
   vlrctl.start()
   mpris.register_nonmpris_player(SPOTIFYNAME,vlrctl)
   ```

   into
   ```
   # Vollibrespot
   vlrctl = VollibspotifyControl()
   vlrctl.start()
   mpris.register_nonmpris_player(SPOTIFYNAME,vlrctl)

   # TidalControl (ADD THIS PART)
   tdctl = TidalControl()
   tdctl.start()
   mpris.register_nonmpris_player(tdctl.playername,tdctl)
   ```

5. Testing
   ```
   # Stop AudioControl2 Daemon
   systemctl restart audiocontrol2
   ```

6. Done! Open your HifiBerryOS web interface and play a song - you should see track metadata and playback controls.

## Verification

Check that Tidal is registered as a player:

```bash
curl http://127.0.0.1:81/api/player/status
```

You should see `"name": "Tidal"` in the players list.

Check metadata while playing:

```bash
curl http://127.0.0.1:81/api/track/metadata
```

You should see artist, title, album information when a track is playing.

## Troubleshooting

### Tidal not showing in player list

1. Check that volume-bridge is running:
   ```bash
   systemctl status tidal-volume-bridge
   ```

2. Check that the status file is being updated:
   ```bash
   ls -la /tmp/tidal-status.json
   cat /tmp/tidal-status.json
   ```

3. Check AudioControl2 logs:
   ```bash
   journalctl -u audiocontrol2 -f
   ```

### Metadata not updating

- Ensure you're playing music through Tidal Connect
- Check that `/tmp/tidal-status.json` is being updated (timestamp should be recent)
- Restart AudioControl2: `systemctl restart audiocontrol2`

## References

* [AudioControl2 API Documentation](https://github.com/hifiberry/audiocontrol2/blob/master/doc/api.md)
* [HifiBerryOS Documentation](https://github.com/hifiberry/hifiberry-os)
