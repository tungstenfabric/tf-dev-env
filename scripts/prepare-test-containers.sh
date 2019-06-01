#!/bin/bash

REPODIR=/root/src/${CANONICAL_HOSTNAME}/Juniper/contrail-test
BRANCH=${SB_BRANCH:-master}

[ -d ${REPODIR} ] || git clone https://github.com/Juniper/contrail-test -b ${BRANCH}  ${REPODIR}
cp common.env ${REPODIR}
if [ -f tpc.repo.template ]; then
  cp tpc.repo.template ${REPODIR}/docker/base/tpc.repo
  cp tpc.repo.template ${REPODIR}/docker/test/tpc.repo
fi
