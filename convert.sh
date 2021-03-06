#!/bin/bash
#
# Script to convert aiff files downloaded from Beatport to lossless format (with covers).
# It uses ffmpeg (that not deals with covers during conversion), metaflac to
# apply covers to flac file and mp4art in case of alac files (m4a container).
#
# Script requirements:
# - ffmpeg
# - jq
# - metaflac (optionally)
# - mp4v2 (optionally)

# usage description
usage () {
  echo
  echo "Script to convert aiff files (downloaded from Beatport) to lossless format"
  echo "like flac or alac (m4a container). If no argument specified files will be "
  echo "converted to alac."
  echo
  echo "Usage:"
  echo "$(basename $0) -d /dir/with/aiffs [flac|alac|both]"
  echo

  exit 0
}

###
#
# Cover extractor
#
###

# Get cover art from music file and save it to image file
cover_extractor() {

  filename="$1"
  pic_name="$2"

  ffmpeg -i "$filename" -map 0:$( \
    ffprobe \
      -loglevel quiet \
      -print_format json \
      -hide_banner \
      -select_streams v \
      -show_streams "$filename" | jq '.streams[] | if .tags.comment == "Cover (front)" then .index else empty end') \
      "$pic_name"
}

###
#
# FLAC
#
###

flac_convert() {

  filename="$1"

  echo "Flac filename: $filename"
  # Files comes always with .aiff extension so we will remove last four letters
  # and replace them with "flac" (no dot)
  flac_filename="${filename%????}flac"

  # Convert file to .flac
  ffmpeg -i "$filename" "$flac_filename"

  # Find stream with cover art
  pic_name="cover.mjpeg"
  cover_extractor "$filename" "$pic_name"
  metaflac --import-picture-from="3||||$pic_name" "$flac_filename"
  rm "$pic_name"

  # Remove source file if dest file exists
  if [ -e "$flac_filename" ]; then
    rm "$filename"
  fi
}


###
#
# ALAC
#
###

alac_convert() {

  filename="$1"

  echo "Alac filename: $filename"
  # Files comes always with .aiff extension so we will remove last four letters
  # and replace them with "m4a" (no dot)
  alac_filename="${filename%????}m4a"

  # Convert file to alac (-vn stands for "no video". ffmpeg thinks that cover
  # art included into aiff file is a video so it creates mp4 video file. We'd like
  # to avoid it as it makes problems with cover art display in Mac Finder)
  ffmpeg -i "$filename" -acodec alac -vn "$alac_filename"

  # Cover (front)
  pic_name="cover.mjpeg"
  cover_extractor "$filename" "$pic_name"
  mp4art --add "$pic_name" "$alac_filename"
  rm "$pic_name"

  # Remove source file if dest file exists
  if [ -e "$alac_filename" ]; then
    rm "$filename"
  fi
}


###
#
# Main part of script
#
###
main() {

  CODEC="$1"

  if [ "" == "$CODEC" ]; then
    CODEC="alac"
  fi

  # Check requirements
  if [ $(ffmpeg -version &>/dev/null; echo $?) -ne 0 ]; then
    echo "Please install ffmpeg."
    exit 1
  fi

  # Check if jq is installed
  if [ $(jq --version) == "" ]; then
    echo "Please install jq."
    exit 1
  fi

  # Flac requirements
  if [ "$CODEC" == "flac" ] || [ "$CODEC" == "both" ]; then
    if [ $(metaflac --version) == "" ]; then
      echo "Please install metaflac"
      exit 1
    fi
  fi

  # Alac requirements
  if [ "$CODEC" == "alac" ] || [ "$CODEC" == "both" ]; then
    if [ $(mp4art --version) == "" ]; then
      echo "Please install mp4v2"
      exit 1
    fi
  fi

  # Each element in the loop is separated by newline rather than blank sign
  IFS=$'\n'

  for filename in $(find . -name "*.aiff"); do

    if [ "$CODEC" == "flac" ] || [ "$CODEC" == "both" ]; then
      # echo "flac"
      flac_convert "$filename"
    fi

    if [ "$CODEC" == "alac" ] || [ "$CODEC" == "both" ]; then
      # echo "alac"
      alac_convert "$filename"
    fi

  done

  # # Leaving for the future
  # DIRNAME=$(dirname "$0")
  # find . -name "*.aiff" -exec "$DIRNAME"/flac_convert.sh "{}" \;
}


# Arguments handle
while getopts "hd:" optname; do
  case "$optname" in
    "h")
      usage
    ;;
    "d")
      cd "${OPTARG}"
      main "${!OPTIND}"   # indirect expansion 
    ;;
    *)
      usage
    ;;
  esac
done
