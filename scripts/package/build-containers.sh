#!/bin/bash

workdir=$1
prefix=$2

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../../common/common.sh"
source_env

echo "INFO: Build containers"
if [[ -z "${workdir}" ]] ; then
  echo "ERROR: \$1 Must be set to build containers folder"
  exit 1
fi

res=0
${workdir}/containers/build.sh || res=1

mkdir -p /output/logs/${prefix}s
# do not fail script if logs files are absent
mv ${workdir}/containers/*.log /output/logs/${prefix}s/ || /bin/true

exit $res
