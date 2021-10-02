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
LINUX_DISTR_VER=${LINUX_DISTR_VER:-7}

CONTRAIL_KEEP_LOG_FILES=${CONTRAIL_KEEP_LOG_FILES:-'false'}

mkdir -p ${WORKSPACE}/output/logs
logfile="${WORKSPACE}/output/logs/build-tf-dev-env.log"
echo "Building tf-dev-env image: ${DEVENV_IMAGE}" | tee $logfile

build_opts="--build-arg LC_ALL=en_US.UTF-8 --build-arg LANG=en_US.UTF-8 --build-arg LANGUAGE=en_US.UTF-8"
build_opts+=" --build-arg LINUX_DISTR=$LINUX_DISTR --build-arg LINUX_DISTR_VER=$LINUX_DISTR_VER"
build_opts+=" --build-arg SITE_MIRROR=${SITE_MIRROR:+${SITE_MIRROR}/external-web-cache}"
if [ -n "$YUM_ENABLE_REPOS" ] ; then
    build_opts+=" --build-arg YUM_ENABLE_REPOS=$YUM_ENABLE_REPOS"
fi
if [[ "$LINUX_DISTR" =~ 'centos' ]] ; then
    docker_file="Dockerfile.centos"
else
    if [[ "$LINUX_DISTR" =~ 'ubi7' ]] ; then
        docker_file="Dockerfile.ubi7"
    else
        docker_file="Dockerfile.ubi8"
    fi
    if [[ -n "$YUM_SM_PLUGIN_ENABLED" ]] ; then
        build_opts+=" --build-arg YUM_SM_PLUGIN_ENABLED=$YUM_SM_PLUGIN_ENABLED"
    fi
fi

docker_ver=$(mysudo docker -v | awk -F' ' '{print $3}' | sed 's/,//g')
echo "Docker version: $docker_ver"

if [[ "$docker_ver" < '17.06' ]] ; then
    # old docker can't use ARG-s before FROM:
    # comment all ARG-s before FROM
    cat ${docker_file} | awk '{if(ncmt!=1 && $1=="ARG"){print("#"$0)}else{print($0)}; if($1=="FROM"){ncmt=1}}' > ${docker_file}.nofromargs
    # and then change FROM-s that uses ARG-s
    sed -i \
        -e "s|^FROM \${CONTRAIL_REGISTRY}/\([^:]*\):\${CONTRAIL_CONTAINER_TAG}|FROM ${CONTRAIL_REGISTRY}/\1:${tag}|" \
        -e "s|^FROM \$LINUX_DISTR:\$LINUX_DISTR_VER|FROM $LINUX_DISTR:$LINUX_DISTR_VER|" \
        -e "s|^FROM \$UBUNTU_DISTR:\$UBUNTU_DISTR_VERSION|FROM $UBUNTU_DISTR:$UBUNTU_DISTR_VERSION|" \
        ${docker_file}.nofromargs
    docker_file="${docker_file}.nofromargs"
fi

build_opts+=" --network host --no-cache --tag ${DEVENV_IMAGE} --tag ${CONTAINER_REGISTRY}/${DEVENV_IMAGE} -f $docker_file ."

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
