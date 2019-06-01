#!/bin/bash

REPODIR=/root/src/${CANONICAL_HOSTNAME}/Juniper/contrail-container-builder
BRANCH=${SB_BRANCH:-master}

[ -d ${REPODIR} ] || git clone https://github.com/Juniper/contrail-container-builder -b ${BRANCH}  ${REPODIR}
for file in tpc.repo.template common.env ; do
  if [ -f $file ]; then
    cp $file ${REPODIR}
  fi
done
