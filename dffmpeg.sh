#!/bin/bash

# This script is a convenience wrapper for running ffmpeg in a docker container from linuxserver.io
# See https://github.com/linuxserver/docker-ffmpeg for further information

# Usage: ./dffmpeg.sh -i INPUTFILE -f "FFMPEG_OPTIONS" OUTFILE

# Examples
# Simple conversion:          ./dffmpeg.sh -i file.wav file.ogg
# Using ffmpeg with options   ./dffmpeg.sh -i file.flac -f "-c:a libfdk_aac" file.m4a

# Parse options
while getopts ":i:f:" opt; do
  case ${opt} in
    i) IN_FILE=$OPTARG ;;
    f) OPTIONS="$OPTARG" ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1 ;;
  esac
done
shift $((OPTIND -1))

OUT_FILE="$@"
DIRNAME=$(dirname "$IN_FILE")
BASENAME=$(basename "$IN_FILE")

# Build docker run command
COMMAND="docker run --rm -it \
  -v ${DIRNAME@Q}:/config \
  linuxserver/ffmpeg \
  -i /config/${BASENAME@Q} \
  ${OPTIONS} \
  /config/${OUT_FILE@Q}"

#echo $COMMAND
eval $COMMAND

exit $?
