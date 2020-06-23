#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../../common/common.sh"
source_env

[ -n "$DEBUG" ] && set -x

REPODIR=${REPODIR:-"."}
CONTRAIL_TEST_DIR=${CONTRAIL_TEST_DIR:-"${REPODIR}/third_party/contrail-test"}

if [[ -z "${CONTRAIL_REGISTRY}" ]]; then
  echo "CONTRAIL_REGISTRY is not set" && exit 1
fi

if [[ -z "${CONTRAIL_REPOSITORY}" ]]; then
  echo "CONTRAIL_REPOSITORY is not set" && exit 1
fi

CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-"dev"}
openstack_versions=${OPENSTACK_VERSIONS:-"queens,rocky"}
CONTRAIL_KEEP_LOG_FILES=${CONTRAIL_KEEP_LOG_FILES:-'false'}

tpc_repo="$CONTRAIL_CONFIG_DIR/etc/yum.repos.d/tpc.repo"
if [ -f $tpc_repo ]; then
  cp $tpc_repo ${CONTRAIL_TEST_DIR}/docker/base/tpc.repo
  cp $tpc_repo ${CONTRAIL_TEST_DIR}/docker/test/tpc.repo
fi

pushd ${CONTRAIL_TEST_DIR}

if [[ -n "$CONTRAIL_CONFIG_DIR" && -d "${CONTRAIL_CONFIG_DIR}/etc/yum.repos.d" ]] ; then
  # apply same repos for test containers
  cp -f ${CONTRAIL_CONFIG_DIR}/etc/yum.repos.d/* ./docker/base/
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
        --tag ${openstack_version}-${CONTRAIL_CONTAINER_TAG} \
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
  declare -A jobs
  for openstack_version in ${openstack_versions//,/ } ; do
      build_for_os_version $openstack_version &
      jobs+=( [$openstack_version]=$! )
  done

  for openstack_version in ${openstack_versions//,/ } ; do
    if (( res != 0 )) ; then
      # kill other jobs because previous is failed
      kill %${jobs[$openstack_version]}
    fi
    if ! wait ${jobs[$openstack_version]} ; then
      res=1
    fi
  done
fi

popd

mkdir -p /output/logs/contrail-test
# do not fail script if logs files are absent
mv ${CONTRAIL_TEST_DIR}/*.log /output/logs/contrail-test || /bin/true

exit $res
