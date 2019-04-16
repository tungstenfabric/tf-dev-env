#!/bin/bash

REPODIR=/root/src/${CANONICAL_HOSTNAME}/Juniper/contrail-deployers-containers
BRANCH=${SB_BRANCH:-master}

[ -d ${REPODIR} ] || git clone https://github.com/Juniper/contrail-deployers-containers -b ${BRANCH}  ${REPODIR}
cp tpc.repo.template common.env ${REPODIR}
