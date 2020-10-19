#!/bin/bash

workdir=$1
prefix=$2
container=$3

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../../common/common.sh"
source_env

res=0
${workdir}/containers/build.sh $container || res=1

mkdir -p "${CONTRAIL_OUTPUT_DIR:-/output}/logs/${prefix}s"
# do not fail script if logs files are absent
mv ${workdir}/containers/*.log "${CONTRAIL_OUTPUT_DIR:-/output}/logs/${prefix}s/" || /bin/true

exit $res
