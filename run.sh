#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common/common.sh
source ${scriptdir}/common/functions.sh

stage="$1"
target="$2"

cd "$scriptdir"

# Build options

# enable build of development sandbox 
export BUILD_DEV_ENV=${BUILD_DEV_ENV:-0}
export BUILD_DEV_ENV_ON_PULL_FAIL=${BUILD_DEV_ENV_ON_PULL_FAIL:-1}

# enable build from sources (w/o RPMs)
export CONTRAIL_BUILD_FROM_SOURCE=${CONTRAIL_BUILD_FROM_SOURCE:-}

# variables that can be redefined outside (for CI)
SITE_MIRROR=${SITE_MIRROR:-}

# very specific stage - here all containers must be up and all prerequisites must be inatalled
if [[ "$stage" == 'upload' ]]; then
  # Pushes devenv (or potentially other containers) to external registry
  echo "INFO: pushing devenv to container registry"
  sudo docker stop ${DEVENV_CONTAINER_NAME}
  sudo docker commit ${DEVENV_CONTAINER_NAME} ${CONTAINER_REGISTRY}/${DEVENV_IMAGE_NAME}:${DEVENV_PUSH_TAG}
  sudo docker push ${CONTAINER_REGISTRY}/${DEVENV_IMAGE_NAME}:${DEVENV_PUSH_TAG}
  exit 0
fi

echo tf-dev-env startup
echo
echo '[ensure python is present]'
install_prerequisites_$DISTRO

# prepare env
$scriptdir/common/setup_docker.sh
$scriptdir/common/setup_docker_registry.sh
load_tf_devenv_profile

echo
echo "INFO: make common.env"
eval "cat <<< \"$(<$scriptdir/common.env.tmpl)\"" > $scriptdir/common.env
echo "INFO: common.env content:"
cat $scriptdir/common.env

timestamp=$(date +"%d_%m_%Y__%H_%M_%S")
log_path="${WORKSPACE}/build_${timestamp}.log"

# make env profile to run inside container
# input dir can be already created and had files like patchsets-info.json, unittest_targets.lst
input_dir="${scriptdir}/input"
mkdir -p "$input_dir"
tf_container_env_file="${input_dir}/tf-developer-sandbox.env"
create_env_file "$tf_container_env_file"

# mount this dir always - some stage can put files there even if it was empty when container was created
mkdir -p ${scriptdir}/config
# and put tpc.repo there cause stable image doesn't have it
mkdir -p ${scriptdir}/config/etc/yum.repos.d
cp -f ${scriptdir}/tpc.repo ${scriptdir}/config/etc/yum.repos.d/

