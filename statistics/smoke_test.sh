#!/bin/bash
function docker_build_smoke_test() {
    local image=$1
    local log_file=$2
    printf "####################"
    printf "Starting the smoke test for $image "

     #run_ct_and_get_entrypoint
    local ct_name=$(docker run -d $image)
    local exit_code="$?"
    printf "The exit code of ct_run is %s" "$exit_code"
    if [[ "${exit_code}" -eq 0 ]] ; then    
        entrypoint_exit_code=$(docker inspect -f "{{json .State.ExitCode }}" "${ct_name}")
        if [[ "${entrypoint_exit_code}" -eq 0 ]] ; then
	    echo "Test is OK for image ${image}" >> $log_file
        fi
    else
      echo  "Test is FAILED for image ${image}" | append_log_file $LOG_FILE
    fi
    ct_rm $ct_name
}
