#!/bin/bash -ex

REPODIR=${REPODIR:-"/root/src/${CANONICAL_HOSTNAME}/Juniper"}
CONTAINER_BUILDER_DIR=${CONTAINER_BUILDER_DIR:-"${REPODIR}/contrail-container-builder"}

for file in $CONTRAIL_CONFIG_DIR/etc/yum.repos.d/*.repo tpc.repo.template; do
  if [ -e $file ]; then
    if ! echo $file | egrep -q '.template$'; then
      cp $file ${CONTAINER_BUILDER_DIR}/$(basename $file).template
    else
      cp $file ${CONTAINER_BUILDER_DIR}
    fi
  fi
done
if [ -e common.env ]; then
  cp common.env ${CONTAINER_BUILDER_DIR}
fi
