#!/bin/bash
#
# ffmpeg video slideshow script with zoom in and pan and fade in/out #2 transition v4 (25.05.2019)
#
# Copyright (c) 2019, Taner Sener (https://github.com/tanersener)
#
# This work is licensed under the terms of the MIT license. For a copy, see <https://opensource.org/licenses/MIT>.
#

# SCRIPT OPTIONS - CAN BE MODIFIED
WIDTH=1280
HEIGHT=720
FPS=30
TRANSITION_DURATION=2
IMAGE_DURATION=1
SCREEN_MODE=2               # 1=CENTER, 2=CROP, 3=SCALE, 4=BLUR
BACKGROUND_COLOR="black"
INPUT_MEDIA_FOLDER="./media/"
OUTPUT="./advanced_zoom_in_and_pan_with_fade_in_out_two.mp4"

IFS=$'\t\n'                 # REQUIRED TO SUPPORT SPACES IN FILE NAMES


CUR_DIR="$(dirname "$0")"
source "${CUR_DIR}/../options/options_parser.sh"

# FILE OPTIONS
# FILES=`find ../media/*.jpg | sort -r`             # USE ALL IMAGES UNDER THE media FOLDER SORTED
# FILES=('../media/1.jpg' '../media/2.jpg')         # USE ONLY THESE IMAGE FILES
# shellcheck disable=SC2006
FILES=`find $INPUT_MEDIA_FOLDER/*`                         # USE ALL IMAGES UNDER THE media FOLDER

############################
# DO NO MODIFY LINES BELOW
############################

# CALCULATE LENGTH MANUALLY
let IMAGE_COUNT=0
for IMAGE in ${FILES[@]}; do (( IMAGE_COUNT+=1 )); done

if [[ ${IMAGE_COUNT} -lt 2 ]]; then
    echo "Error: media folder should contain at least two images"
    exit 1;
fi

# INTERNAL VARIABLES
TRANSITION_FRAME_COUNT=$(( TRANSITION_DURATION*FPS ))
IMAGE_DURATION=$( echo "1.0*$TOTAL_DURATION/$IMAGE_COUNT-2*$TRANSITION_DURATION" | bc -l )
IMAGE_FRAME_COUNT=$(echo "$IMAGE_DURATION*$FPS" | bc )

echo -e "\nVideo Slideshow Info\n------------------------\nImage count: ${IMAGE_COUNT}\nDimension: ${WIDTH}x${HEIGHT}\nFPS: ${FPS}\nImage duration: ${IMAGE_DURATION} s\n\
Transition duration: ${TRANSITION_DURATION} s\nTotal duration: ${TOTAL_DURATION} s\n"

START_TIME=$SECONDS

# 1. START COMMAND
FULL_SCRIPT="ffmpeg -y "

# 2. ADD INPUTS
for IMAGE in ${FILES[@]}; do
    FULL_SCRIPT+="-loop 1 -i '${IMAGE}' "
done

# 3. START FILTER COMPLEX
FULL_SCRIPT+="-filter_complex \""

