#!/bin/bash

log() {
  script=$(basename "$0")
  echo "$(/bin/date) ${HOSTNAME} ${script}[$$]: [$1]: $2"
}

running_environment()
{
  echo "Running environment: "
  echo "  FRIENDLY_NAME:            ${FRIENDLY_NAME}"
  echo "  MODEL_NAME:               ${MODEL_NAME}"
  echo "  BEOCREATE_SYMLINK_FOLDER: ${BEOCREATE_SYMLINK_FOLDER}"
  echo "  DOCKER_DNS:               ${DOCKER_DNS}"
  echo "  DOCKER_IMAGE:             ${DOCKER_IMAGE}"
  echo "  BUILD_OR_PULL:            ${BUILD_OR_PULL}"
  echo "  MQA_PASSTHROUGH:          ${MQA_PASSTHROUGH}"
  echo "  MQA_CODEC:                ${MQA_CODEC}"
  echo "  PWD:                      ${PWD}"
  echo ""
}

usage()
{
  echo "$0 installs TIDAL Connect on your Raspberry Pi."
  echo ""
  echo "Usage: "
  echo ""
  echo "  [FRIENDLY_NAME=<FRIENDLY_NAME>] \\"
  echo "  [MODEL_NAME=<MODEL_NAME>] \\"
  echo "  [BEOCREATE_SYMLINK_FOLDER=<BEOCREATE_SYMLINK_FOLDER>] \\"
  echo "  [DOCKER_DNS=<DOCKER_DNS>] \\"
  echo "  [DOCKER_IMAGE=<DOCKER_IMAGE>] \\"
  echo "  [BUILD_OR_PULL=<build|pull>] \\"
  echo "  [MQA_PASSTHROUGH=<true|false>] \\"
  echo "  [MQA_CODEC=<true|false>] \\"
  echo "  $0 \\"
  echo "    [-f <FRIENDLY_NAME>] \\"
  echo "    [-m <MODEL_NAME>] \\"
  echo "    [-b <BEOCREATE_SYMLINK_FOLDER>] \\"
  echo "    [-d <DOCKER_DNS>] \\"
  echo "    [-i <Docker Image>] \\"
  echo "    [-p <build|pull>] \\"
  echo "    [-t <true|false>] \\"
  echo "    [-c <true|false>"
  echo ""
  echo "Defaults:"
  echo "  FRIENDLY_NAME:            ${FRIENDLY_NAME_DEFAULT}"
  echo "  MODEL_NAME:               ${MODEL_NAME_DEFAULT}"
  echo "  BEOCREATE_SYMLINK_FOLDER: ${BEOCREATE_SYMLINK_FOLDER_DEFAULT}"
  echo "  DOCKER_DNS:               ${DOCKER_DNS_DEFAULT}"
  echo "  DOCKER_IMAGE:             ${DOCKER_IMAGE_DEFAULT}"
  echo "  BUILD_OR_PULL:            ${BUILD_OR_PULL_DEFAULT}"
  echo "  MQA_PASSTHROUGH:          ${MQA_PASSTHROUGH_DEFAULT}"
  echo "  MQA_CODEC:                ${MQA_CODEC_DEFAULT}"
  echo ""

  echo "Example: "
  echo "  BUILD_OR_PULL=build \\"
  echo "  DOCKER_IMAGE=tidal-connect:latest \\"
  echo "  MQA_PASSTHROUGH=true \\"
  echo "  $0"
  echo ""

  running_environment

  echo "Please note that command line arguments "
  echo "take precedence over environment variables,"
  echo "which take precedence over defaults."
  echo ""
}

