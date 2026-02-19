# Raspberry Pi Tidal Connect Docker Installation Script

## This fork adds an installation script for Raspbian (Raspberry Pi OS).<br/>
## It also fixes an error which causes the tidal connect docker to fail to install.<br/>
The issue was that the docker yml template was being incorrectly copied over and the speech marks around 'restart: "no" ' were failing to be copied over.
My solution was changing it from "no" to 'no' which can be correctly copied over into the docker yml allowing it to be initialised correctly.

# Installation for Raspbian (Raspberry Pi OS)
```
git clone https://github.com/SC4RT/tidal-connect-pi.git
```
```
cd tidal-connect-pi
```
```
sudo ./install_raspbian.sh
```
## Configuration
```
-f <FRIENDLY_NAME>
-m <MODEL_NAME>
-d <DOCKER_DNS>
Example: sudo ./install_raspbian.sh -f ZiFi -m RaspberryPi -d 9.9.9.9
```
## Test
Please run to check for any errors, keep in mind that any ALSA 'unknown' errors are expected for virtual devices and such
```
sudo docker logs tidal_connect -f
```
![pallas](https://imgs.search.brave.com/GHu4YiG_g4JAjG5LfrQ1hHwtkgqGOLD3-2xgSDtrJeA/rs:fit:860:0:0:0/g:ce/aHR0cHM6Ly9pMC53/cC5jb20vY2FpdGx5/bmZpbnRvbi5jb20v/d3AtY29udGVudC91/cGxvYWRzLzIwMjMv/MDMvMTExNzQ2MzA2/MDZfMWQxZGI0MmI1/ZF9vLmpwZz9yZXNp/emU9MTAyNCw2ODIm/c3NsPTE)


# V Go support the original creator
<a href="https://www.buymeacoffee.com/tonytromp" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 30px !important;width: 110px !important;" ></a>


# V Original ReadMe Continued Below V 


# Tidal Connect Docker image for HifiBerry (and RaspbianOS)

![hifiberry_sources](img/hifiberry_listsources.png?raw=true)

Image based on https://github.com/shawaj/ifi-tidal-release and https://github.com/seniorgod/ifi-tidal-release. 
Please visit https://www.raspberrypi.org/forums/viewtopic.php?t=297771 for full information on the backround of this project.

# Why this Docker Port

I have been happily using HifiberryOS but being an extremely slim OS (based on Buildroot) has its pitfalls, that there is no easy way of extending its current features. Thankfully the Hifiberry Team have blessed us by providing Docker and Docker-Compose within OS.
As I didn't want to add yet another system for Tidal integration (e.g. Bluesound, Volumio), i stumbled upon this https://support.hifiberry.com/hc/en-us/community/posts/360013667717-Tidal-Connect-, and i decided to do something about it. 

This port does much more than just providing the docker image with TIDAL Connect and volume control, as for HifiBerry users it will also install additional sources menu as displayed above.

# Features

## Core Functionality
- ✅ **TIDAL Connect** - Full Tidal Connect integration for high-quality music streaming
- ✅ **Docker-based** - Clean, isolated installation that doesn't interfere with your system
- ✅ **HifiBerry UI Integration** - Tidal appears as a source in the HifiBerry web interface

## Enhanced Features (New!)
- ✅ **Phone Volume Control** - Volume adjustments from your phone/tablet are synced to ALSA mixer
- ✅ **Metadata Display** - Now playing info (artist, title, album) shown in HifiBerry UI via AudioControl2
- ✅ **Web UI Controls** - Play/pause, next, previous controls work from the HifiBerry web interface
- ✅ **Connection Watchdog** - Automatic recovery from connection drops and token expiration
- ✅ **WiFi Power Management** - Automatically disabled for improved responsiveness
- ✅ **Hard Shutdown Resilient** - Designed for hard power-offs; automatic cleanup on boot ensures fresh start

## Audio Quality
- Supports up to 24-bit/96kHz (depending on your DAC)
- MQA passthrough support (configurable)
- Direct ALSA integration for low-latency playback

# Known Issues & Limitations

* ~~Remote volume control (via IOS/Android) is not working on Hifiberry DAC2 Pro~~ **FIXED!** Now works via volume bridge
* Token expiration may require reconnecting from Tidal app (watchdog handles automatic recovery)
* Web UI volume slider may not reflect phone volume changes in real-time (phone control works, just display lag)
* **mDNS collision during rapid restarts**: Fixed in latest version - service was colliding with its own mDNS registration (see [docs/MDNS_COLLISION_FIX.md](docs/MDNS_COLLISION_FIX.md))
* **Name collision**: In rare cases, if another device on your network has the same name, TIDAL won't discover your device (see [Troubleshooting](#troubleshooting))

# Installation

1. SSH into your Raspberry and clone/copy this repository onto your system. 
```
# On HifiberryOS
cd /data && \
  git clone https://github.com/TonyTromp/tidal-connect-docker.git && \
  cd tidal-connect-docker
```

2. Install and run

```
# On HifiBerryOS
./install_hifiberry.sh
```


Other PiOS (e.g. Raspbian), you can find the docker-compose scripts in the Docker folder.

## What Gets Installed

The installation script sets up:

1. **tidal.service** - Main Tidal Connect Docker container
2. **tidal-volume-bridge.service** - Syncs phone volume to ALSA mixer and exports metadata
3. **tidal-watchdog.service** - Monitors for connection issues and auto-recovers
4. **AudioControl2 integration** (if available) - Enables metadata display and web UI controls
5. **HifiBerry UI source** - Adds Tidal Connect to the sources menu

## Verification

After installation, verify everything is running:

```bash
# Check all services
systemctl status tidal.service
systemctl status tidal-volume-bridge.service
systemctl status tidal-watchdog.service

# Check that Tidal appears in AudioControl2 (if available)
curl http://127.0.0.1:81/api/player/status

# Watch logs
docker logs -f tidal_connect
tail -f /var/log/tidal-watchdog.log
```

Your device should now appear in the Tidal app on your phone as the friendly name you configured!

ENJOY! 🎵

## Managing the Service

```bash
# Start Tidal Connect
./start-tidal-service.sh

# Stop Tidal Connect  
./stop-tidal-service.sh

# View logs
docker logs -f tidal_connect
journalctl -u tidal-volume-bridge -f
journalctl -u tidal-watchdog -f
```

## Usage
```
./install_hifiberry.sh installs TIDAL Connect on your Raspberry Pi.

Usage: 

  [FRIENDLY_NAME=<FRIENDLY_NAME>] \
  [MODEL_NAME=<MODEL_NAME> ] \
  [BEOCREATE_SYMLINK_FOLDER=<BEOCREATE_SYMLINK_FOLDER> ] \
  [DOCKER_DNS=<DOCKER_DNS> ] \
  ./install_hifiberry.sh \
    [-f <FRIENDLY_NAME>] \
    [-m <MODEL_NAME>] \
    [-b <BEOCREATE_SYMLINK_FOLDER>] \
    [-d <DOCKER_DNS>] \
    [-i <Docker Image>] \
    [-p <build|pull>]

Defaults:
  FRIENDLY_NAME:            hifiberry
  MODEL_NAME:               hifiberry
  BEOCREATE_SYMLINK_FOLDER: /opt/beocreate/beo-extensions/tidal
  DOCKER_DNS:               8.8.8.8
  DOCKER_IMAGE:             edgecrush3r/tidal-connect:latest
  BUILD_OR_PULL:            pull

Example: 
  BUILD_OR_PULL=build \
  DOCKER_IMAGE=tidal-connect:latest \
  ./install_hifiberry.sh

Running environment: 
  FRIENDLY_NAME:            hifiberry
  MODEL_NAME:               hifiberry
  BEOCREATE_SYMLINK_FOLDER: /opt/beocreate/beo-extensions/tidal
  DOCKER_DNS:               8.8.8.8
  DOCKER_IMAGE:             tidal-connect:latest
  BUILD_OR_PULL:            build
  PWD:                      /root

Please note that command line arguments 
take precedence over environment variables,
which take precedence over defaults.
```

## Example Run 1
This is an example from a Raspberry Pi that was configured with the hostname `hifipi1`.

```
# ./install_hifiberry.sh
Running environment: 
  FRIENDLY_NAME:            hifipi1
  MODEL_NAME:               hifipi1
  BEOCREATE_SYMLINK_FOLDER: /opt/beocreate/beo-extensions/tidal
  DOCKER_DNS:               8.8.8.8
  DOCKER_IMAGE:             edgecrush3r/tidal-connect:latest
  BUILD_OR_PULL:            pull
  PWD:                      /data/tidal-connect-docker

Wed Oct 20 21:48:11 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Pre-flight checks.
Wed Oct 20 21:48:11 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Checking to see if Docker is running.
Wed Oct 20 21:48:11 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Confirmed that Docker daemon is running.
Wed Oct 20 21:48:11 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Checking to see if Docker image edgecrush3r/tidal-connect:latest exists.
Wed Oct 20 21:48:11 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Docker image edgecrush3r/tidal-connect:latest does not exist on local machine.
Wed Oct 20 21:48:11 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Pulling docker image edgecrush3r/tidal-connect:latest.
latest: Pulling from edgecrush3r/tidal-connect
31994f9482cd: Already exists 
b7df42230716: Pull complete 
ff3b3b30d785: Pull complete 
c59fa572c696: Pull complete 
c25866291a97: Pull complete 
06d8c178ae9c: Pull complete 
e3a1435f71e6: Pull complete 
0503bcd05c0a: Pull complete 
10cba31442a1: Pull complete 
451f209d8450: Pull complete 
a670b60306b7: Pull complete 
4f99276c4db5: Pull complete 
050764b3bf72: Pull complete 
ac5e5d854f89: Pull complete 
cfeac5365a22: Pull complete 
7644a931eb75: Pull complete 
9c0257db74bb: Pull complete 
4b687a78d94f: Pull complete 
Digest: sha256:715cc0f52fe1b4f305796a016eeddac84d5a9da02b6f512a955a8a23356112fc
Status: Downloaded newer image for edgecrush3r/tidal-connect:latest
docker.io/edgecrush3r/tidal-connect:latest
Wed Oct 20 21:50:04 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Finished pulling docker image edgecrush3r/tidal-connect:latest.
Wed Oct 20 21:50:04 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Creating .env file.
Wed Oct 20 21:50:04 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Finished creating .env file.
Wed Oct 20 21:50:04 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Generating docker-compose.yml.
Wed Oct 20 21:50:04 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Finished generating docker-compose.yml.
Wed Oct 20 21:50:04 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Enabling TIDAL Connect Service.
Wed Oct 20 21:50:05 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Finished enabling TIDAL Connect Service.
Wed Oct 20 21:50:05 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Adding TIDAL Connect Source to Beocreate.
Tidal extension found, removing previous install...
Adding Tidal Source to Beocreate UI.
Wed Oct 20 21:50:05 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Finished adding TIDAL Connect Source to Beocreate.
Wed Oct 20 21:50:05 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Installation Completed.
Wed Oct 20 21:50:06 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Starting TIDAL Connect Service.

Starting TIDAL Connect Service...
Wed Oct 20 21:50:12 EDT 2021 hifipi1 install.sh[20785]: [INFO]: Restarting Beocreate 2 Service.
Stopping Beocreate 2 Server
Starting Beocreate 2 Server
Done.
```

## Example Run 2

This is an example where we specified to `install.sh` that it should build the image and overrode the default image name.

```
#   BUILD_OR_PULL=build \
>   DOCKER_IMAGE=tidal-connect:latest \
>   ./install_hifiberry.sh
Running environment: 
  FRIENDLY_NAME:            hifipi1
  MODEL_NAME:               hifipi1
  BEOCREATE_SYMLINK_FOLDER: /opt/beocreate/beo-extensions/tidal
  DOCKER_DNS:               8.8.8.8
  DOCKER_IMAGE:             tidal-connect:latest
  BUILD_OR_PULL:            build
  PWD:                      /data/tidal-connect-docker

Wed Oct 20 21:53:09 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Pre-flight checks.
Wed Oct 20 21:53:09 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Checking to see if Docker is running.
Wed Oct 20 21:53:10 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Confirmed that Docker daemon is running.
Wed Oct 20 21:53:10 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Checking to see if Docker image tidal-connect:latest exists.
Wed Oct 20 21:53:10 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Docker image tidal-connect:latest exist on the local machine.
Wed Oct 20 21:53:10 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Creating .env file.
Wed Oct 20 21:53:10 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Finished creating .env file.
Wed Oct 20 21:53:10 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Generating docker-compose.yml.
Wed Oct 20 21:53:10 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Finished generating docker-compose.yml.
Wed Oct 20 21:53:10 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Enabling TIDAL Connect Service.
Wed Oct 20 21:53:11 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Finished enabling TIDAL Connect Service.
Wed Oct 20 21:53:11 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Adding TIDAL Connect Source to Beocreate.
Tidal extension found, removing previous install...
Adding Tidal Source to Beocreate UI.
Wed Oct 20 21:53:11 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Finished adding TIDAL Connect Source to Beocreate.
Wed Oct 20 21:53:11 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Installation Completed.
Wed Oct 20 21:53:11 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Starting TIDAL Connect Service.

Starting TIDAL Connect Service...
Wed Oct 20 21:53:17 EDT 2021 hifipi1 install.sh[21309]: [INFO]: Restarting Beocreate 2 Service.
Stopping Beocreate 2 Server
Starting Beocreate 2 Server
Done.
```

3. Start/Stopping

You can either start or stop the TIDAL Service via the HifiBerryOS Sources menu or via command-line.
If you would rather use command line, you might find these scripts handy.

![hifiberry_startstop](img/hifiberry_tidalcontrol.png?raw=true)

```
./start-tidal-service.sh
./stop-tidal-service.sh
```

You may also use the systemd scripts:
```
systemctl stop tidal.service
systemctl start tidal.service
```

## Troubleshooting

### Device Not Found in TIDAL App? 🔍

**First, try the reset script** - This clears all state and restarts cleanly:
```bash
cd /data/tidal-connect-docker
./reset-tidal.sh
```

This script:
- Stops all services cleanly
- Removes stuck Docker containers
- Clears mDNS cache (restarts Avahi)
- Reloads ALSA state
- Starts everything in the correct order

**If that doesn't work** - Update to latest version:
```bash
cd /data/tidal-connect-docker
git pull
./install_hifiberry.sh  # Re-run install (safe, preserves settings)
```

**Still having issues?** - Try changing device name:
```bash
./fix-name-collision.sh
```

### Run Diagnostics
```bash
./check-tidal-status.sh
```

### Documentation

📚 **[Complete Documentation →](docs/)**

Quick links:
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Fix common issues
- [System Architecture](docs/ARCHITECTURE.md) - How it works
- [Changelog](docs/CHANGELOG.md) - Version history

### Quick Checks

**Check logs**:
```bash
docker logs tidal_connect --tail 50
tail -f /var/log/tidal-watchdog.log
```

**Restart services**:
```bash
systemctl restart avahi-daemon
systemctl restart tidal.service
```

**List audio devices**:
```bash
docker exec tidal_connect /app/ifi-tidal-release/bin/ifi-pa-devs-get 2>/dev/null | grep device#
```

# *** Other Stuff *** #

Build the docker image (OPTIONAL!):

NOTE: I have already uploaded a pre-built docker image to Docker Hub for you.
This means you can skip this time consuming step to build the image manually, and use the pre-built image unless you need to add something to the base image.
However for those who like to thinker, you can add other things to the docker image if you would like to.
```
# Go to the <tidal-connect-docker>/Docker path
cd tidal-connect-docker-master/Docker

# Build the image
./build_docker.sh
```

* Fiddle with Audio Controls and Song Info scraping *

Check out the 'cmd' folder for a bunch of cool bash scripts to control your music (hence you can use to control via Alexa/Google etc).
To scrape song info you can try
```
python scraper.py
```
This will give you all song info in JSON format.

# Tweaking and tuning configuration
If you need to alter any parameters, just change the entrypoint.sh to contain whatever settings you need
The entrypoint.sh file/command is executed upon start of the container and mounted via docker-compose.

