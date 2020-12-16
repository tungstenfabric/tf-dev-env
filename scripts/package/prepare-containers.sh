#!/bin/bash -ex

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../../common/common.sh"
source_env

REPODIR=${REPODIR:-"."}
CONTAINER_BUILDER_DIR=${CONTAINER_BUILDER_DIR:-"${REPODIR}/contrail-container-builder"}
COPY_REPO_GLOB=${COPY_REPO_GLOB:-"$CONTRAIL_CONFIG_DIR/etc/yum.repos.d/*.repo"}

for file in $COPY_REPO_GLOB /etc/yum.repos.d/tpc.repo; do
  if [ -e $file ]; then
    cp $file ${CONTAINER_BUILDER_DIR}/$(basename $file).template
  fi
done
if [ -e common.env ]; then
  cp common.env ${CONTAINER_BUILDER_DIR}
fi

if [ -e $CONTRAIL_CONFIG_DIR/etc/pip.conf ]; then
  cp $CONTRAIL_CONFIG_DIR/etc/pip.conf ${CONTAINER_BUILDER_DIR}/containers/general-base/
fi
