#!/bin/bash
source ./const.sh
source ./utils.sh
list_images_path="./list_images"
stats_log="stats_$(date +%m-%d-%Y-%H-%M-%S)"
touch $stats_log
if [ -e "$list_images_path" ] ; then
    printf "IMAGE # LOCAL_IMAGE_SIZE # JUNIPER_IMAGE_SIZE #" | tee -a $stats_log
    while read image_name; do
         docker pull ${JUNIPER_REPO}/${image_name}:${JUNIPER_TAG} #donwload image for juniper
         id_juniper=$(docker images | grep "${JUNIPER_REPO}/${image_name}" | grep ${JUNIPER_TAG} | head -1 | awk '{print $3}') #get juniper id image
         id_src=$(docker images | grep "${TF_LOCAL_REPO}/${image_name}" | grep ${TF_LOCAL_TAG} | head -1 | awk '{print $3}') # get local repo image
         size_juniper=$( get_size $id_juniper )
         size_src=$( get_size $id_src )
         echo "$image_name       #     $size_src    #    $size_juniper    #"  | tee -a $stats_log
         layers_juniper=$( get_layers_count $id_juniper )
         layers_src=$( get_layers_count $id_src )         
         echo "Statistics for image $image_name : local image is $size_src  size and has $layers_src layers, juniper image $size_juniper size and has $layers_juniper layers \n" "$image_name" "$size_src" "$layers_src" "$size_juniper" "$layers_juniper" | tee -a $LOG_FILE         
    done < "$list_images_path"
fi
