#!/bin/bash
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