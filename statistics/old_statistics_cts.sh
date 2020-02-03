#!/bin/bash
#TODO:
#What to collect size, rpms, pip2,pip3 count, size of the most biggest layers, count of layers
#1. Create list of containers to compare
#2. Note that you need to define the repository
JUNIPER_REPO=${JUNIPER_REPO:-"opencontrailnightly"}
JUNIPER_TAG=${JUNIPER_TAG:-"2003-latest"}
TF_LOCAL_REPO=${TF_LOCAL_REPO:-"localhost:5000"}
TF_LOCAL_TAG=${TF_LOCAL_TAG:-"dev"}
#3. Get the table with size and image name
#image_name from_source_size rpm_size

function log() {
  echo -e "$(date -u +"%Y-%m-%d %H:%M:%S,%3N"): INFO: $@"
}

function err() {
  echo -e "$(date -u +"%Y-%m-%d %H:%M:%S,%3N"): ERROR: $@" >&2
}
function append_log_file() {
  local logfile=$1
  local always_echo=${2:-'false'}
  local line=''
  while read line ; do
      echo "$line" >>  $logfile
  done
}

function ct_rm() {
	local ct=$1
	[ "$(docker ps -a | grep $ct )" ] && docker rm -f "${ct}"
}

LOG_FILE="logrun_$(date +%m-%d-%Y-%H-%M-%S)"
[ ! -d  "./logs" ] && mkdir -p ./logs
[ ! -f  "./logs/$LOG_FILE" ] && mkdir -p ./logs && touch "./logs/$LOG_FILE"
function docker_build_smoke_test() {
    local image=$1
    printf "####################"
    printf "Starting the smoke test for $image "

     #run_ct_and_get_entrypoint
    local ct_name=$(docker run -d -e OPENSTACK_VERSION="queens"  $image)
    local exit_code="$?"
    printf "The exit code of ct_run is %s" "$exit_code"
    if [[ "${exit_code}" -eq 0 ]] ; then    
        entrypoint_exit_code=$(docker inspect -f "{{json .State.ExitCode }}" "${ct_name}")
        ct_name=$(docker inspect -f '{{ json .ContainerConfig.Labels.name }}' 8875100856bf); echo "${ct_name}"; if [[ "$ct_name" == "heat" ]] ; then echo "OK"; fi
        if [[ "${entrypoint_exit_code}" -eq 0 ]] ; then
            log "Test is OK for image ${image}" | append_log_file $LOG_FILE
	    log "Test is OK for image ${image}" >> $LOG_FILE
	    echo "Test is OK for image ${image}" >> $LOG_FILE	
            

        fi
    else
      err  "Test is FAILED for image ${image}" | append_log_file $LOG_FILE
      echo "Test is OK for image ${image}" >> $LOG_FILE
    fi
    ct_rm $ct_name
}

function get_size() {
    local image_id=$1
    if [[ -n "$image_id" ]] ; then
        local size=$(docker inspect -f "{{ json .Size }}" $image_id)
        size=$(( size / 1000000 ))
        echo "$size MB"
    fi
}

function get_layers_count () {
    local image_id=$1
    if [[ -n "$image_id" ]] ; then
        local layers=$( docker history $image_id | wc -l )        
        echo $layers
    fi
}

function get_layers_size() {
    local image_id=$1
    if [[ -n "$image_id" ]] ; then
        local layers=$( docker history $image_id | grep MB )
        
        echo "$layers MB"
    fi
}

list_images_path="./.list_images"
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




