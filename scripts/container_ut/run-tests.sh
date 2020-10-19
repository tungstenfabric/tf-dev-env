#!/bin/bash -e
set -o pipefail

[ "${DEBUG,,}" == "true" ] && set -x
scriptdir=$(realpath $(dirname "$0"))

src_root="${ROOT_CONTRAIL:-$HOME/contrail}"
logs_path="${CONTRAIL_OUTPUT_DIR:-/output}/logs"
cd $src_root
mkdir -p "$logs_path"
repo_dir="${ROOT_CONTRAIL:-$HOME/contrail}/contrail-container-builder"

res=0
targets=$($repo_dir/run-tests.sh list | grep -P '^containers')
for target in $targets ; do
    logfile=$(echo $target | tr '/' '-' ).log
    if ! $repo_dir/run-tests.sh $target &> $logs_path/$logfile ; then
       echo "ERROR: $(date) $target container test failed. Unit test log is available at $logs_path/$logfile"
       res=1
    fi
done
exit $res
