#!/bin/bash -x

workdir=$1
prefix=$2
container=$3

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../../common/common.sh"
source_env

res=0
${workdir}/containers/build.sh $container || res=1

mkdir -p /output/logs/${prefix}s
# do not fail script if logs files are absent
# may be 2
echo "may be 2"
mv ${workdir}/containers/*.log /output/logs/${prefix}s/ || /bin/true

exit $res
