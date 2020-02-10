#!/bin/bash

echo "INFO: Build sources containers"
if [[ -z "${REPODIR}" ]] ; then
  echo "ERROR: REPODIR Must be set for build src containers"
  exit 1
fi

BUILDSH=${REPODIR}/contrail-container-builder/containers/build.sh
if ! [[ -x "${BUILDSH}" ]] ; then
  echo "ERROR: build.sh tool from contrail-container-builder is not available in ${REPODIR} or is not executable"
  exit 1
fi

PUBLISH_LIST_FILE=${PUBLISH_LIST_FILE:-"src_containers_to_publish"}
if ! [[ -f "${PUBLISH_LIST_FILE}" ]] ; then
  echo "ERROR: targets for build as src containers must be listed at ${PUBLISH_LIST_FILE}"
  exit 1
fi

DOCKERFILE_TEMPLATE=scripts/Dockerfile.src.tmpl
if ! [[ -f "${DOCKERFILE_TEMPLATE}" ]] ; then
  echo "ERROR: Dockerfile template ${DOCKERFILE_TEMPLATE} is not available."
  exit 1
fi

VENDOR_NAME=${VENDOR_NAME:-tungstenfabric}
CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-latest}

while IFS= read -r line
do
  if ! [[ "$line" =~ ^\#.*$ ]] ; then
    if ! [[ "$line" =~ ^[\-0-9a-zA-Z_.]+$ ]] ; then
      echo "ERROR: Directory name ${line} must contain only latin letters, digits or '.', '-', '_' symbols  "
      exit 1
    fi

    if ! [[ -d "${REPODIR}/${line}" ]] ; then
      echo "ERROR: not found directory ${REPODIR}/${line} mentioned in ${PUBLISH_LIST_FILE}"
      exit 1
    fi

    export CONTRAIL_CONTAINER_NAME=contrail-${line}-src
    echo "INFO: Pack $line sources to container ${CONTRAIL_CONTAINER_NAME}"
    cp -f ${DOCKERFILE_TEMPLATE} ${REPODIR}/${line}/Dockerfile
    ${BUILDSH} ${REPODIR}/${line} || /bin/true
    unset CONTRAIL_CONTAINER_NAME
  fi
done < ${PUBLISH_LIST_FILE}


