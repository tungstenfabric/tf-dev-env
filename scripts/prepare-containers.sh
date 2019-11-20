#!/bin/bash -ex

REPODIR=${REPODIR:-"/root/src/${CANONICAL_HOSTNAME}/Juniper"}
CONTAINER_BUILDER_DIR=${CONTAINER_BUILDER_DIR:-"${REPODIR}/contrail-container-builder"}
COPY_REPO_GLOB=${COPY_REPO_GLOB:-"config/etc/yum.repos.d/*.repo"}

for file in $COPY_REPO_GLOB tpc.repo.template; do
  if [ -f $file ]; then
    if ! echo $file | egrep -q '.template$'; then
      cp $file ${CONTAINER_BUILDER_DIR}/$(basename $file).template
    else
      cp $file ${CONTAINER_BUILDER_DIR}
    fi
  fi
done
if [ -f common.env ]; then
  cp common.env ${CONTAINER_BUILDER_DIR}
fi
