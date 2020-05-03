#!/bin/bash -e

REPODIR=${REPODIR:-"."}
CONTRAIL_DEPLOYERS_DIR=${CONTRAIL_DEPLOYERS_DIR:-"${REPODIR}/contrail-deployers-containers"}

if [ -e tpc.repo ]; then
  cp tpc.repo ${CONTRAIL_DEPLOYERS_DIR}/tpc.repo.template
fi
if [ -e common.env ]; then
  cp common.env ${CONTRAIL_DEPLOYERS_DIR}
fi