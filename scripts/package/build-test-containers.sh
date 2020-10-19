#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../../common/common.sh"
source_env

REPODIR=${REPODIR:-"."}
CONTRAIL_TEST_DIR=${CONTRAIL_TEST_DIR:-"${REPODIR}/third_party/contrail-test"}

if [[ -z "${CONTRAIL_REGISTRY}" ]]; then
  echo "CONTRAIL_REGISTRY is not set" && exit 1
fi

export CONTRAIL_REGISTRY

if [[ -z "${CONTRAIL_REPOSITORY}" ]]; then
  echo "CONTRAIL_REPOSITORY is not set" && exit 1
fi

export CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-"dev"}
openstack_version="train"
CONTRAIL_KEEP_LOG_FILES=${CONTRAIL_KEEP_LOG_FILES:-'false'}

tpc_repo="$CONTRAIL_CONFIG_DIR/etc/yum.repos.d/tpc.repo"
if [ -f $tpc_repo ]; then
  cp $tpc_repo ${CONTRAIL_TEST_DIR}/docker/base/tpc.repo
  cp $tpc_repo ${CONTRAIL_TEST_DIR}/docker/test/tpc.repo
fi

pushd ${CONTRAIL_TEST_DIR}

if [[ -n "$CONTRAIL_CONFIG_DIR" && -d "${CONTRAIL_CONFIG_DIR}/etc/yum.repos.d" ]] ; then
  # apply same repos for test containers
  cp -f ${CONTRAIL_CONFIG_DIR}/etc/yum.repos.d/* docker/base/
fi

function append_log() {
  local logfile=$1
  local always_echo=${2:-'false'}
  while read line ; do
    if [[ "${CONTRAIL_KEEP_LOG_FILES,,}" != 'true' || "$always_echo" != 'false' ]] ; then
      echo "$line" | tee -a $logfile
    else
      echo "$line" >> $logfile
    fi
  done
}

function build_for_os_version() {
    local openstack_version=$1
    local logfile="./build-test-${openstack_version}.log"
    local openstack_repo_option=""
    if [[ ! -z "${OPENSTACK_REPOSITORY}" ]]; then
        echo Using openstack repository ${OPENSTACK_REPOSITORY}/openstack-${openstack_version}
        openstack_repo_option="--openstack-repo ${OPENSTACK_REPOSITORY}/openstack-${openstack_version}"
    fi

    echo "INFO: Start build test container for ${openstack_version}" | append_log $logfile true
    ./build-container.sh test \
        --base-tag ${CONTRAIL_CONTAINER_TAG} \
        --tag ${CONTRAIL_CONTAINER_TAG} \
        --registry-server ${CONTRAIL_REGISTRY} \
        --sku ${openstack_version} \
        --contrail-repo ${CONTRAIL_REPOSITORY} \
        ${openstack_repo_option} \
        --post | append_log $logfile

    local res=${PIPESTATUS[0]}
    if [ $res -eq 0 ]; then
      echo "INFO: Build test container for ${openstack_version} finished successfully" | append_log $logfile true
      [[ "${CONTRAIL_KEEP_LOG_FILES,,}" != 'true' ]] && rm -f $logfile
    else
      echo "ERROR: Faild to build test container for ${openstack_version}" | append_log $logfile true
    fi
    return $res
}

res=0

logfile="./build-test-base.log"
echo "INFO: Build base test container" | append_log $logfile true
./build-container.sh base \
  --registry-server ${CONTRAIL_REGISTRY} \
  --tag ${CONTRAIL_CONTAINER_TAG} 2>&1 | append_log $logfile
if [ ${PIPESTATUS[0]} -eq 0 ]; then
  echo "INFO: Build base test container finished successfully" | append_log $logfile true
  [[ "${CONTRAIL_KEEP_LOG_FILES,,}" != 'true' ]] && rm -f $logfile
else
  echo "ERROR: Failed to build base test container" | append_log $logfile true
  res=1
fi

if [[ $res == '0' ]]; then
  build_for_os_version $openstack_version
fi

popd

contrail_test_logs="${CONTRAIL_OUTPUT_DIR:-/output}/logs/contrail-test"
mkdir -p "$contrail_test_logs"
# do not fail script if logs files are absent
mv "${CONTRAIL_TEST_DIR}"/*.log "$contrail_test_logs" || /bin/true


deployment_test_logfile="${WORKSPACE}/tf_deployment_test_build_containers.log"
if [[ $res == '0' && -e ${REPODIR}/tf-deployment-test/build-containers.sh ]]; then
  ${REPODIR}/tf-deployment-test/build-containers.sh | append_log $deployment_test_logfile true || res=1
fi

tf_deployment_test_logs="${CONTRAIL_OUTPUT_DIR:-/output}/logs/tf-deployment-test"
mkdir -p "$tf_deployment_test_logs"
# do not fail script if logs file is absent
mv "$deployment_test_logfile" "$tf_deployment_test_logs" || /bin/true


exit $res
