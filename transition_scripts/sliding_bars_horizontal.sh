#!/bin/bash
#
# ffmpeg video slideshow script with horizontal sliding bars transition v5 (25.05.2019)
#
# Copyright (c) 2017-2019, Taner Sener (https://github.com/tanersener)
#
# This work is licensed under the terms of the MIT license. For a copy, see <https://opensource.org/licenses/MIT>.
#

# SCRIPT OPTIONS - CAN BE MODIFIED
WIDTH=1280
HEIGHT=720
FPS=30
TRANSITION_DURATION=1
TOTAL_DURATION=10
SCREEN_MODE=2               # 1=CENTER, 2=CROP, 3=SCALE, 4=BLUR
BAR_COUNT=8                 # HEIGHT SHOULD BE DIVISIBLE BY BAR_COUNT. IF NOT HORIZONTAL LINES WILL APPEAR ON TRANSITION
BACKGROUND_COLOR="black"
DIRECTION=1                 # 1=LEFT TO RIGHT, 2=RIGHT TO LEFT
INPUT_MEDIA_FOLDER="./media/"
OUTPUT="./output.mp4"

CUR_DIR="$(dirname "$0")"
source "${CUR_DIR}/../options/options_parser.sh"

IFS=$'\t\n'                 # REQUIRED TO SUPPORT SPACES IN FILE NAMES

# FILE OPTIONS
# FILES=`find ../media/*.jpg | sort -r`             # USE ALL IMAGES UNDER THE media FOLDER SORTED
# FILES=('../media/1.jpg' '../media/2.jpg')         # USE ONLY THESE IMAGE FILES
FILES=`find $INPUT_MEDIA_FOLDER/*`                  # USE ALL IMAGES UNDER THE media FOLDER

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
IMAGE_DURATION=$( echo "1.0*($TOTAL_DURATION+$TRANSITION_DURATION)/$IMAGE_COUNT-$TRANSITION_DURATION" | bc -l )
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

# 4. PREPARE INPUTS
for (( c=0; c<${IMAGE_COUNT}; c++ ))
do
    case ${SCREEN_MODE} in
        1)
            FULL_SCRIPT+="[${c}:v]setpts=PTS-STARTPTS,scale=w='if(gte(iw/ih,${WIDTH}/${HEIGHT}),min(iw,${WIDTH}),-1)':h='if(gte(iw/ih,${WIDTH}/${HEIGHT}),-1,min(ih,${HEIGHT}))',scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=sar=1/1,fps=${FPS},format=rgba,split=2[stream$((c+1))out1][stream$((c+1))out2];"
        ;;
        2)
            FULL_SCRIPT+="[${c}:v]setpts=PTS-STARTPTS,scale=w='if(gte(iw/ih,${WIDTH}/${HEIGHT}),-1,${WIDTH})':h='if(gte(iw/ih,${WIDTH}/${HEIGHT}),${HEIGHT},-1)',crop=${WIDTH}:${HEIGHT},setsar=sar=1/1,fps=${FPS},format=rgba,split=2[stream$((c+1))out1][stream$((c+1))out2];"
        ;;
        3)
            FULL_SCRIPT+="[${c}:v]setpts=PTS-STARTPTS,scale=${WIDTH}:${HEIGHT},setsar=sar=1/1,fps=${FPS},format=rgba,split=2[stream$((c+1))out1][stream$((c+1))out2];"
        ;;
        4)
            FULL_SCRIPT+="[${c}:v]scale=${WIDTH}x${HEIGHT},setsar=sar=1/1,fps=${FPS},format=rgba,boxblur=100,setsar=sar=1/1[stream${c}blurred];"
            FULL_SCRIPT+="[${c}:v]scale=w='if(gte(iw/ih,${WIDTH}/${HEIGHT}),min(iw,${WIDTH}),-1)':h='if(gte(iw/ih,${WIDTH}/${HEIGHT}),-1,min(ih,${HEIGHT}))',scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=sar=1/1,fps=${FPS},format=rgba[stream${c}raw];"
            FULL_SCRIPT+="[stream${c}blurred][stream${c}raw]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2:format=rgb,setpts=PTS-STARTPTS,split=2[stream$((c+1))out1][stream$((c+1))out2];"
        ;;
    esac
done

