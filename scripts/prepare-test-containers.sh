#!/bin/bash -e

REPODIR=${REPODIR:-"."}
CONTRAIL_TEST_DIR=${CONTRAIL_TEST_DIR:-"${REPODIR}/contrail-test"}

cp common.env ${CONTRAIL_TEST_DIR}
if [ -f tpc.repo ]; then
  cp tpc.repo ${CONTRAIL_TEST_DIR}/docker/base/tpc.repo
  cp tpc.repo ${CONTRAIL_TEST_DIR}/docker/test/tpc.repo
fi
