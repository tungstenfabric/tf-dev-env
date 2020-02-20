#!/bin/bash
source ./const.sh
source ./utils.sh
function collect_fs_stats() {
local image_name=$1
#local id_juniper=$(docker images | grep "${JUNIPER_REPO}/${image_name}" | grep ${JUNIPER_TAG} | head -1 | awk '{print $3}') #get juniper id image

#local id_src=$(docker images | grep "${TF_LOCAL_REPO}/${image_name}" | grep ${TF_LOCAL_TAG} | head -1 | awk '{print $3}') # get local repo image
local id_juniper=$( get_image_id $image_name $JUNIPER_REPO $JUNIPER_TAG )
local id_src=$( get_image_id $image_name $TF_LOCAL_REPO $TF_LOCAL_TAG )


compare_fs $id_src $id_juniper
}
image=$1
collect_fs_stats $image

