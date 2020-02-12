#!/bin/bash

my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"

source ${my_dir}/../common/common.sh
source ${my_dir}/../common/functions.sh

echo "INFO: Build sources containers"
if [[ -z "${REPODIR}" ]] ; then
  echo "ERROR: REPODIR Must be set for build src containers"
  exit 1
fi

buildsh=${REPODIR}/contrail-container-builder/containers/build.sh
if ! [[ -x "${buildsh}" ]] ; then
  echo "ERROR: build.sh tool from contrail-container-builder is not available in ${REPODIR} or is not executable"
  exit 1
fi

publish_list_file=${PUBLISH_LIST_FILE:-"${my_dir}/../src_containers_to_publish"}
if ! [[ -f "${publish_list_file}" ]] ; then
  echo "ERROR: targets for build as src containers must be listed at ${publish_list_file}"
  exit 1
fi

dockerfile_template=${DOCKERFILE_TEMPLATE:-"${my_dir}/Dockerfile.src.tmpl"}
if ! [[ -f "${dockerfile_template}" ]] ; then
  echo "ERROR: Dockerfile template ${dockerfile_template} is not available."
  exit 1
fi

VENDOR_NAME=${VENDOR_NAME:-tungstenfabric}
CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-latest}

build_log_file=${TF_CONFIG_DIR}/src_containers_build.log
mkdir -p ${TF_CONFIG_DIR}
echo "===== Start Build Containers at $(date) =====" > ${build_log_file}

function run_src_container_build() {
  local res=0
  ${buildsh} ${REPODIR}/$1 || res=1
  if [[ $res == 1 ]] ; then
    echo "ERROR: Container ${CONTRAIL_CONTAINER_NAME} building failed" >> ${build_log_file}
  else
    echo "INFO: Container ${CONTRAIL_CONTAINER_NAME} has been successfully built" >> ${build_log_file}
  fi
}

while IFS= read -r line; do
if ! [[ "$line" =~ ^\#.*$ ]] ; then
  if ! [[ "$line" =~ ^[\-0-9a-zA-Z\/_.]+$ ]] ; then
    echo "ERROR: Directory name ${line} must contain only latin letters, digits or '.', '-', '_' symbols  "
    exit 1
  fi

  if ! [[ -d "${REPODIR}/${line}" ]] ; then
    echo "ERROR: not found directory ${REPODIR}/${line} mentioned in ${publish_list_file}"
    exit 1
  fi

  export CONTRAIL_CONTAINER_NAME=contrail-${line}-src
  echo "INFO: Pack $line sources to container ${CONTRAIL_CONTAINER_NAME}"
  cp -f ${dockerfile_template} ${REPODIR}/${line}/Dockerfile
  run_src_container_build ${line} &
  unset CONTRAIL_CONTAINER_NAME
  rm -f ${REPODIR}/${line}/Dockerfile
fi
done < ${publish_list_file}

wait

if [[ $(cat ${build_log_file} | grep ERROR | wc -l) > 0 ]] ; then
  echo "ERROR: There were some errors when source containers builded. See log ${build_log_file}"
  exit 1
else
  echo "INFO: Source containers has been successfuly built"
  exit 0
fi

