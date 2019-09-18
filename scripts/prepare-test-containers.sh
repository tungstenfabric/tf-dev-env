#!/bin/bash -e

REPODIR=${REPODIR:-"/root/src/${CANONICAL_HOSTNAME}/Juniper"}

CONTRAIL_TEST_DIR=${CONTRAIL_TEST_DIR:-"${REPODIR}/contrail-test"}
BRANCH=${SB_BRANCH:-master}

[ -d ${CONTRAIL_TEST_DIR} ] || git clone https://github.com/Juniper/contrail-test -b ${BRANCH}  ${CONTRAIL_TEST_DIR}
cp common.env ${CONTRAIL_TEST_DIR}
if [ -f tpc.repo.template ]; then
  cp tpc.repo.template ${CONTRAIL_TEST_DIR}/docker/base/tpc.repo
  cp tpc.repo.template ${CONTRAIL_TEST_DIR}/docker/test/tpc.repo
fi
