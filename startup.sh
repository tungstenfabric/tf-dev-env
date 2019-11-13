#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common/common.sh
source ${scriptdir}/common/functions.sh

stages="$@"

cd "$scriptdir"

# Build options

# enable build of development sandbox 
export BUILD_DEV_ENV=${BUILD_DEV_ENV:-0}
export BUILD_DEV_ENV_ON_PULL_FAIL=${BUILD_DEV_ENV_ON_PULL_FAIL:-1}

# enable build from sources (w/o RPMs)
export CONTRAIL_BUILD_FROM_SOURCE=${CONTRAIL_BUILD_FROM_SOURCE:-}

# variables that can be redefined outside (for CI)
EXTERNAL_REPOS=${EXTERNAL_REPOS:-/root/src}
CANONICAL_HOSTNAME=${CANONICAL_HOSTNAME:-"review.opencontrail.org"}
SITE_MIRROR=${SITE_MIRROR:-}


echo tf-dev-env startup
echo
echo '[ensure python is present]'
if [ x"$DISTRO" == x"centos" ]; then
  sudo yum install -y python lsof
elif [ x"$DISTRO" == x"rhel" ]; then
  sudo yum install -y python lsof
elif [ x"$DISTRO" == x"ubuntu" ]; then
  sudo apt-get install -y python-minimal lsof
fi

# prepare env
mkdir -p "${CONTRAIL_DIR}/RPMS"
sudo -E $scriptdir/common/setup_docker.sh
sudo -E $scriptdir/common/setup_docker_registry.sh
sudo -E $scriptdir/common/setup_rpm_repo.sh
load_tf_devenv_profile

echo
echo "INFO: make common.env"
cat $scriptdir/common.env.tmpl | envsubst > $scriptdir/common.env
echo "INFO: common.env content:"
cat $scriptdir/common.env

timestamp=$(date +"%d_%m_%Y__%H_%M_%S")
log_path="${WORKSPACE}/build_${timestamp}.log"

echo
echo '[environment setup]'
if ! is_container_created "$TF_DEVENV_CONTAINER_NAME"; then
  options="-e LC_ALL=en_US.UTF-8 -e LANG=en_US.UTF-8 -e LANGUAGE=en_US.UTF-8 "
  options+=" -v ${CONTRAIL_DIR}:/root/contrail:z"
  options+=" -e DEVENVTAG=$DEVENVTAG"
  
  if [[ -n "${SRC_ROOT}" ]]; then
    options+=" -e CONTRAIL_SOURCE=$SRC_ROOT"
  fi

  if [ -n "$CONTRAIL_BUILD_FROM_SOURCE" ]; then
    options+=" -e CONTRAIL_BUILD_FROM_SOURCE=${CONTRAIL_BUILD_FROM_SOURCE}"
  fi

  if [[ -n "${CANONICAL_HOSTNAME}" ]]; then
    options+=" -e CANONICAL_HOSTNAME=${CANONICAL_HOSTNAME}"
  fi

  if [[ -n "${SITE_MIRROR}" ]]; then
    options+=" -e SITE_MIRROR=${SITE_MIRROR}"
  fi

  if [[ -n "$DEBUG" ]] ; then
    options+=" -e DEBUG=${DEBUG}"
  fi

  if [[ "$RUN_UNIT_TESTS" == '1' ]] ; then
    options+=" -e RUN_UNIT_TESTS=1"
  fi

  if [[ "$BUILD_DEV_ENV" != '1' ]] && ! is_container_created $DEVENV_IMAGE ; then
    if ! docker inspect $DEVENV_IMAGE >/dev/null 2>&1 && ! docker pull $DEVENV_IMAGE ; then
      if [[ "$BUILD_DEV_ENV_ON_PULL_FAIL" != '1' ]]; then
        exit 1
      fi
      echo No image $DEVENV_IMAGE is available. Try to build.
      BUILD_DEV_ENV=1
    fi
  fi

  if [[ "$BUILD_DEV_ENV" == '1' ]]; then
    echo Build $DEVENV_IMAGE docker image
    if [[ -d ${scriptdir}/config/etc/yum.repos.d ]]; then
      cp -f ${scriptdir}/config/etc/yum.repos.d/* ${scriptdir}/container/
    fi
    cd ${scriptdir}/container
    dev_env_source=${DISTRO}
    if [[ "$dev_env_source" == 'ubuntu' ]]; then
      dev_env_source='centos'
    fi
    sudo -E ./build.sh -i ${IMAGE} -d ${dev_env_source} ${DEVENVTAG}
    cd ${scriptdir}
  fi

  volumes="-v /var/run/docker.sock:/var/run/docker.sock"
  volumes+=" -v ${scriptdir}:/root/tf-dev-env"
  volumes+=" -v ${scriptdir}/container/entrypoint.sh:/root/entrypoint.sh"
  if [[ -d "${scriptdir}/config" ]]; then
    volumes+=" -v ${scriptdir}/config:/config"
  fi
  start_sandbox_cmd="sudo -E docker run --network host --privileged --detach \
    --name $TF_DEVENV_CONTAINER_NAME \
    -w /root ${options} \
    -e CONTRAIL_DEV_ENV=/root/tf-dev-env \
    $volumes -it \
    ${DEVENV_IMAGE}"

  eval $start_sandbox_cmd 2>&1 | tee ${log_path}

  echo $TF_DEVENV_CONTAINER_NAME created.
else
  if is_container_up "$TF_DEVENV_CONTAINER_NAME"; then
    echo "$TF_DEVENV_CONTAINER_NAME already running."
  else
    echo $(sudo -E docker start $TF_DEVENV_CONTAINER_NAME) started.
  fi
fi

echo "run stages $stages" 
sudo -E docker exec -i $TF_DEVENV_CONTAINER_NAME /root/startup.sh $stages | tee -a ${log_path}
result=${PIPESTATUS[0]}

if [[ $result == 0 ]] ; then
  echo
  echo '[DONE]'
  echo "If needed You can now connect to the sandbox container by using:"
  echo "  docker exec -it $TF_DEVENV_CONTAINER_NAME bash"
else
  echo
  echo 'ERROR: There were failures. See logs for details.'
fi

exit $result
