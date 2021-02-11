#!/bin/bash

set -o pipefail

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

function run_cmd(){
  local me=$(whoami)
  if [[ "root" == "$me" ]] || ! grep -q "^docker:" /etc/group || groups | grep -q 'docker' ; then
    $@
    return
  fi
  if ! grep -q "^docker:.*:$me" /etc/group ; then
    sudo usermod -aG docker $me
  fi
  echo $@ | sg docker -c bash
}

function build_operator() {
  cd ${REPODIR}/tf-operator

  type go >/dev/null 2>&1 || {
    export PATH=$PATH:/usr/local/go/bin
  }
  export CGO_ENABLED=1

  local target=${CONTAINER_REGISTRY}/tf-operator:${CONTRAIL_CONTAINER_TAG}
  run_cmd operator-sdk build $target
  run_cmd docker push $target
}

res=0

operator_logfile="${WORKSPACE}/tf_operator_build_containers.log"
build_operator | append_log $operator_logfile true || res=1

mkdir -p /output/logs/tf-operator
# do not fail script if logs file is absent
mv $operator_logfile /output/logs/tf-operator || /bin/true

exit $res
