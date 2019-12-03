#!/bin/bash -e

REPODIR=${REPODIR:-"."}
CONTRAIL_DEPLOYERS_DIR=${CONTRAIL_DEPLOYERS_DIR:-"${REPODIR}/contrail-deployers-containers"}

for file in tpc.repo.template common.env ; do
  if [ -f $file ]; then
    cp $file ${CONTRAIL_DEPLOYERS_DIR}
  fi
done