select_playback_device()
{
  ARRAY_DEVICES=()
  
  echo ""
  echo "Scanning for audio output devices..."
  
  # Try to get devices using docker run (container doesn't need to be running)
  DEVICES=$(docker run --rm --device /dev/snd \
    --entrypoint "" \
    ${DOCKER_IMAGE} \
    /app/ifi-tidal-release/bin/ifi-pa-devs-get 2>/dev/null | grep device#)

  if [ -z "$DEVICES" ]; then
    log ERROR "Could not detect audio devices. Trying alternative method..."
    # Fallback: try to use aplay to list devices
    DEVICES=$(aplay -l 2>/dev/null | grep -E "^card [0-9]+:" | head -5)
    if [ -z "$DEVICES" ]; then
      log ERROR "No audio devices found. Using default device."
      PLAYBACK_DEVICE="default"
      return
    fi
  fi

  echo ""
  echo "Found output devices:"
  echo ""
  
  #make newlines the only separator
  IFS=$'\n'
  re_parse="^device#([0-9])+=(.*)$"
  device_count=0
  for line in $DEVICES
  do
    if [[ $line =~ $re_parse ]]
    then
      device_num="${BASH_REMATCH[1]}"
      device_name="${BASH_REMATCH[2]}"

      echo "  ${device_num}=${device_name}"
      ARRAY_DEVICES+=( "${device_name}" )
      device_count=$((device_count + 1))
    fi
  done

  if [ $device_count -eq 0 ]; then
    log ERROR "No valid audio devices found. Using default device."
    PLAYBACK_DEVICE="default"
    return
  fi

  echo ""
  while :; do
    read -ep "Choose your output Device (0-$((device_count-1))): " number
    [[ $number =~ ^[[:digit:]]+$ ]] || { echo "Please enter a number."; continue; }
    (( ( (number=(10#$number)) <= $((device_count-1)) ) && number >= 0 )) || { echo "Please enter a number between 0 and $((device_count-1))."; continue; }
    break
  done

  PLAYBACK_DEVICE="${ARRAY_DEVICES[$number]}"
  
  if [ -z "$PLAYBACK_DEVICE" ]; then
    log ERROR "Invalid device selection. Using default device."
    PLAYBACK_DEVICE="default"
  else
    echo ""
    echo "Selected: ${PLAYBACK_DEVICE}"
  fi
}


# define defaults
FRIENDLY_NAME_DEFAULT=${HOSTNAME}
MODEL_NAME_DEFAULT=${HOSTNAME}
BEOCREATE_SYMLINK_FOLDER_DEFAULT="/opt/beocreate/beo-extensions/tidal"
DOCKER_DNS_DEFAULT="8.8.8.8"
DOCKER_IMAGE_DEFAULT="edgecrush3r/tidal-connect:latest"
BUILD_OR_PULL_DEFAULT="pull"
MQA_PASSTHROUGH_DEFAULT="false"
MQA_CODEC_DEFAULT="false"
PLAYBACK_DEVICE="default"

# override defaults with environment variables, if they have been set
FRIENDLY_NAME=${FRIENDLY_NAME:-${FRIENDLY_NAME_DEFAULT}}
MODEL_NAME=${MODEL_NAME:-${MODEL_NAME_DEFAULT}}
BEOCREATE_SYMLINK_FOLDER=${BEOCREATE_SYMLINK_FOLDER:-${BEOCREATE_SYMLINK_FOLDER_DEFAULT}}
DOCKER_DNS=${DOCKER_DNS:-${DOCKER_DNS_DEFAULT}}
DOCKER_IMAGE=${DOCKER_IMAGE:-${DOCKER_IMAGE_DEFAULT}}
BUILD_OR_PULL=${BUILD_OR_PULL:-${BUILD_OR_PULL_DEFAULT}}
MQA_PASSTHROUGH=${MQA_PASSTHROUGH:-${MQA_PASSTHROUGH_DEFAULT}}
MQA_CODEC=${MQA_CODEC:-${MQA_CODEC_DEFAULT}}

HELP=${HELP:-0}
VERBOSE=${VERBOSE:-0}

# override with command line parameters, if defined
while getopts "hvf:m:b:d:i:p:t:c:" option
do
  case ${option} in
    f)
      FRIENDLY_NAME=${OPTARG}
      ;;
    m)
      MODEL_NAME=${OPTARG}
      ;;
    b)
      BEOCREATE_SYMLINK_FOLDER=${OPTARG}
      ;;
    d)
      DOCKER_DNS=${OPTARG}
      ;;
    i)
      DOCKER_IMAGE=${OPTARG}
      ;;
    p)
      BUILD_OR_PULL=${OPTARG}
      ;;
    t)
      MQA_PASSTHROUGH=${OPTARG}
      ;;
    c)
      MQA_CODEC=${OPTARG}
      ;;
    v)
      VERBOSE=1
      ;;
    h)
      HELP=1
      usage
      exit 0
      ;;
  esac
done

running_environment

log INFO "Pre-flight checks."

log INFO "Checking to see if Docker is running."
docker info &> /dev/null
if [ $? -ne 0 ]
then
  log ERROR "Docker daemon isn't running."
  exit 1
else
  log INFO "Confirmed that Docker daemon is running."
fi

log INFO "Checking to see if Docker image ${DOCKER_IMAGE} exists."
docker inspect --type=image ${DOCKER_IMAGE} &> /dev/null
if [ $? -eq 0 ]
then
  log INFO "Docker image ${DOCKER_IMAGE} exist on the local machine."
  DOCKER_IMAGE_EXISTS=1
else
  log INFO "Docker image ${DOCKER_IMAGE} does not exist on local machine."
  DOCKER_IMAGE_EXISTS=0
fi

