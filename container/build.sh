#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/../common/common.sh

function mysudo() {
    if [[ $DISTRO == "macosx" ]]; then
        "$@"
    else
        sudo $@
    fi
}

LINUX_DISTR=${LINUX_DISTR:-'centos'}
LINUX_DISTR_VER=${LINUX_DISTR_VER:-}

CONTRAIL_KEEP_LOG_FILES=${CONTRAIL_KEEP_LOG_FILES:-'false'}

mkdir -p ${WORKSPACE}/output/logs
logfile="${WORKSPACE}/output/logs/build-tf-dev-env.log"
echo "Building tf-dev-env image: ${DEVENV_IMAGE}" | tee $logfile

build_opts="--build-arg LC_ALL=en_US.UTF-8 --build-arg LANG=en_US.UTF-8 --build-arg LANGUAGE=en_US.UTF-8"
build_opts+=" --network host --no-cache --tag ${DEVENV_IMAGE} --tag ${CONTAINER_REGISTRY}/${DEVENV_IMAGE} -f Dockerfile.${LINUX_DISTR} ."

if [[ "$ENABLE_RHSM_REPOS" == 'true' ]] ; then
    build_opts+=" --build-arg ENABLE_RHSM_REPOS=$ENABLE_RHSM_REPOS"
fi

if [[ $DISTRO != 'macosx' ]] ; then
    CONTRAIL_KEEP_LOG_FILES=${CONTRAIL_KEEP_LOG_FILES,,}
fi
if [[ "${CONTRAIL_KEEP_LOG_FILES}" != 'true' ]] ; then
   mysudo docker build $build_opts 2>&1 | tee -a $logfile
   result=${PIPESTATUS[0]}
   if [ $result -eq 0 ]; then
      rm -f $logfile
   fi
else
   # skip output into terminal
   mysudo docker build $build_opts >> $logfile 2>&1
   result=${PIPESTATUS[0]}
fi

exit $result
