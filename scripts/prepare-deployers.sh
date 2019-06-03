#!/bin/bash

PROJECTDIR=/root/src/${CANONICAL_HOSTNAME}/Juniper
REPODIR=${PROJECTDIR}/contrail-deployers-containers
BRANCH=${SB_BRANCH:-master}

function link_deployers_project() {
    project_name=$1

    if [ -d ${PROJECTDIR}/${project_name} ] && [ ! -d /root/${project_name} ]; then
        ln -s ${PROJECTDIR}/${project_name} /root/${project_name}
    fi
}

[ -d ${REPODIR} ] || git clone https://github.com/Juniper/contrail-deployers-containers -b ${BRANCH}  ${REPODIR}
for file in tpc.repo.template common.env ; do
  if [ -f $file ]; then
    cp $file ${REPODIR}
  fi
done

link_deployers_project contrail-helm-deployer
link_deployers_project openstack-helm
link_deployers_project openstack-helm-infra
