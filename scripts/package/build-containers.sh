#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../../common/common.sh"
source_env

set -o pipefail
[ -n "$DEBUG" ] && set -x

echo "INFO: Build containers"
if [[ -z "${CONTAINER_BUILDER_DIR}" ]] ; then
  echo "ERROR: CONTAINER_BUILDER_DIR Must be set to build containers"
  exit 1
fi

res=0
${CONTAINER_BUILDER_DIR}/containers/build.sh || res=1

mkdir -p /output/logs/container-builder
# do not fail script if logs files are absent
mv ${CONTAINER_BUILDER_DIR}/containers/*.log /output/logs/container-builder/ || /bin/true

exit $res
