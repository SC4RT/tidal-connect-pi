#!/bin/bash

echo -e "\e[33m
                                                        
                                                        
 .M\"\"\"bgd   .g8\"\"\"bgd           \`7MM\"\"\"Mq. MMP\"\"MM\"\"YMM 
,MI    \"Y .dP'     \`M             MM   \`MM.P'   MM   \`7 
\`MMb.     dM'       \`     ,AM     MM   ,M9      MM      
  \`YMMNq. MM             AVMM     MMmmdM9       MM      
.     \`MM MM.          ,W' MM     MM  YM.       MM      
Mb     dM \`Mb.     ,',W'   MM     MM   \`Mb.     MM      
P\"Ybmmd\"    \`\"bmmmd' AmmmmmMMmm .JMML. .JMM.  .JMML.    
                           MM                           
                           MM
\e[0m
"

log() {
  script=$(basename "$0")
  echo "$(/bin/date) ${HOSTNAME} ${script}[$$]: [$1]: $2"
}

running_environment()
{
  echo "Running environment: "
  echo "  FRIENDLY_NAME:            ${FRIENDLY_NAME}"
  echo "  MODEL_NAME:               ${MODEL_NAME}"
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
  echo "  [DOCKER_DNS=<DOCKER_DNS>] \\"
  echo "  [DOCKER_IMAGE=<DOCKER_IMAGE>] \\"
  echo "  [BUILD_OR_PULL=<build|pull>] \\"
  echo "  [MQA_PASSTHROUGH=<true|false>] \\"
  echo "  [MQA_CODEC=<true|false>] \\"
  echo "  $0 \\"
  echo "    [-f <FRIENDLY_NAME>] \\"
  echo "    [-m <MODEL_NAME>] \\"
  echo "    [-d <DOCKER_DNS>] \\"
  echo "    [-i <Docker Image>] \\"
  echo "    [-p <build|pull>] \\"
  echo "    [-t <true|false>] \\"
  echo "    [-c <true|false>"
  echo ""
  echo "Defaults:"
  echo "  FRIENDLY_NAME:            ${FRIENDLY_NAME_DEFAULT}"
  echo "  MODEL_NAME:               ${MODEL_NAME_DEFAULT}"
  echo "  DOCKER_DNS:               ${DOCKER_DNS_DEFAULT}"
  echo "  DOCKER_IMAGE:             ${DOCKER_IMAGE_DEFAULT}"
  echo "  BUILD_OR_PULL:            ${BUILD_OR_PULL_DEFAULT}"
  echo "  MQA_PASSTHROUGH:          ${MQA_PASSTHROUGH_DEFAULT}"
  echo "  MQA_CODEC:                ${MQA_CODEC_DEFAULT}"
  echo ""
  running_environment
}

select_playback_device()
{
  ARRAY_DEVICES=()
  echo ""
  echo "Scanning for audio output devices..."
  DEVICES=$(docker run --rm --device /dev/snd --entrypoint "" ${DOCKER_IMAGE} /app/ifi-tidal-release/bin/ifi-pa-devs-get 2>/dev/null | grep device#)
  if [ -z "$DEVICES" ]; then
    log ERROR "Could not detect audio devices. Trying alternative method..."
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
  IFS=$'\n'
  device_count=0
  for line in $DEVICES
  do
    if [[ "$line" =~ ^device#([0-9]+)=(.*)$ ]]; then
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

FRIENDLY_NAME_DEFAULT=${HOSTNAME}
MODEL_NAME_DEFAULT=${HOSTNAME}
DOCKER_DNS_DEFAULT="8.8.8.8"
DOCKER_IMAGE_DEFAULT="edgecrush3r/tidal-connect:latest"
BUILD_OR_PULL_DEFAULT="pull"
MQA_PASSTHROUGH_DEFAULT="false"
MQA_CODEC_DEFAULT="false"
PLAYBACK_DEVICE="default"

FRIENDLY_NAME=${FRIENDLY_NAME:-${FRIENDLY_NAME_DEFAULT}}
MODEL_NAME=${MODEL_NAME:-${MODEL_NAME_DEFAULT}}
DOCKER_DNS=${DOCKER_DNS:-${DOCKER_DNS_DEFAULT}}
DOCKER_IMAGE=${DOCKER_IMAGE:-${DOCKER_IMAGE_DEFAULT}}
BUILD_OR_PULL=${BUILD_OR_PULL:-${BUILD_OR_PULL_DEFAULT}}
MQA_PASSTHROUGH=${MQA_PASSTHROUGH:-${MQA_PASSTHROUGH_DEFAULT}}
MQA_CODEC=${MQA_CODEC:-${MQA_CODEC_DEFAULT}}

HELP=${HELP:-0}
VERBOSE=${VERBOSE:-0}

while getopts "hvf:m:d:i:p:t:c:" option
do
  case ${option} in
    f) FRIENDLY_NAME=${OPTARG} ;;
    m) MODEL_NAME=${OPTARG} ;;
    d) DOCKER_DNS=${OPTARG} ;;
    i) DOCKER_IMAGE=${OPTARG} ;;
    p) BUILD_OR_PULL=${OPTARG} ;;
    t) MQA_PASSTHROUGH=${OPTARG} ;;
    c) MQA_CODEC=${OPTARG} ;;
    v) VERBOSE=1 ;;
    h) HELP=1; usage; exit 0 ;;
  esac
done

running_environment

if systemctl is-active --quiet tidal.service 2>/dev/null || docker ps -a | grep -q tidal_connect; then
  log INFO "Existing installation detected, performing cleanup..."
  systemctl stop tidal-watchdog.service 2>/dev/null || true
  systemctl stop tidal-volume-bridge.service 2>/dev/null || true
  systemctl stop tidal.service 2>/dev/null || true
  docker rm -f tidal_connect 2>/dev/null || true
  systemctl reset-failed tidal.service 2>/dev/null || true
  systemctl reset-failed tidal-volume-bridge.service 2>/dev/null || true
  systemctl reset-failed tidal-watchdog.service 2>/dev/null || true
  sleep 2
  log INFO "Cleanup complete"
fi

docker info &> /dev/null || { log ERROR "Docker daemon isn't running."; exit 1; }
docker inspect --type=image ${DOCKER_IMAGE} &> /dev/null
DOCKER_IMAGE_EXISTS=$?
if [ ${DOCKER_IMAGE_EXISTS} -ne 0 ]; then
  if [ "${BUILD_OR_PULL}" == "pull" ]; then
    docker pull ${DOCKER_IMAGE}
  elif [ "${BUILD_OR_PULL}" == "build" ]; then
    cd Docker && DOCKER_IMAGE=${DOCKER_IMAGE} ./build_docker.sh && cd ..
  else
    log ERROR "BUILD_OR_PULL must be \"build\" or \"pull\""; usage; exit 1
  fi
fi

if [ "$(docker ps -q -f name=tidal_connect)" ]; then
  ./stop-tidal-service.sh
fi

select_playback_device
[ -z "$PLAYBACK_DEVICE" ] && { log ERROR "No playback device selected. Installation cannot continue."; exit 1; }

ENV_FILE="${PWD}/Docker/.env"
CONFIG_FILE="${PWD}/Docker/CONFIG"
> ${ENV_FILE}
echo "FRIENDLY_NAME=${FRIENDLY_NAME}" >> ${ENV_FILE}
echo "MODEL_NAME=${MODEL_NAME}" >> ${ENV_FILE}
echo "MQA_PASSTHROUGH=${MQA_PASSTHROUGH}" >> ${ENV_FILE}
echo "MQA_CODEC=${MQA_CODEC}" >> ${ENV_FILE}
echo "PLAYBACK_DEVICE=${PLAYBACK_DEVICE}" >> ${ENV_FILE}
[ -L "${CONFIG_FILE}" ] && rm "${CONFIG_FILE}"
ln -s ${ENV_FILE} ${CONFIG_FILE}

eval "echo \"$(cat templates/docker-compose.yml.tpl)\"" > Docker/docker-compose.yml
eval "echo \"$(cat templates/tidal.service.tpl)\"" >/etc/systemd/system/tidal.service
systemctl enable tidal.service
eval "echo \"$(cat templates/tidal-volume-bridge.service.tpl)\"" >/etc/systemd/system/tidal-volume-bridge.service
systemctl enable tidal-volume-bridge.service
eval "echo \"$(cat templates/tidal-watchdog.service.tpl)\"" >/etc/systemd/system/tidal-watchdog.service
systemctl enable tidal-watchdog.service

chmod +x ${PWD}/volume-bridge.sh ${PWD}/tidal-watchdog.sh ${PWD}/wait-for-avahi.sh \
       ${PWD}/wait-for-container.sh ${PWD}/wait-for-mdns-clear.sh \
       ${PWD}/start-tidal-service.sh ${PWD}/stop-tidal-service.sh \
       ${PWD}/check-tidal-status.sh ${PWD}/fix-name-collision.sh

if [ "$(docker ps -q -f name=docker_tidal-connect)" ]; then
  ./stop-tidal-service.sh
fi

./start-tidal-service.sh
