#!/bin/bash

# This script saves the contents of optical discs (CD/DVD) to ISO image files,
# optionally compressed with tar and gzip.
# Supports adding multiple discs to one tarball.

# Inspirations:
# https://www.linuxjournal.com/content/archiving-cds-iso-commandline
# http://www.troubleshooters.com/linux/coasterless.htm

set -e

usage()
{
cat <<EOF
Usage: $0 [-hwtzimn] [-l LABEL] [-k LICENSE_KEY] [-o OUTPUT_DIR]
-h	Show this message
-w	Write ISO image to disk (default mode is dryrun)
-t	Create a tar archive to hold generated files
-z	Use gzip compression when creating tar archive
-i	Add multiple discs interactively
-m	Write meta data from disc to a text file
-n	Do not verify generated ISO images against the original disc
-s  Summarize
-l	Specifiy custom LABEL
-k	Add a text file containing the string LICENSE_KEY
-o	Specify directory OUTPUT_DIR in which to place generated images

Exit status definition:
0	Normal operation
1	Syntax error
2	No optical drive DEVICE found
3	No optical disc found
4	Fatal error reading optical disc block size or block count
5	Verification of image failed
EOF
}

# Default settings, can be overridden with options
VERIFYIMAGE=true
METADATAFILE=false
ADDLICENSEKEY=false
DRYRUN=true
MAKETAR=false
GZIP=false
MULTIPLEDISCS=false
OUTDIR=`readlink -f .`
SUMMARIZE=false

# Process options and arguments
while getopts 'hnmwtzisl:k:o:' OPTION; do
  case $OPTION in
    h)	usage; 	exit 0 ;;
    n)	VERIFYIMAGE=false ;;
    m)	METADATAFILE=true ;;
    w)	DRYRUN=false ;;
    t)	MAKETAR=true ;;
    z)	GZIP=true ;;
    i)	MULTIPLEDISCS=true; discNum=1 ;;
    s)  SUMMARIZE=true ;;
    l)	LABEL="$OPTARG" ;;
    k)	KEY="$OPTARG" ;;
    o)	setOutDir "$OPTARG" ;;
    ?)	usage; exit 1 ;;
  esac
done
shift $((OPTIND-1))

main() {
  checkDevice
  checkMediaPresence
  makeLabel
  getDiscInfo
  if $DRYRUN || $SUMMARIZE; then
    echo "DISC AND DRIVE INFORMATION"
    echo "Device: $DEVICE"
    echo "Title: $TITLE"
    echo "Publisher: $PUBLISHER"
    echo "UUID: $UUID"
    echo "Disc block size: $blocksize"
    echo "Disc block count: $blockcount"
    echo ""
    echo "OPTIONS"
    echo "Label: $LABEL"
    echo "License key: $KEY"
    echo "Output directory: $OUTDIR"
    echo "Verify ISO image against original disc (recommended): $VERIFYIMAGE"
    echo "Write disc hardware metadata to text file: $METADATAFILE"
    echo "Create tar archive: $MAKETAR"
    echo "Use gzip compression for tar archive: $GZIP"
    echo "Add multiple discs interactively: $MULTIPLEDISCS"
    if $DRYRUN; then
      echo "--- This is a dryrun, no data will be written ---"
      exit 0
    fi
  fi
  
  # Check sanity
  if ! $MAKETAR && $GZIP; then
    echo "Error: Gzip compression is only supported for tar archives."
    echo "Use -zt rather than -z."
    usage
    exit 1
  fi
  
  # Create temp folder
  TEMPDIR=`mktemp -d`
  
  # Generate LABEL for file naming
  makeLabel
  
  # Add license key text file
  if [[ $KEY ]]; then
    echo "$KEY" > "${TEMPDIR}/${LABEL}_license_key.txt"
  fi
  
  # If adding multiple discs, start ISO creation loop
  if $MULTIPLEDISCS; then
    while true; do
      
      checkMediaPresence
      
      makeImage $discNum
      
      (( discNum++ ))
      
      read -p "Add another disc (y/n)? " yn
      case $yn in
        [Yy]* ) continue ;;
        [Nn]* ) break ;;
        * ) echo "Please answer yes (y) or no (n)." ;;
      esac
    done
  else # Just creating a single ISO image
    makeImage
  fi
  
  if $MAKETAR; then
    TARBALL="${OUTDIR}/${LABEL}.tar"
    if $GZIP; then
      checkForExistingFile "$TARBALL.gz"
      tar --create --gzip --verbose --file="$TARBALL.gz" --directory="${TEMPDIR}" .
    else
      checkForExistingFile "$TARBALL"
      tar --create --verbose --file="$TARBALL" --directory="${TEMPDIR}" .
    fi
  else
    for file in "$TEMPDIR/*"; do
      fileName=`basename "$file"`
      checkForExistingFile "$OUTDIR/$fileName"
      cp "$file" "$OUTDIR"
    done
  fi
  
  echo "Done."
  quitRmTemp 0
}

