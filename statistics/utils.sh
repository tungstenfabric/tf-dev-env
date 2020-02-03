#!/bin/bash

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



