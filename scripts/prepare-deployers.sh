#!/bin/bash -e

REPODIR=${REPODIR:-"/root/src/${CANONICAL_HOSTNAME}/Juniper"}

CONTRAIL_DEPLOYERS_DIR=${CONTRAIL_DEPLOYERS_DIR:-"${REPODIR}/contrail-deployers-containers"}
BRANCH=${SB_BRANCH:-master}

[ -d ${CONTRAIL_DEPLOYERS_DIR} ] || git clone https://github.com/Juniper/contrail-deployers-containers -b ${BRANCH}  ${CONTRAIL_DEPLOYERS_DIR}
for file in tpc.repo.template common.env ; do
  if [ -f $file ]; then
    cp $file ${CONTRAIL_DEPLOYERS_DIR}
  fi
done