# Functions to check various conditions
checkDevice() {
  DEVICE=`udevadm info -q property /dev/cdrom | grep DEVNAME | cut -d "=" -f 2`
  
  if [[ -z $DEVICE ]]; then
    echo "No optical drive found" >&2
    exit 2
  fi
}

checkMediaPresence() {
  local mediaPresent=false
  while ! $mediaPresent; do
    udevadm info -q property /dev/cdrom | grep "ID_CDROM_MEDIA=1" > /dev/null
    mediaPresent=`[ $? -eq 0 ]`
    if ! $mediaPresent; then
      read -p "No optical disc found. Retry (r) or abort (a)?" ra
      case $ra in
        [Rr]* ) echo "Retrying..." ;;
        [Aa]* ) quitRmTemp 3 ;;
        * ) echo "Please answer retry (r) or abort (a)." ;;
      esac
    fi
  done
}

checkForExistingFile() {
  if [ -e "$1" ]; then
    while true; do
      read -p "WARNING: "$1" already exists, overwrite (o) or abort (a)? Aborting will delete all generated temporary files." soa
      case $oa in
        [Oo]* ) break ;;
        [Aa]* ) quitRmTemp 0 ;;
        * ) echo "Please press (o) to overwrite or (a) to abort." ;;
      esac
    done
  fi
}


# Image creation functionality
makeImage() {
  checkMediaPresence
  getDiscInfo
  
  # Generate file paths
  local discSubStr=""
  if $MULTIPLEDISCS; then
    discSubStr="_disc$1"
  fi
  
  local isoFile="${LABEL}${discSubStr}.iso"
  
  local isoFilePath="${TEMPDIR}/$isoFile"
  
  checkForExistingFile "$isoFilePath"
  
  # Create image
  echo "Creating $isoFile"
  dd if=$DEVICE bs=$blocksize count=$blockcount of="$isoFilePath" status=progress
  
  
  if $METADATAFILE; then
    local infoFile="${isoFilePath}_info.txt"
    checkForExistingFile "$infoFile"
    isoinfo -d -i $DEVICE > "${infoFile}"
  fi
  
  if $VERIFYIMAGE; then
    echo "Hang on while $isoFile is being verified against the original disc..."
    local md5disc=`dd if=$DEVICE bs=$blocksize count=$blockcount | md5sum` &> /dev/null
    local md5iso=`cat "$isoFilePath" | md5sum` &> /dev/null
    if [ "$md5disc" != "$md5iso" ]; then
      echo "Verification failed :("
      echo "Optical disc MD5:	$md5disc"
      echo "ISO image MD5:	$md5iso"
      
      # TODO: Allow retry in case of verification failure
      
      quitRmTemp 5
    else
      echo "Verification success :)"
    fi
  fi
}

makeLabel() {
  # Get title, publisher name, and uuid as stored in disc metadata
  TITLE=`udevadm info -q property /dev/cdrom | grep "ID_FS_LABEL=" | cut -d "=" -f 2`
  PUBLISHER=`udevadm info -q property /dev/cdrom | grep "ID_FS_PUBLISHER_ID=" | cut -d "=" -f 2`
  UUID=`udevadm info -q property /dev/cdrom | grep "ID_FS_UUID=" | cut -d "=" -f 2`
  
  # Generate label if not supplied by user
  if [ -z $LABEL ]; then
    if [ -z "$TITLE" ]; then
      if [ -z "$PUBLISHER" ]; then
        LABEL="$UUID"
        echo "Disk doesn't contain information about title or publisher."
        echo "$UUID will be used for the label."
      else
        LABEL="$PUBLISHER"
      fi
    else
      LABEL="$TITLE"
    fi
  fi
}

getDiscInfo() {
  # Get disc block size
  blocksize=`isoinfo -d -i $DEVICE | grep "^Logical block size is:" | cut -d " " -f 5`
  if [ -z "$blocksize" ]; then
    echo "Error reading optical disc: Blank block size" >&2
    quitRmTemp 4
  fi
  
  # Get disc block count
  blockcount=`isoinfo -d -i $DEVICE | grep "^Volume size is:" | cut -d " " -f 4`
  if [ -z "$blockcount" ]; then
    echo "Error reading optical disc: Blank block count" >&2
    quitRmTemp 4
  fi
}

# Utility functions
setOutDir() {
  if ! [ -d "$1" ]; then
    echo "Error: $OPTARG is not a directory" >&2
    exit 1
  else
    OUTDIR=`readlink -f "$1"`
  fi
}

quitRmTemp() {
  if [ -d "$TEMPDIR" ]; then
    rm -r "$TEMPDIR";
  fi
  exit $1
}

# Execute main script
main
