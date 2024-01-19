#!/bin/bash

# This script converts media files to Ogg Vorbis format using ffmpeg

VERSION=0.1.0

# Defaults
QUALITY=7
LOGLEVEL="error"
DELETE=0

# Check for ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "Could not find ffmpeg, is it installed?"
    exit 2
fi

# Usage statement
usage() {
    echo "Usage: $0 [-q quality] [-l loglevel] [-dhv] file..."
    echo
    echo "Options:"
    echo "  -q,     Set the quality of the encoding (0-10). Default is 7."
    echo "  -l,     Set the ffmpeg log level. Default is error."
    echo "  -d,     Delete the original files after converting. Use with care!"
    echo "  -h,     Display this message."
    echo "  -v,     Display version information."
    echo
    echo "Arguments:"
    echo "  file    One or more files to convert."
    echo
    echo "This script utilizes ffmpeg with the libvorbis encoder to convert audio/video files to OGG format."
}

# Parse arguments
while getopts ":q:ldhv" opt; do
  case ${opt} in
    q)
      if [ -n "${OPTARG}" ] && [ "${OPTARG}" -ge 0 ] && [ "${OPTARG}" -le 10 ]; then
        QUALITY=${OPTARG}
      else
        echo "Error: Argument for -q is missing or out of range. Quality should be between 0 and 10." >&2
        exit 1
      fi
      ;;
    l)
      LOGLEVEL=${OPTARG}
      ;;
    d)
      DELETE=1
      ;;
    h)
      usage
      exit 0
      ;;
    v)
      echo "2ogg version $VERSION"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      exit 1
      ;;
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

if [ -n $@ ]; then
    usage
    exit 1
fi

# Loop over remaining arguments
for FILE in "$@"; do
    if [[ -f $FILE ]]; then
        # Gather metadata
        BASENAME=$(basename "$FILE")
        DIRNAME=$(dirname "$FILE")
        NAME="${BASENAME%.*}"
        NEW_FILE="$DIRNAME/$NAME.ogg"
        OLD_CODEC=$(ffprobe "$FILE" 2>&1 | awk -F '[: ,]+' '/Audio/{print toupper($6)}')

        # Assume we are not skipping this file
        SKIP=0
        # Check whether original file contains audio
        if [ -z "$OLD_CODEC" ]; then
            echo "$FILE does not contain audio data according to ffmpeg, skipping conversion"
            SKIP=1
        # Check whether original is encoded with a lossy codec
        elif echo "MP3 AAC OGG WMA AC3 DTS VORBIS EAC3 TRUEHD LIBTWOLAME MP2 WMAV1 WMAV2 LIBFDK_AAC LIBVORBIS LIBMP3LAME" | grep -q "$OLD_CODEC" && [ -n "$OLD_CODEC" ]; then
            echo "$FILE is already encoded in a lossy format $OLD_CODEC, skipping conversion"
            SKIP=1
        # Check whether a .ogg already exists with the generated name
        elif [[ -f $NEW_FILE ]]; then
            echo "$NEW_FILE already exists, skipping conversion"
            SKIP=1
        fi
        
        if [[ $SKIP -eq 0 ]]; then
            # Convert file
            ffmpeg -nostats -loglevel "$LOGLEVEL" -i "$FILE" -c:a libvorbis -q:a $QUALITY "$NEW_FILE"

            # Check if conversion was successful
            if [[ $? -eq 0 ]]; then
                echo "Encoding: $BASENAME -> $NEW_FILE"
                
                # Calculate space savings
                ORIGINAL_SIZE=$(du -b "$FILE" | cut -f1)
                let SPACE_ORIGINALS=$SPACE_ORIGINALS+$ORIGINAL_SIZE

                NEW_SIZE=$(du -b "$NEW_FILE" | cut -f1)
                let SAVED=$ORIGINAL_SIZE-$NEW_SIZE
                let SPACE_SAVED=$SPACE_SAVED+$SAVED

                # Optionally delete original file
                if [[ $DELETE -eq 1 ]]; then
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
done

# Information summary
echo "--- Summary ---"
echo "$NUM_CONVERTED converted, $NUM_FAILED failed, $NUM_SKIPPED skipped, $NUM_DELETED originals deleted"

if [[ $SPACE_SAVED -gt 0 ]]; then
    SPACE_SAVED_READABLE=$(echo "$SPACE_SAVED" | numfmt --to=iec)
    SPACE_SAVED_PERCENTAGE=$( echo "scale=2; 100*$SPACE_SAVED/$SPACE_ORIGINALS" | bc )
    echo "Disk usage savings: $SPACE_SAVED_READABLE"
    echo "Compression rate: $SPACE_SAVED_PERCENTAGE%"
fi

exit 0