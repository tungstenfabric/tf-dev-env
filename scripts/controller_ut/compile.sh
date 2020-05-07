#!/bin/bash -e

JOBS=${JOBS:-$(nproc)}

scriptdir=$(realpath $(dirname "$0"))
source $scriptdir/definitions.sh

cd $HOME/contrail
logs_path="/output/logs"
mkdir -p "$logs_path"

echo "INFO: Run full build $(date)"
# BUILD_ONLY=1 scons -j $JOBS --without-dpdk --kernel-dir=/lib/modules/${KVERS}/build &> $logs_path/build_full.$(date "+%F_%T")
echo "INFO: full build is done $(date)"
