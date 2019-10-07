#!/bin/bash -e

REPODIR=${REPODIR:-"/root/src/${CANONICAL_HOSTNAME}/Juniper"}
CONTAINER_BUILDER_DIR=${CONTAINER_BUILDER_DIR:-"${REPODIR}/contrail-container-builder"}

for file in tpc.repo.template common.env ; do
  if [ -f $file ]; then
    cp $file ${CONTAINER_BUILDER_DIR}
  fi
done