# Pull latest image or build Docker image if it doesn't already exist.
if [ ${DOCKER_IMAGE_EXISTS} -eq 0 ]
then
  if [ "${BUILD_OR_PULL}" == "pull" ]
  then
    # Pulling latest image
    log INFO "Pulling docker image ${DOCKER_IMAGE}."
    docker pull ${DOCKER_IMAGE}
    log INFO "Finished pulling docker image ${DOCKER_IMAGE}."
  elif [ "${BUILD_OR_PULL}" == "build" ]
  then
    log INFO "Building docker image."
    cd Docker && \
    DOCKER_IMAGE=${DOCKER_IMAGE} ./build_docker.sh && \
    cd ..
    log INFO "Finished building docker image."
  else
    log ERROR "BUILD_OR_PULL must be set to \"build\" or \"pull\""
    usage
    exit 1
  fi

  docker inspect --type=image ${DOCKER_IMAGE} &> /dev/null
  if [ $? -ne 0 ]
  then
    log ERROR "Docker image ${DOCKER_IMAGE} does not exist on the local machine even after we tried ${BUILD_OR_PULL}ing it."
    log ERROR "Exiting."
    exit 1
  fi
fi

if [ "$(docker ps -q -f name=tidal_connect)" ]; then
  log INFO "Stopping Tidal Container.."
  ./stop-tidal-service.sh
fi

log INFO "Select audio output device"
select_playback_device

# Validate that a device was selected
if [ -z "$PLAYBACK_DEVICE" ]; then
  log ERROR "No playback device selected. Installation cannot continue."
  exit 1
fi

log INFO "Playback device set to: ${PLAYBACK_DEVICE}"

log INFO "Creating .env file."
ENV_FILE="${PWD}/Docker/.env"
CONFIG_FILE="${PWD}/Docker/CONFIG"

> ${ENV_FILE}
echo "FRIENDLY_NAME=${FRIENDLY_NAME}" >> ${ENV_FILE}
echo "MODEL_NAME=${MODEL_NAME}" >> ${ENV_FILE}
echo "MQA_PASSTHROUGH=${MQA_PASSTHROUGH}" >> ${ENV_FILE}
echo "MQA_CODEC=${MQA_CODEC}" >> ${ENV_FILE}
echo "PLAYBACK_DEVICE=${PLAYBACK_DEVICE}" >> ${ENV_FILE}
log INFO "Finished creating .env file."

if [ -L "${CONFIG_FILE}" ]; then
 log INFO "${CONFIG_FILE} already exists. this file will be replaced with new configuration."
 rm "${CONFIG_FILE}"
fi
log INFO "Create config symlink -> ${ENV_FILE}"
ln -s ${ENV_FILE} ${CONFIG_FILE}

# Generate docker-compose.yml
log INFO "Generating docker-compose.yml."
eval "echo \"$(cat templates/docker-compose.yml.tpl)\"" > Docker/docker-compose.yml
log INFO "Finished generating docker-compose.yml."

# Enable service
log INFO  "Enabling TIDAL Connect Service."
eval "echo \"$(cat templates/tidal.service.tpl)\"" >/etc/systemd/system/tidal.service

systemctl enable tidal.service

log INFO "Finished enabling TIDAL Connect Service."

# Enable volume bridge service
log INFO  "Enabling TIDAL Connect Volume Bridge Service."
eval "echo \"$(cat templates/tidal-volume-bridge.service.tpl)\"" >/etc/systemd/system/tidal-volume-bridge.service

systemctl enable tidal-volume-bridge.service

log INFO "Finished enabling TIDAL Connect Volume Bridge Service."

# Enable watchdog service for auto-recovery
log INFO  "Enabling TIDAL Connect Watchdog Service."
eval "echo \"$(cat templates/tidal-watchdog.service.tpl)\"" >/etc/systemd/system/tidal-watchdog.service

systemctl enable tidal-watchdog.service

log INFO "Finished enabling TIDAL Connect Watchdog Service."

