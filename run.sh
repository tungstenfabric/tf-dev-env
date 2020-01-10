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
SITE_MIRROR=${SITE_MIRROR:-}

echo tf-dev-env startup
echo
echo '[ensure python is present]'
if [ x"$DISTRO" == x"centos" ]; then
  sudo yum install -y python lsof
elif [ x"$DISTRO" == x"rhel" ]; then
  sudo yum install -y python lsof
elif [ x"$DISTRO" == x"ubuntu" ]; then
  export DEBIAN_FRONTEND=noninteractive
  sudo -E apt-get install -y python-minimal lsof
fi

# prepare env
$scriptdir/common/setup_docker.sh
$scriptdir/common/setup_docker_registry.sh
$scriptdir/common/setup_rpm_repo.sh
load_tf_devenv_profile

echo
echo "INFO: make common.env"
cat $scriptdir/common.env.tmpl | envsubst > $scriptdir/common.env
echo "INFO: common.env content:"
cat $scriptdir/common.env

timestamp=$(date +"%d_%m_%Y__%H_%M_%S")
log_path="${WORKSPACE}/build_${timestamp}.log"

# make env profile for run inside container
tf_container_env_dir=${CONTRAIL_DIR}/.env
mkdir -p $tf_container_env_dir
tf_container_env_file=${tf_container_env_dir}/tf-developer-sandbox.env
cat <<EOF > $tf_container_env_file
DEBUG=${DEBUG}
CONTRAIL_DEV_ENV=/root/tf-dev-env
DEVENVTAG=$DEVENVTAG
CONTRAIL_SOURCE=$CONTRAIL_DIR
CONTRAIL_BUILD_FROM_SOURCE=${CONTRAIL_BUILD_FROM_SOURCE}
SITE_MIRROR="${SITE_MIRROR}"
CONTRAIL_KEEP_LOG_FILES=${CONTRAIL_KEEP_LOG_FILES}
EOF

if [[ -d "${scriptdir}/config" ]]; then
  cat <<EOF >> $tf_container_env_file
CONTRAIL_CONFIG_DIR=${CONTRAIL_CONFIG_DIR:-"/config"}
EOF
fi

if [[ -n "$GERRIT_CHANGE_ID" && -n "$GERRIT_CHANGE_URL" && -n "$GERRIT_BRANCH" ]] ; then
  cat <<EOF >> $tf_container_env_file
# code review system options
GERRIT_CHANGE_ID=$GERRIT_CHANGE_ID
GERRIT_CHANGE_URL=$GERRIT_CHANGE_URL
GERRIT_BRANCH=$GERRIT_BRANCH
GERRIT_CHANGE_NUMBER=$GERRIT_CHANGE_NUMBER
GERRIT_PATCHSET_NUMBER=$GERRIT_PATCHSET_NUMBER
GERRIT_PROJECT=$GERRIT_PROJECT
EOF
fi

echo
echo '[environment setup]'
if ! is_container_created "$TF_DEVENV_CONTAINER_NAME"; then
  if [[ "$BUILD_DEV_ENV" != '1' ]] && ! is_container_created $DEVENV_IMAGE ; then
    if ! sudo docker inspect $DEVENV_IMAGE >/dev/null 2>&1 && ! sudo docker pull $DEVENV_IMAGE ; then
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
    ./build.sh -i ${IMAGE} -d ${dev_env_source} ${DEVENVTAG}
    cd ${scriptdir}
  fi

  options="-e LC_ALL=en_US.UTF-8 -e LANG=en_US.UTF-8 -e LANGUAGE=en_US.UTF-8 "
  volumes="-v /var/run:/var/run:z"
  volumes+=" -v ${scriptdir}:/root/tf-dev-env:z"
  if [[ "$BIND_CONTRAIL_DIR" != 'false' ]] ; then
    volumes+=" -v ${CONTRAIL_DIR}:/root/contrail:z"
  fi
  volumes+=" -v ${CONTRAIL_DIR}/logs:/root/contrail/logs:z"
  volumes+=" -v ${CONTRAIL_DIR}/RPMS:/root/contrail/RPMS:z"
  volumes+=" -v ${tf_container_env_dir}:/root/contrail/.env:z"
  if [[ -d "${scriptdir}/config" ]]; then
    volumes+=" -v ${scriptdir}/config:/config:z"
  fi
  # Provide env variables because:
  #  - there is backward compatibility case with manual doing docker exec
  #  into container and user of make.
  #  - TF Jenkins CI use non-bind folder for sources
  start_sandbox_cmd="sudo docker run --network host --privileged --detach \
    --name $TF_DEVENV_CONTAINER_NAME \
    -w /root ${options} \
    $volumes -it \
    --env-file $tf_container_env_file \
    ${DEVENV_IMAGE}"

  eval $start_sandbox_cmd 2>&1 | tee ${log_path}
  if [[ ${PIPESTATUS[0]} != 0 ]] ; then
    echo
    echo "ERROR: Failed to run $TF_DEVENV_CONTAINER_NAME container."
    exit 1
  fi

  echo $TF_DEVENV_CONTAINER_NAME created.
else
  if is_container_up "$TF_DEVENV_CONTAINER_NAME"; then
    echo "$TF_DEVENV_CONTAINER_NAME already running."
  else
    echo $(sudo docker start $TF_DEVENV_CONTAINER_NAME) started.
  fi
fi

if [[ "$stages" == 'none' ]] ; then
  echo "INFO: dont run any stages"
  exit 0
fi

# In case if contrail folder is not bint to the container from host
# it is needed to copy container builde on host to be able mount
# data into the building conainers for build from sources.
if [[ -n "$CONTRAIL_BUILD_FROM_SOURCE" && "$BIND_CONTRAIL_DIR" == 'false' ]] ; then
  if [[ ! -e ${CONTRAIL_DIR}/contrail-container-builder ]] ; then
    docker cp $TF_DEVENV_CONTAINER_NAME:/root/contrail/contrail-container-builder ${CONTRAIL_DIR}/
  fi
fi

echo "run stages $stages"
sudo docker exec -i $TF_DEVENV_CONTAINER_NAME /root/run.sh $stages | tee -a ${log_path}
result=${PIPESTATUS[0]}

if [[ $result == 0 ]] ; then
  echo
  echo '[DONE]'
  echo "There are stages avalable to run ./run.sh <stage>:"
  echo "  build     - perform sequence of stages: fetch, configure, compile, package"
  echo "              (if stage was run previously it be skipped)"
  echo "  fetch     - sync TF git repos"
  echo "  configure - fetch third party packages and install dependencies"
  echo "  compile   - buld TF binaries"
  echo "  package   - package TF into docker containers"
  echo "  test      - run unittests"
  echo "For advanced usage You can now connect to the sandbox container by using:"
  echo "  sudo docker exec -it $TF_DEVENV_CONTAINER_NAME bash"
else
  echo
  echo 'ERROR: There were failures. See logs for details.'
fi

exit $result
