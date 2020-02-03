#!/bin/bash

list_images_path="./list_images"
if [ -e "$list_images_path" ] ; then
    while read image_name; do
         docker pull ${JUNIPER_REPO}/${image_name}:${JUNIPER_TAG} #donwload image for juniper
         id_juniper=$(docker images | grep "${JUNIPER_REPO}/${image_name}" | grep ${JUNIPER_TAG} | head -1 | awk '{print $3}') #get juniper id image
         id_src=$(docker images | grep "${TF_LOCAL_REPO}/${image_name}" | grep ${TF_LOCAL_TAG} | head -1 | awk '{print $3}') # get local repo image
         docker_build_smoke_test $id_src
         size_juniper=$( get_size $id_juniper )
         size_src=$( get_size $id_src )
         layers_juniper=$( get_layers_count $id_juniper )
         layers_src=$( get_layers_count $id_src )
         log "Statistics for image $image_name : local image is $size_src  size and has $layers_src layers, juniper image $size_juniper size and has $layers_juniper layers \n" "$image_name" "$size_src" "$layers_src" "$size_juniper" "$layers_juniper" >> $LOG_FILE
         echo "Statistics for image $image_name : local image is $size_src  size and has $layers_src layers, juniper image $size_juniper size and has $layers_juniper layers \n" "$image_name" "$size_src" "$layers_src" "$size_juniper" "$layers_juniper" >> $LOG_FILE
         size_juniper=""
         size_src=""
         layers_juniper=""          
	 layers_src=""
    done < "$list_images_path"
fi




