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
openstack_versions=${OPENSTACK_VERSIONS:-"ocata,queens,rocky"}
CONTRAIL_KEEP_LOG_FILES=${CONTRAIL_KEEP_LOG_FILES:-'false'}

pushd ${REPODIR}

function append_log() {
  local logfile=$1
  while read line ; do
    if [[ "${CONTRAIL_KEEP_LOG_FILES,,}" != 'true' ]] ; then
      echo "$line" | tee -a $logfile
    else
      echo "$line" >> $logfile
    fi
  done
}

logfile="./build-test-base.log"
echo Build base test container | tee $logfile
./build-container.sh base \
  --registry-server ${CONTRAIL_REGISTRY} \
  --tag ${CONTRAIL_CONTAINER_TAG} 2>&1 | append_log $logfile
if [ ${PIPESTATUS[0]} -eq 0 ]; then
  echo Build base test container finished successfully | tee -a $logfile
  [[ "${CONTRAIL_KEEP_LOG_FILES,,}" != 'true' ]] && rm -f $logfile
else
  popd
  echo Failed to build base test container | append_log $logfile
  exit 1
fi

declare -A jobs
for openstack_version in ${openstack_versions//,/ } ; do
    openstack_repo_option=""
    if [[ ! -z "${OPENSTACK_REPOSITORY}" ]]; then
        echo Using openstack repository ${OPENSTACK_REPOSITORY}/openstack-${openstack_version}
        openstack_repo_option="--openstack-repo ${OPENSTACK_REPOSITORY}/openstack-${openstack_version}"
    fi

    echo Start build test container for ${openstack_version} | tee "./build-test-${openstack_version}.log"
    ./build-container.sh test \
        --base-tag ${CONTRAIL_CONTAINER_TAG} \
        --tag ${openstack_version}-${CONTRAIL_CONTAINER_TAG} \
        --registry-server ${CONTRAIL_REGISTRY} \
        --sku ${openstack_version} \
        --contrail-repo ${CONTRAIL_REPOSITORY} \
        ${openstack_repo_option} \
        --post | append_log "./build-test-${openstack_version}.log" &
    jobs+=( [$openstack_version]=$! )
done

res=0
for openstack_version in ${openstack_versions//,/ } ; do
  if (( res != 0 )) ; then
    # kill other jobs because previous  is failed
    kill %${jobs[$openstack_version]}
  fi
  if ! wait ${jobs[$openstack_version]} ; then
    echo "ERROR: Faild to build test container for ${openstack_version}" | tee -a "./build-test-${openstack_version}.log"
    res=1
  else
    echo Build test container for ${openstack_version} finished successfully | tee -a "./build-test-${openstack_version}.log"
    [[ "${CONTRAIL_KEEP_LOG_FILES,,}" != 'true' ]] && rm -f "./build-test-${openstack_version}.log"
  fi
done

popd

exit $res