# Install AudioControl2 integration (metadata and web UI controls)
if [ -f "/opt/audiocontrol2/audiocontrol2.py" ]; then
  log INFO "Installing TIDAL Connect AudioControl2 Integration."
  
  # Create symlink to tidalcontrol.py
  DST_PLAYER_FILE="/opt/audiocontrol2/ac2/players/tidalcontrol.py"
  rm -f "$DST_PLAYER_FILE"
  ln -s "${PWD}/work-in-progress/audiocontrol2/tidalcontrol.py" "$DST_PLAYER_FILE"
  
  AC_CONTROL_FILE="/opt/audiocontrol2/audiocontrol2.py"
  
  # Check if already configured
  if ! grep -q "from ac2.players.tidalcontrol import TidalControl" "$AC_CONTROL_FILE"; then
    log INFO "Configuring AudioControl2 for Tidal integration."
    
    # Add import
    sed -i '/^from ac2\.players\.vollibrespot import MYNAME as SPOTIFYNAME$/a from ac2.players.tidalcontrol import TidalControl' "$AC_CONTROL_FILE"
    
    # Add registration
    PLACEHOLDER="$(sed -nE 's/^(.*)mpris\.register_nonmpris_player\(SPOTIFYNAME,vlrctl\)$/\1/p' "$AC_CONTROL_FILE")"
    sed -i "/mpris.register_nonmpris_player(SPOTIFYNAME,vlrctl)/a \\\n${PLACEHOLDER}# TidalControl\n${PLACEHOLDER}tdctl = TidalControl()\n${PLACEHOLDER}tdctl.start()\n${PLACEHOLDER}mpris.register_nonmpris_player(tdctl.playername,tdctl)" "$AC_CONTROL_FILE"
  else
    log INFO "AudioControl2 already configured for Tidal."
  fi
  
  # Create service override to ensure audiocontrol2 starts after tidal
  AC_OVERRIDE_DIR="/etc/systemd/system/audiocontrol2.service.d"
  mkdir -p "$AC_OVERRIDE_DIR"
  
  cat > "$AC_OVERRIDE_DIR/tidal-integration.conf" <<EOF
[Unit]
# Ensure AudioControl2 starts after Tidal Connect
After=tidal.service
Wants=tidal.service
EOF
  
  systemctl daemon-reload
  systemctl restart audiocontrol2 2>/dev/null || true
  
  log INFO "Finished installing AudioControl2 integration."
else
  log INFO "AudioControl2 not found - skipping UI integration (metadata will still work via JSON file)."
fi

# Add TIDAL Connect Source to Beocreate
log INFO "Adding TIDAL Connect Source to Beocreate."
if [ -L "${BEOCREATE_SYMLINK_FOLDER}" ]; then
  # Already installed... remove symlink and re-install
  log INFO "TIDAL Connect extension found, removing previous install."
  rm ${BEOCREATE_SYMLINK_FOLDER}
fi

log INFO "Adding TIDAL Connect Source to Beocreate UI."
ln -s ${PWD}/beocreate/beo-extensions/tidal ${BEOCREATE_SYMLINK_FOLDER}
log INFO "Finished adding TIDAL Connect Source to Beocreate."

# Ensure scripts are executable
log INFO "Setting script permissions."
chmod +x ${PWD}/volume-bridge.sh 2>/dev/null || true
chmod +x ${PWD}/tidal-watchdog.sh 2>/dev/null || true
chmod +x ${PWD}/start-tidal-service.sh 2>/dev/null || true
chmod +x ${PWD}/stop-tidal-service.sh 2>/dev/null || true

log INFO "Installation Completed."

if [ "$(docker ps -q -f name=docker_tidal-connect)" ]; then
  log INFO "Stopping TIDAL Connect Service."
  ./stop-tidal-service.sh
fi

log INFO "Starting TIDAL Connect Service."
./start-tidal-service.sh

log INFO "Restarting Beocreate 2 Service."
./restart_beocreate2

log INFO "=========================================="
log INFO "TIDAL Connect Installation Complete!"
log INFO "=========================================="
log INFO ""
log INFO "Installed Features:"
log INFO "  ✓ TIDAL Connect service"
log INFO "  ✓ Volume bridge (phone volume control)"
log INFO "  ✓ Connection watchdog (auto-recovery)"
if [ -f "/opt/audiocontrol2/audiocontrol2.py" ]; then
  log INFO "  ✓ AudioControl2 integration (metadata + UI controls)"
fi
log INFO ""
log INFO "Your device should now be visible in TIDAL as: ${FRIENDLY_NAME}"
log INFO ""
log INFO "To verify installation:"
log INFO "  systemctl status tidal.service"
log INFO "  systemctl status tidal-volume-bridge.service"
log INFO "  systemctl status tidal-watchdog.service"
if [ -f "/opt/audiocontrol2/audiocontrol2.py" ]; then
  log INFO "  curl http://127.0.0.1:81/api/player/status"
fi
log INFO ""
log INFO "To view logs:"
log INFO "  docker logs -f tidal_connect"
log INFO "  tail -f /var/log/tidal-watchdog.log"
log INFO ""
log INFO "Documentation:"
log INFO "  README.md - Main documentation"
log INFO "  WATCHDOG.md - Connection resilience info"
log INFO "  work-in-progress/audiocontrol2/README.md - UI integration info"
log INFO ""
log INFO "Finished, exiting."