echo
echo '[environment setup]'
if ! is_container_created "$DEVENV_CONTAINER_NAME"; then
  if [[ "$BUILD_DEV_ENV" != '1' ]] && ! is_container_created ${CONTAINER_REGISTRY}/$DEVENV_IMAGE ; then
    if ! mysudo docker inspect ${CONTAINER_REGISTRY}/$DEVENV_IMAGE >/dev/null 2>&1 && ! mysudo docker pull ${CONTAINER_REGISTRY}/$DEVENV_IMAGE ; then
      if [[ "$BUILD_DEV_ENV_ON_PULL_FAIL" != '1' ]]; then
        exit 1
      fi
      echo "No image $DEVENV_IMAGE is available. Try to build."
      BUILD_DEV_ENV=1
    fi
  fi

  if [[ "$BUILD_DEV_ENV" == '1' ]]; then
    echo "Build $DEVENV_IMAGE docker image"
    if [[ -d ${scriptdir}/config/etc/yum.repos.d ]]; then
      cp -f ${scriptdir}/config/etc/yum.repos.d/* ${scriptdir}/container/
    fi
    cd ${scriptdir}/container
    ./build.sh -i ${DEVENV_IMAGE_NAME} ${DEVENV_TAG}
    cd ${scriptdir}
  fi

  options="-e LC_ALL=en_US.UTF-8 -e LANG=en_US.UTF-8 -e LANGUAGE=en_US.UTF-8 "
  volumes="-v /var/run:/var/run:${DOCKER_VOLUME_OPTIONS}"
  if [[ $DISTRO != "macosx" ]]; then
      volumes+=" -v /etc/localtime:/etc/localtime"
  fi
  volumes+=" -v ${scriptdir}:/$DEVENV_USER/tf-dev-env:${DOCKER_VOLUME_OPTIONS}"
  if [[ "$BIND_CONTRAIL_DIR" != 'false' ]] ; then
    volumes+=" -v ${CONTRAIL_DIR}:/$DEVENV_USER/contrail:${DOCKER_VOLUME_OPTIONS}"
  elif [[ -n "$CONTRAIL_BUILD_FROM_SOURCE" && -n "${src_volume_name}" ]] ; then
    volumes+=" -v ${src_volume_name}:/$DEVENV_USER/contrail:${DOCKER_VOLUME_OPTIONS}"
  fi
  # make dir to create them under current user
  mkdir -p ${WORKSPACE}/output
  volumes+=" -v ${WORKSPACE}/output:/output:${DOCKER_VOLUME_OPTIONS}"
  volumes+=" -v ${input_dir}:/input:${DOCKER_VOLUME_OPTIONS}"
  volumes+=" -v ${scriptdir}/config:/config:${DOCKER_VOLUME_OPTIONS}"
  # Provide env variables because:
  #  - there is backward compatibility case with manual doing docker exec
  #  into container and user of make.
  #  - TF Jenkins CI use non-bind folder for sources
  start_sandbox_cmd="mysudo docker run --network host --privileged --detach \
    --name $DEVENV_CONTAINER_NAME \
    -w /$DEVENV_USER ${options} \
    $volumes -it \
    --env-file $tf_container_env_file \
    ${CONTAINER_REGISTRY}/${DEVENV_IMAGE}"

  echo "INFO: start cmd '$start_sandbox_cmd'"
  eval $start_sandbox_cmd 2>&1 | tee ${log_path}
  if [[ ${PIPESTATUS[0]} != 0 ]] ; then
    echo
    echo "ERROR: Failed to run $DEVENV_CONTAINER_NAME container."
    exit 1
  fi

  echo $DEVENV_CONTAINER_NAME created.
else
  if is_container_up "$DEVENV_CONTAINER_NAME"; then
    echo "$DEVENV_CONTAINER_NAME already running."
  else
    echo "$(mysudo docker start $DEVENV_CONTAINER_NAME) started."
  fi
fi

if [[ "$stage" == 'none' ]] ; then
  echo "INFO: don't run any stages"
  exit 0
fi

echo "run stage $stage with target $target"
mysudo docker exec -i $DEVENV_CONTAINER_NAME /$DEVENV_USER/tf-dev-env/container/run.sh $stage $target | tee -a ${log_path}
result=${PIPESTATUS[0]}

if [[ $result == 0 ]] ; then
  echo
  echo '[DONE]'
  echo "There are stages available to run ./run.sh <stage>:"
  echo "  build     - perform sequence of stages: fetch, configure, compile, package"
  echo "              (if stage was run previously it be skipped)"
  echo "  fetch     - sync TF git repos"
  echo "  configure - fetch third party packages and install dependencies"
  echo "  compile   - build TF binaries"
  echo "  package   - package TF into docker containers (you can specify target container to build like container-vrouter)"
  echo "  test      - run unittests"
  echo "  freeze    - prepare tf-dev-env for pushing to container registry for future reuse by compressing contrail directory"
  echo "  upload    - pushes tf-dev-env to container registry"
  echo "For advanced usage You can now connect to the sandbox container by using:"
  if [[ $DISTRO != "macosx" ]]; then
    echo "  sudo docker exec -it $DEVENV_CONTAINER_NAME bash"
  else
    echo "  docker exec -it $DEVENV_CONTAINER_NAME bash"
  fi
else
  echo
  echo 'ERROR: There were failures. See logs for details.'
fi

exit $result
