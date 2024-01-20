#!/bin/bash

# This script converts media files to Ogg Vorbis format using ffmpeg,
# optionally using a particular libvorbis encoding quality level.
# Supports deleting original files and raising ffmpeg log level.

usage()
{
cat <<EOF
Usage: $0 [-q QUALITY] [-l LOGLEVEL] [-dhv] file..."

Options:
  -q,     Set the quality of the encoding (0-10). Default is 7.
  -l,     Set the ffmpeg log level. Default is error.
  -d,     Delete the original files after converting. Use with care!
  -h,     Display this message.

Arguments:
  file    One or more files to convert.

This script converts audio/video files to OGG format, using ffmpeg and the libvorbis encoder.
EOF
}
# Check for ffmpeg
if ! command -v ffmpeg &> /dev/null; then
  echo "Could not find ffmpeg, is it installed and in the system path?"
  exit 2
fi

# Defaults
QUALITY=7
LOGLEVEL="error"
DELETE=0

# Parse options and arguments
while getopts ":q:ldh" opt; do
  case ${opt} in
    q)
      if [ -n "${OPTARG}" ] && [ "${OPTARG}" -ge 0 ] && [ "${OPTARG}" -le 10 ]; then
        QUALITY=${OPTARG}
      else
        echo "Error: Argument for -q is missing or out of range. QUALITY should be between 0 and 10." >&2
        exit 1
      fi
    ;;
    l) LOGLEVEL=${OPTARG} ;;
    d) DELETE=1 ;;
    h) usage; exit 0;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
    usage; exit 1 ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
    usage; exit 1 ;;
  esac
done
shift $((OPTIND -1))

# Keep track of some info
SPACE_ORIGINALS=0
SPACE_SAVED=0
NUM_CONVERTED=0
NUM_FAILED=0
NUM_SKIPPED=0
NUM_DELETED=0

if [ -z "$@" ]; then
  echo "No arguments provided."
  usage; exit 1
fi

LOSSY_CODECS="MP3 AAC OGG WMA AC3 DTS VORBIS EAC3 TRUEHD LIBTWOLAME MP2 WMAV1 WMAV2 LIBFDK_AAC LIBVORBIS LIBMP3LAME"

convertFile() {
  FILE="$1"
  if [ -f "$FILE" ]; then
    # Gather metadata
    BASENAME=$(basename "$FILE")
    DIRNAME=$(dirname "$FILE")
    NAME="${BASENAME%.*}"
    NEW_FILE="$DIRNAME/$NAME.ogg"
    OLD_CODEC=$(ffprobe "$FILE" 2>&1 | awk -F '[: ,]+' '/Audio/{print toupper($6)}')
    
    # Assume we are not skipping this file
    local SKIP=0
    # Check whether original file contains audio
    if [ -z "$OLD_CODEC" ]; then
      echo "$FILE does not contain audio data according to ffmpeg, skipping conversion"
      SKIP=1
      # Check whether original is encoded with a lossy codec
      elif echo "$LOSSY_CODECS" | grep -q "$OLD_CODEC" && [ -n "$OLD_CODEC" ]; then
      echo "$FILE is already encoded in a lossy format $OLD_CODEC, skipping conversion"
      SKIP=1
      # Check whether a .ogg already exists with the generated name
      elif [ -f "$NEW_FILE" ]; then
      echo "$NEW_FILE already exists, skipping conversion"
      SKIP=1
    fi
    
    if [ $SKIP -eq 0 ]; then
      # Convert file
      ffmpeg -nostats -loglevel "$LOGLEVEL" -i "$FILE" -c:a libvorbis -q:a $QUALITY "$NEW_FILE"
      
      # Check if conversion was successful
      if [ $? -eq 0 ]; then
        echo "Encoding: $BASENAME -> $NEW_FILE"
        
        # Calculate space savings
        ORIGINAL_SIZE=$(du -b "$FILE" | cut -f1)
        let SPACE_ORIGINALS=$SPACE_ORIGINALS+$ORIGINAL_SIZE
        
        NEW_SIZE=$(du -b "$NEW_FILE" | cut -f1)
        let SAVED=$ORIGINAL_SIZE-$NEW_SIZE
        let SPACE_SAVED=$SPACE_SAVED+$SAVED
        
        # Optionally delete original file
        if [ $DELETE -eq 1 ]; then
          rm "$FILE"
          echo "Deleted original file $FILE."
          ((NUM_DELETED++))
        fi
        
        ((NUM_CONVERTED++))
      else
        echo "Conversion of $FILE failed."
        ((NUM_FAILED++))
        
        # Remove results of failed conversion
        rm "$NEW_FILE"
      fi
    else
      ((NUM_SKIPPED++))
    fi
    
  else
    echo "File $FILE not found."
    ((NUM_FAILED++))
  fi
}

# Loop over arguments
for FILE in "$@"; do
  convertFile "$FILE"
done

# Information summary
echo "--- Summary ---"
echo "$NUM_CONVERTED converted, $NUM_FAILED failed, $NUM_SKIPPED skipped, $NUM_DELETED originals deleted"

if [ $SPACE_SAVED -gt 0 ]; then
  SPACE_SAVED_READABLE=$(echo "$SPACE_SAVED" | numfmt --to=iec)
  SIZE_REDUCTION=$( echo "scale=2; 100*$SPACE_SAVED/$SPACE_ORIGINALS" | bc )
  echo "Disk usage savings: $SPACE_SAVED_READABLE"
  echo "File size reduction: $SIZE_REDUCTION%"
fi

exit 0