#!/bin/bash
source ./const.sh
source ./utils.sh
source ./compare_rpm.sh
source ./compare_pip.sh
list_images_path="./list_images"
base_dir="./logs"
[ ! -d "$base_dir" ] && mkdir -p "$base_dir"
specific_image=$1
stats_log="${base_dir}/stats_$(date +%m-%d-%Y-%H-%M-%S)"
stats_log_layers="${stats_log}layers"
stats_rpms_layers="${stats_log}rpms"
stats_pips="${stats_log}pips"
fs_log="${stats_log}fs"
status="OK"
function collector() { 
	local image_name=$1
	docker pull ${JUNIPER_REPO}/${image_name}:${JUNIPER_TAG} #donwload image for juniper
         local id_juniper=$(docker images | grep "${JUNIPER_REPO}/${image_name}" | grep ${JUNIPER_TAG} | head -1 | awk '{print $3}') #get juniper id image

         local id_src=$(docker images | grep "${TF_LOCAL_REPO}/${image_name}" | grep ${TF_LOCAL_TAG} | head -1 | awk '{print $3}') # get local repo image
         local size_juniper=$( get_size $id_juniper )
         local size_src=$( get_size $id_src )
         echo "size_juniper is $size_juniper "
         if (( size_src > size_juniper )); then
            status="NOT OK!"
         else
            status="OK"
         fi
         echo "#     $image_name       #     $size_src     #    $size_juniper    #    $status      #"  | tee -a $stats_log
         local layers_size_juniper=$( get_layers_size $id_juniper )
         local layers_size_src=$( get_layers_size $id_src )
         local rpms_compare=$( compare_images_rpms $id_src $id_juniper )
	 local pips_compare_2=$( compare_images_pip $id_src $id_juniper python2 )
	 local pips_compare_3=$( compare_images_pip $id_src $id_juniper python3 )
         printf "############\n #### %s  local layers is \n %s  \n ##############\n" "$image_name" "$layers_size_src"| tee -a $stats_log_layers
         printf "############\n #### %s  remote layers is \n %s  \n ##############\n" "$image_name" "$layers_size_juniper"| tee -a $stats_log_layers
         printf "############\n compare rpms for %s \n %s \n ############# \n" "$image_name" "$rpms_compare" | tee -a $stats_rpms_layers
	 printf "############\n compare pips for %s \n %s \n ############# \n" "$image_name" "$pips_compare_2" | tee -a $stats_pips
	 printf "############\n compare rpms for %s \n %s \n ############# \n" "$image_name" "$pips_compare_3" | tee -a $stats_pips
	 local fs_cmpr=$(compare_fs $id_src $id_juniper )
	 echo $fs_cmpr | tee -a $fs_log
         local layers_juniper=$( get_layers_count $id_juniper )
         local layers_src=$( get_layers_count $id_src )
         echo "Statistics for image $image_name : local image is $size_src  size and has $layers_src layers, juniper image $size_juniper size and has $layers_juniper layers \n" "$image_name" "$size_src" "$layers_src" "$size_juniper" "$layers_juniper" | tee -a $LOG_FILE


}

if [ -z "$specific_image" ] ; then
if [ -e "$list_images_path" ] ; then
    echo "IMAGE_NAME                           # CONTRAIL_REMOTE_IMAGE_SIZE (MB) # LOCAL_IMAGE_SIZE (MB)     #     STATUS (LOCAL LESS THEN REMOTE)      ##" | tee -a $stats_log
    while read image_name; do
	collector $image_name
    done < "$list_images_path"
fi
else
	echo "IMAGE_NAME                           # CONTRAIL_REMOTE_IMAGE_SIZE (MB) # LOCAL_IMAGE_SIZE (MB)     #     STATUS (LOCAL LESS THEN REMOTE)      ##" | tee -a $stats_log
	collector $specific_image
fi