# 5. APPLY PADDING
for (( c=1; c<=${IMAGE_COUNT}; c++ ))
do
    FULL_SCRIPT+="[stream${c}out1]pad=width=${WIDTH}:height=${HEIGHT}:x=(${WIDTH}-iw)/2:y=(${HEIGHT}-ih)/2:color=${BACKGROUND_COLOR},trim=duration=${IMAGE_DURATION},select=lte(n\,${IMAGE_FRAME_COUNT})[stream${c}overlaid];"
    if [[ ${c} -eq 1 ]]; then
        if  [[ ${IMAGE_COUNT} -gt 1 ]]; then
            FULL_SCRIPT+="[stream${c}out2]pad=width=${WIDTH}:height=${HEIGHT}:x=(${WIDTH}-iw)/2:y=(${HEIGHT}-ih)/2:color=${BACKGROUND_COLOR},trim=duration=${TRANSITION_DURATION},select=lte(n\,${TRANSITION_FRAME_COUNT})[stream${c}ending];"
        fi
    elif [[ ${c} -lt ${IMAGE_COUNT} ]]; then
        FULL_SCRIPT+="[stream${c}out2]pad=width=${WIDTH}:height=${HEIGHT}:x=(${WIDTH}-iw)/2:y=(${HEIGHT}-ih)/2:color=${BACKGROUND_COLOR},trim=duration=${TRANSITION_DURATION},select=lte(n\,${TRANSITION_FRAME_COUNT}),split=2[stream${c}starting][stream${c}ending];"
    elif [[ ${c} -eq ${IMAGE_COUNT} ]]; then
        FULL_SCRIPT+="[stream${c}out2]pad=width=${WIDTH}:height=${HEIGHT}:x=(${WIDTH}-iw)/2:y=(${HEIGHT}-ih)/2:color=${BACKGROUND_COLOR},trim=duration=${TRANSITION_DURATION},select=lte(n\,${TRANSITION_FRAME_COUNT})[stream${c}starting];"
    fi
done

# 6. PREPARE BARS
for (( c=2; c<=${IMAGE_COUNT}; c++ ))
do
    FULL_SCRIPT+="[stream${c}starting]split=${BAR_COUNT}"

    for (( d=1; d<=${BAR_COUNT}; d++ ))
    do
        FULL_SCRIPT+="[stream${c}starting${d}]"
    done

    FULL_SCRIPT+=";"

    for (( d=1; d<=${BAR_COUNT}; d++ ))
    do
        FULL_SCRIPT+="[stream${c}starting${d}]crop=out_w=iw:out_h=ih/${BAR_COUNT}:x=0:y=ih/${BAR_COUNT}*$(( d-1 )),pad=w=${WIDTH}:h=${HEIGHT}:x=0:y=0:color=#00000000[stream${c}starting${d}cropped];"
    done

    for (( d=1; d<=${BAR_COUNT}; d++ ))
    do

        if [[ ${d} -eq 1 ]]; then
            FULL_SCRIPT+="[stream$((c-1))ending]"
        else
            FULL_SCRIPT+="[stream${c}starting$((d-1))added]"
        fi

        case ${DIRECTION} in
            1)
                FULL_SCRIPT+="[stream${c}starting${d}cropped]overlay=x='if(between(t,(${TRANSITION_DURATION}/${BAR_COUNT})*$((d-1)),(${TRANSITION_DURATION}/${BAR_COUNT})*${d}),-w+${WIDTH}*(t-(${TRANSITION_DURATION}/${BAR_COUNT})*$((d-1)))/(${TRANSITION_DURATION}/${BAR_COUNT}),if(gte(t,(${TRANSITION_DURATION}/${BAR_COUNT})*${d}),0,-w))':y=h/${BAR_COUNT}*$((d-1)),select=lte(n\,${TRANSITION_FRAME_COUNT})"
            ;;
            *)
                FULL_SCRIPT+="[stream${c}starting${d}cropped]overlay=x='if(between(t,(${TRANSITION_DURATION}/${BAR_COUNT})*$((d-1)),(${TRANSITION_DURATION}/${BAR_COUNT})*${d}),w-${WIDTH}*(t-(${TRANSITION_DURATION}/${BAR_COUNT})*$((d-1)))/(${TRANSITION_DURATION}/${BAR_COUNT}),if(gte(t,(${TRANSITION_DURATION}/${BAR_COUNT})*${d}),0,w))':y=h/${BAR_COUNT}*$((d-1)),select=lte(n\,${TRANSITION_FRAME_COUNT})"
            ;;
        esac

        if [[ ${d} -eq ${BAR_COUNT} ]]; then
            FULL_SCRIPT+="[stream${c}blended];"
        else
            FULL_SCRIPT+="[stream${c}starting${d}added];"
        fi
    done

done

# 7. BEGIN CONCAT
for (( c=1; c<${IMAGE_COUNT}; c++ ))
do
    FULL_SCRIPT+="[stream${c}overlaid][stream$((c+1))blended]"
done

# 8. END CONCAT
FULL_SCRIPT+="[stream${IMAGE_COUNT}overlaid]concat=n=$((2*IMAGE_COUNT-1)):v=1:a=0,format=yuv420p[video]\""

# 9. END
FULL_SCRIPT+=" -map [video] -vsync 2 -async 1 -rc-lookahead 0 -g 0 -profile:v main -level 42 -c:v libx264 -r ${FPS} $OUTPUT"

eval ${FULL_SCRIPT}

ELAPSED_TIME=$(($SECONDS - $START_TIME))

echo -e '\nSlideshow created in '$ELAPSED_TIME' seconds\n'

unset $IFS