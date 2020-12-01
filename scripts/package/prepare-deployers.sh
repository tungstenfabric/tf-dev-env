#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../../common/common.sh"
source_env

REPODIR=${REPODIR:-"."}
CONTRAIL_DEPLOYERS_DIR=${CONTRAIL_DEPLOYERS_DIR:-"${REPODIR}/contrail-deployers-containers"}

tpc_repo="/etc/yum.repos.d/tpc.repo"
if [ -e $tpc_repo ]; then
  cp $tpc_repo ${CONTRAIL_DEPLOYERS_DIR}/tpc.repo.template
fi
if [ -e common.env ]; then
  cp common.env ${CONTRAIL_DEPLOYERS_DIR}
fi
