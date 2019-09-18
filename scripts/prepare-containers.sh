#!/bin/bash -e

REPODIR=${REPODIR:-"/root/src/${CANONICAL_HOSTNAME}/Juniper"}

CONTAINER_BUILDER_DIR=${CONTAINER_BUILDER_DIR:-"${REPODIR}/contrail-container-builder"}
BRANCH=${SB_BRANCH:-master}

[ -d ${CONTAINER_BUILDER_DIR} ] || git clone https://github.com/Juniper/contrail-container-builder -b ${BRANCH}  ${CONTAINER_BUILDER_DIR}
for file in tpc.repo.template common.env ; do
  if [ -f $file ]; then
    cp $file ${CONTAINER_BUILDER_DIR}
  fi
done