# 4. PREPARE INPUTS & FADE IN/OUT PARTS & ZOOM & PAN EACH STREAM
for (( c=0; c<${IMAGE_COUNT}; c++ ))
do
    POSITION_NUMBER=$((RANDOM % 5));

    case ${POSITION_NUMBER} in
        0)
            POSITION_FORMULA="x='iw/2':y='-${HEIGHT}-(ih/zoom/2)'"                      # TOP RIGHT
        ;;
        1)
            POSITION_FORMULA="x='iw/2':y='(ih/zoom/2)'"                                 # BOTTOM RIGHT
        ;;
        2)
            POSITION_FORMULA="x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'"                # CENTER
        ;;
        3)
            POSITION_FORMULA="x='${WIDTH}-(iw/zoom/2)':y='-${HEIGHT}-(ih/zoom/2)'"      # TOP LEFT
        ;;
        4)
            POSITION_FORMULA="x='${WIDTH}-(iw/zoom/2)':y='${HEIGHT}+(ih/zoom/2)'"       # BOTTOM LEFT
        ;;
    esac

    case ${SCREEN_MODE} in
        1)
            FULL_SCRIPT+="[${c}:v]setpts=PTS-STARTPTS,scale=w='if(gte(iw/ih,${WIDTH}/${HEIGHT}),min(iw,${WIDTH}),-1)':h='if(gte(iw/ih,${WIDTH}/${HEIGHT}),-1,min(ih,${HEIGHT}))',scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=sar=1/1,fps=${FPS},format=rgba,pad=width=${WIDTH}:height=${HEIGHT}:x=(${WIDTH}-iw)/2:y=(${HEIGHT}-ih)/2:color=${BACKGROUND_COLOR}"
        ;;
        2)
            FULL_SCRIPT+="[${c}:v]setpts=PTS-STARTPTS,scale=w='if(gte(iw/ih,${WIDTH}/${HEIGHT}),-1,${WIDTH})':h='if(gte(iw/ih,${WIDTH}/${HEIGHT}),${HEIGHT},-1)',crop=${WIDTH}:${HEIGHT},setsar=sar=1/1,fps=${FPS},format=rgba"
        ;;
        3)
            FULL_SCRIPT+="[${c}:v]setpts=PTS-STARTPTS,scale=${WIDTH}:${HEIGHT},setsar=sar=1/1,fps=${FPS},format=rgba"
        ;;
        4)
            FULL_SCRIPT+="[${c}:v]scale=${WIDTH}x${HEIGHT},setsar=sar=1/1,fps=${FPS},format=rgba,boxblur=100,setsar=sar=1/1[stream${c}blurred];"
            FULL_SCRIPT+="[${c}:v]scale=w='if(gte(iw/ih,${WIDTH}/${HEIGHT}),min(iw,${WIDTH}),-1)':h='if(gte(iw/ih,${WIDTH}/${HEIGHT}),-1,min(ih,${HEIGHT}))',scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=sar=1/1,fps=${FPS},format=rgba[stream${c}raw];"
            FULL_SCRIPT+="[stream${c}blurred][stream${c}raw]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2:format=rgb,setpts=PTS-STARTPTS"
        ;;
    esac

    FULL_SCRIPT+=",trim=start_frame=0:end_frame=${TRANSITION_FRAME_COUNT},setpts=PTS-STARTPTS,scale=${WIDTH}*5:-1,zoompan=z='pzoom+0.004':d=1:${POSITION_FORMULA}:fps=${FPS}:s=${WIDTH}x${HEIGHT},split=2[stream$((c+1))out1][stream$((c+1))out2];"

    FULL_SCRIPT+="[stream$((c+1))out1]trim=duration=${TRANSITION_DURATION},select=lte(n\,${TRANSITION_FRAME_COUNT}),fade=t=in:s=0:d=${TRANSITION_DURATION}[stream$((c+1))fadeinandzoom];"
    FULL_SCRIPT+="[stream$((c+1))out2]trim=start_frame=${TRANSITION_FRAME_COUNT}-1:end_frame=${TRANSITION_FRAME_COUNT},setpts=PTS-STARTPTS,split=2[stream$((c+1))pre][stream$((c+1))preout];"

    FULL_SCRIPT+="[stream$((c+1))pre]loop=loop=${IMAGE_FRAME_COUNT}:size=1:start=0,trim=duration=${IMAGE_DURATION},setpts=PTS-STARTPTS[stream$((c+1))];"
    FULL_SCRIPT+="[stream$((c+1))preout]loop=loop=${TRANSITION_FRAME_COUNT}:size=1:start=0,trim=duration=${TRANSITION_DURATION},setpts=PTS-STARTPTS,fade=t=out:s=0:d=${TRANSITION_DURATION}[stream$((c+1))fadeout];"

    FULL_SCRIPT+="[stream$((c+1))fadeinandzoom][stream$((c+1))][stream$((c+1))fadeout]concat=n=3:v=1:a=0[stream$((c+1))panning];"
done

# 5. BEGIN CONCAT
for (( c=1; c<=${IMAGE_COUNT}; c++ ))
do
    FULL_SCRIPT+="[stream${c}panning]"
done

# 6. END CONCAT
FULL_SCRIPT+="concat=n=${IMAGE_COUNT}:v=1:a=0,format=yuv420p[video]\""

# 7. END
FULL_SCRIPT+=" -map [video] -vsync 2 -async 1 -rc-lookahead 0 -g 0 -profile:v main -level 42 -c:v libx264 -r ${FPS} $OUTPUT"

eval ${FULL_SCRIPT}

ELAPSED_TIME=$(($SECONDS - $START_TIME))

echo -e '\nSlideshow created in '$ELAPSED_TIME' seconds\n'

unset $IFS