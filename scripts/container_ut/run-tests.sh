#!/bin/bash -e

[ "${DEBUG,,}" == "true" ] && set -x
scriptdir=$(realpath $(dirname "$0"))

src_root=/root/contrail
logs_path="${src_root}/contrail/logs"
cd $src_root
mkdir -p "$logs_path"

/root/contrail/contrail-container-builder/run-tests.sh &> $logs_path/containers-unit-tests.log
