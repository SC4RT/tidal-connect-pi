'''
Copyright (c) 2020 Modul 9/HiFiBerry

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
'''

import logging
import json
import os
from time import time

import subprocess

from ac2.helpers import map_attributes
from ac2.players import PlayerControl
from ac2.constants import CMD_NEXT, CMD_PREV, CMD_PAUSE, CMD_PLAYPAUSE, CMD_STOP, CMD_PLAY, CMD_SEEK, \
    CMD_RANDOM, CMD_NORANDOM, CMD_REPEAT_ALL, CMD_REPEAT_NONE, \
    STATE_PAUSED, STATE_PLAYING, STATE_STOPPED, STATE_UNDEF
from ac2.metadata import Metadata
   
TIDAL_STATE_PLAY="PLAYING"
TIDAL_STATE_PAUSE="PAUSED"
TIDAL_STATE_STOPPED="IDLE"
TIDAL_STATE_BUFFERING="BUFFERING"

TIDAL_ATTRIBUTE_MAP={
    "artist": "artist",
    "title": "title",
    "albumartist": "albumArtist",
    "album": "albumTitle",
    "disc": "discNumber",
    "track": "tracknumber", 
    "duration": "duration",
    "time": "time",
    "file": "streamUrl" 
    }

STATE_MAP={
    TIDAL_STATE_PAUSE: STATE_PAUSED,
    TIDAL_STATE_PLAY: STATE_PLAYING,
    TIDAL_STATE_STOPPED: STATE_STOPPED,
    TIDAL_STATE_BUFFERING: STATE_PLAYING  # Treat buffering as playing
}

class TidalControl(PlayerControl):
    
    def __init__(self, args={}):
        self.state = TIDAL_STATE_STOPPED
        self.meta = None
        self.playername = "Tidal"
        self.status_file = "/tmp/tidal-status.json"
        self.last_status = {}
        
        # Check if Tidal is available - either status file exists or container is running
        if os.path.exists(self.status_file):
            self.is_active_player = True
        else:
            # Fallback: check if container is running
            try:
                result = subprocess.run(['docker', 'ps', '-q', '-f', 'name=tidal_connect'], 
                                      capture_output=True, text=True, timeout=2)
                self.is_active_player = (result.returncode == 0 and result.stdout.strip() != "")
            except:
                self.is_active_player = False

        
    def start(self):
        logging.info('tidalcontrol::start')
        # Read status from file maintained by volume-bridge.sh
        self._update_status()
    
    def _update_status(self):
        """Read status from JSON file written by volume-bridge.sh"""
        try:
            if not os.path.exists(self.status_file):
                self.is_active_player = False
                return
            
            # Check if file is recent (updated within last 30 seconds)
            # This allows Tidal to show up even when idle, as long as the service is running
            mtime = os.path.getmtime(self.status_file)
            if time() - mtime > 30:
                # File is stale - check if container is running as fallback
                try:
                    result = subprocess.run(['docker', 'ps', '-q', '-f', 'name=tidal_connect'], 
                                          capture_output=True, text=True, timeout=2)
                    if result.returncode == 0 and result.stdout.strip():
                        # Container is running, keep player active but mark as stopped
                        self.is_active_player = True
                        self.state = TIDAL_STATE_STOPPED
                        return
                    else:
                        self.is_active_player = False
                        return
                except:
                    self.is_active_player = False
                    return
            
            with open(self.status_file, 'r') as f:
                status = json.load(f)
            
            self.last_status = status
            self.state = status.get('state', 'IDLE')
            self.is_active_player = True
            
            # Update metadata
            md = Metadata()
            md.playerName = "Tidal"
            md.artist = status.get('artist', '')
            md.title = status.get('title', '')
            md.albumTitle = status.get('album', '')
            md.duration = status.get('duration', 0)
            md.position = status.get('position', 0)
            md.positionupdate = time()
            md.artUrl = None
            md.externalArtUrl = None
            
            self.meta = md
            
        except Exception as e:
            logging.error(f"tidalcontrol: Error reading status file: {e}")
            self.is_active_player = False
        
    def get_supported_commands(self):
        logging.info('tidalcontrol::get_supported_commands')
        # Note: Commands are handled by phone app, not directly controllable
        return [CMD_NEXT, CMD_PREV, CMD_PAUSE, CMD_PLAYPAUSE, CMD_PLAY]



    
    def get_state(self):
        logging.info('tidalcontrol::get_state')
        self._update_status()
        
        try:
            state = STATE_MAP.get(self.state, STATE_UNDEF)
        except:
            state = STATE_UNDEF
        
        logging.info(f'tidalcontrol state: {self.state} -> {state}')
        return state
    
    def get_meta(self):
        logging.info('tidalcontrol::get_meta')
        self._update_status()
        return self.meta
    
    def send_command(self, command, parameters={}):
        logging.info(f'tidalcontrol::send_command: {command}')
        
        if command not in self.get_supported_commands():
            logging.warning(f'tidalcontrol: unsupported command {command}')
            return False
        
        # Commands are sent to the speaker_controller via tmux
        # Map AC2 commands to speaker_controller key presses
        try:
            if command == CMD_NEXT:
                subprocess.run(['docker', 'exec', 'tidal_connect', 'tmux', 'send-keys', '-t', 
                               'speaker_controller_application', 'L'], check=True)
            elif command == CMD_PREV:
                subprocess.run(['docker', 'exec', 'tidal_connect', 'tmux', 'send-keys', '-t', 
                               'speaker_controller_application', 'K'], check=True)
            elif command in [CMD_PAUSE, CMD_PLAYPAUSE, CMD_PLAY]:
                subprocess.run(['docker', 'exec', 'tidal_connect', 'tmux', 'send-keys', '-t', 
                               'speaker_controller_application', 'P'], check=True)
            else:
                logging.warning(f'tidalcontrol: command {command} not implemented')
                return False
            
            return True
        except Exception as e:
            logging.error(f'tidalcontrol: error sending command: {e}')
            return False
    
    def is_active(self):
        """
        Checks if Tidal player is active on the system
        """
        self._update_status()
        return self.is_active_player
    
