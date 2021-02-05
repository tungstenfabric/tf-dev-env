#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../../common/common.sh"
source_env

REPODIR=${REPODIR:-"."}

if [[ -z "${CONTRAIL_REGISTRY}" ]]; then
  echo "CONTRAIL_REGISTRY is not set"
  exit 1
fi

export CONTRAIL_REGISTRY

if [[ -z "${CONTRAIL_REPOSITORY}" ]]; then
  echo "CONTRAIL_REPOSITORY is not set"
  exit 1
fi

export CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-"dev"}
CONTRAIL_KEEP_LOG_FILES=${CONTRAIL_KEEP_LOG_FILES:-'false'}

function append_log() {
  local logfile=$1
  local always_echo=${2:-'false'}
  while read line ; do
    if [[ "${CONTRAIL_KEEP_LOG_FILES,,}" != 'true' || "$always_echo" != 'false' ]] ; then
      echo "$line" | tee -a $logfile
    else
      echo "$line" >> $logfile
    fi
  done
}

res=0

operator_logfile="${WORKSPACE}/tf_operator_build_containers.log"
${REPODIR}/tf-operator/scripts/build.sh | append_log $operator_logfile true || res=1

mkdir -p /output/logs/tf-operator
# do not fail script if logs file is absent
mv $operator_logfile /output/logs/tf-operator || /bin/true

exit $res

