#!/bin/bash

REPODIR=/root/src/${CANONICAL_HOSTNAME}/Juniper/contrail-test
BRANCH=${SB_BRANCH:-master}

[ -d ${REPODIR} ] || git clone https://github.com/Juniper/contrail-test -b ${BRANCH}  ${REPODIR}
cp common.env ${REPODIR}
cp tpc.repo ${REPODIR}/docker/test/
