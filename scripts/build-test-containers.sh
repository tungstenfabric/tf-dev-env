#!/bin/bash -e

REPODIR=${test_containers_builder_dir:-"/root/src/${CANONICAL_HOSTNAME}/Juniper/contrail-test"}

source ${REPODIR}/common.env

if [[ -z "${CONTRAIL_REGISTRY}" ]]; then
    echo CONTRAIL_REGISTRY is not set && exit 1
fi

if [[ -z "${CONTRAIL_REPOSITORY}" ]]; then
    echo CONTRAIL_REPOSITORY is not set && exit 1
fi

CONTRAIL_VERSION=${CONTRAIL_VERSION:-"dev"}
CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-"${CONTRAIL_VERSION}"}

pushd ${REPODIR}

echo Build base test container
./build-container.sh base \
    --registry-server ${CONTRAIL_REGISTRY} \
    --tag ${CONTRAIL_CONTAINER_TAG}

for openstack_version in "ocata" "queens" "rocky"; do
    openstack_repo_option=""
    if [[ ! -z "${OPENSTACK_REPOSITORY}" ]]; then
        echo Using openstack repository ${OPENSTACK_REPOSITORY}/openstack-${openstack_version}
        openstack_repo_option="--openstack-repo ${OPENSTACK_REPOSITORY}/openstack-${openstack_version}"
    fi

    echo Build test container for ${openstack_version}
    ./build-container.sh test \
        --base-tag ${CONTRAIL_CONTAINER_TAG} \
        --tag ${openstack_version}-${CONTRAIL_CONTAINER_TAG} \
        --registry-server ${CONTRAIL_REGISTRY} \
        --sku ${openstack_version} \
        --contrail-repo ${CONTRAIL_REPOSITORY} \
        ${openstack_repo_option} \
        --post
done

popd