#!/bin/bash

#
# Common options parser.
#
# Copyright (c) 2018-2019, Taner Sener (https://github.com/tanersener)
#
# This work is licensed under the terms of the MIT license. For a copy, see <https://opensource.org/licenses/MIT>.
#
WIDTH=1280
HEIGHT=720
FPS=30
TRANSITION_DURATION=1
TOTAL_DURATION=10
SCREEN_MODE=2               # 1=CENTER, 2=CROP, 3=SCALE, 4=BLUR
ZOOM_SPEED=2                # 1=SLOWEST, 2=SLOW, 3=MODERATE, 4=FASTER, 5=FASTEST, ...
INPUT_MEDIA_FOLDER="./media/"
OUTPUT="./output.mp4"


usage() {                                 # Function: Print a help message.
  echo "Usage: $0 [ -w width ] [ -height ] [ -t transition period ]
              [ -d image duration ] [ -i image input folder ] [ -o output file ]
              [ -s screen mode (1=CENTER, 2=CROP, 3=SCALE, 4=BLUR) ]  " 1>&2
}
exit_abnormal() {                         # Function: Exit with error.
  usage
  exit 1
}

while getopts ":w:h:t:d:i:o:s:" options; do
  case "${options}" in
    w)
      WIDTH=${OPTARG}
      ;;
    h)
      HEIGHT=${OPTARG}
      ;;
    t)
      TRANSITION_DURATION=${OPTARG}
      ;;
    d)
      TOTAL_DURATION=${OPTARG}
      ;;
    i)
      INPUT_MEDIA_FOLDER=${OPTARG}
      ;;
    o)
      OUTPUT=${OPTARG}
      ;;
    s)
      SCREEN_MODE=${OPTARG}
      ;;
    :)                                    # If expected argument omitted:
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal
      ;;
    *)                                    # If unknown (any other) option:
      exit_abnormal
      ;;
  esac
done