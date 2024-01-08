#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common/common.sh
source ${scriptdir}/common/functions.sh
source ${scriptdir}/common/tf_functions.sh

stage="$1"
target="$2"

cd "$scriptdir"

# Build options

# enable build of development sandbox
export BUILD_DEV_ENV=${BUILD_DEV_ENV:-0}
export BUILD_DEV_ENV_ON_PULL_FAIL=${BUILD_DEV_ENV_ON_PULL_FAIL:-1}

# variables that can be redefined outside (for CI)
SITE_MIRROR=${SITE_MIRROR:-}

# very specific stage - here all containers must be up and all prerequisites must be inatalled
if [[ "$stage" == 'upload' ]]; then
  # Pushes devenv (or potentially other containers) to external registry
  echo "INFO: pushing devenv to container registry"
  mysudo docker stop ${DEVENV_CONTAINER_NAME}
  commit_opts=''
  if [[ "$DISTRO_VER_MAJOR" == '8' ]] ; then
    commit_opts+=' --format docker'
  fi
  echo "INFO: commit container: docker commit $commit_opts ${DEVENV_CONTAINER_NAME} ${CONTAINER_REGISTRY}/${DEVENV_IMAGE_NAME}:${DEVENV_PUSH_TAG}"
  mysudo docker commit $commit_opts ${DEVENV_CONTAINER_NAME} ${CONTAINER_REGISTRY}/${DEVENV_IMAGE_NAME}:${DEVENV_PUSH_TAG}
  echo "INFO: push container: docker push ${CONTAINER_REGISTRY}/${DEVENV_IMAGE_NAME}:${DEVENV_PUSH_TAG}"
  mysudo docker push ${CONTAINER_REGISTRY}/${DEVENV_IMAGE_NAME}:${DEVENV_PUSH_TAG}
  exit 0
fi

echo "INFO: tf-dev-env startup"
echo
echo 'INFO: ensure python is present'
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

# make env profile to run inside container
# input dir can be already created and had files like patchsets-info.json, unittest_targets.lst
input_dir="${scriptdir}/input"
mkdir -p "$input_dir"
tf_container_env_file="${input_dir}/tf-developer-sandbox.env"
create_env_file "$tf_container_env_file"

# mount this dir always - some stage can put files there even if it was empty when container was created
mkdir -p ${scriptdir}/config

devenv_image="$CONTAINER_REGISTRY/$DEVENV_IMAGE"

echo
echo 'INFO: environment setup'
if ! is_container_created "$DEVENV_CONTAINER_NAME"; then
  if [[ "$stage" == 'frozen' ]]; then
    echo "INFO: fetching frozen tf-dev-env from CI registry"
    devenv_image="$FROZEN_REGISTRY/$DEVENV_IMAGE_NAME:frozen"
  fi

  if [[ "$BUILD_DEVDEV_ENV" != '1' ]] && ! is_container_created ${devenv_image} ; then
    if ! mysudo docker inspect $devenv_image >/dev/null 2>&1 && ! mysudo docker pull $devenv_image ; then
      if [[ "$BUILD_DEV_ENV_ON_PULL_FAIL" != '1' ]]; then
        exit 1
      fi
      echo "INFO: No image $devenv_image is available. Try to build."
      BUILD_DEV_ENV=1
    fi
  fi

  if [[ "$BUILD_DEV_ENV" == '1' ]]; then
    echo "INFO: Build $DEVENV_IMAGE_NAME:$DEVENV_TAG docker image"
    cd ${scriptdir}/container
    ./build.sh -i ${DEVENV_IMAGE_NAME} ${DEVENV_TAG}
    cd ${scriptdir}
  fi

  options="-e LC_ALL=en_US.UTF-8 -e LANG=en_US.UTF-8 -e LANGUAGE=en_US.UTF-8 "
  volumes=""
  if [[ $DISTRO != "macosx" ]]; then
    volumes+=" -v /etc/localtime:/etc/localtime:${DOCKER_VOLUME_OPTIONS}"
  fi
  volumes+=" -v ${scriptdir}:/root/tf-dev-env:${DOCKER_VOLUME_OPTIONS}"
  if [[ "$BIND_CONTRAIL_DIR" != 'false' ]] ; then
    # make dir to create them under current user
    mkdir -p ${CONTRAIL_DIR}
    volumes+=" -v ${CONTRAIL_DIR}:/root/contrail:${DOCKER_VOLUME_OPTIONS}"
  fi
  # make dir to create them under current user
  mkdir -p ${WORKSPACE}/output/logs
  volumes+=" -v ${WORKSPACE}/output:/output:${DOCKER_VOLUME_OPTIONS}"
  volumes+=" -v ${input_dir}:/input:${DOCKER_VOLUME_OPTIONS}"
  volumes+=" -v ${scriptdir}/config:/config:${DOCKER_VOLUME_OPTIONS}"

  if [[ "$DISTRO" == 'rhel' && "$(echo $DISTRO_VER | cut -d '.' -f 1)" == '8' ]] ; then
    echo "INFO: add podman container options for rhel8 env"
    volumes+=' -v /var/run:/var/run'
    volumes+=' -v /run/runc:/run/runc'
    volumes+=' -v /sys/fs/cgroup:/sys/fs/cgroup:ro'
    volumes+=' -v /sys/fs/selinux:/sys/fs/selinux'
    volumes+=' -v /var/lib/containers:/var/lib/containers:shared'
    volumes+=' -v /etc/containers:/etc/containers:ro'
    volumes+=' -v /usr/share/containers:/usr/share/containers:ro'
    options+=' --security-opt seccomp=unconfined'
    options+=' --security-opt label=disable'
    if [[ ! -e /run/runc ]] ; then
      # WA for rhel8.4 with container-tools:3.0: folder created at first podman run
      # so it is not possible to bind this folder at first run as podman
      # fails because folder doesnt exist
      sudo mkdir -v -p --context='unconfined_u:object_r:container_var_run_t:s0' -m 0600 /run/runc
    fi
  elif [[ $DISTRO != "macosx" ]]; then
    volumes+=" -v /var/run:/var/run:${DOCKER_VOLUME_OPTIONS}"
  fi

  # Provide env variables because:
  #  - there is backward compatibility case with manual doing docker exec
  #  into container and user of make.
  #  - TF Jenkins CI use non-bind folder for sources
  start_sandbox_cmd="mysudo docker run --network host --privileged --detach \
    --name $DEVENV_CONTAINER_NAME \
    -w /root ${options} \
    $volumes -it \
    $devenv_image"

  echo "INFO: start cmd '$start_sandbox_cmd'"
  eval $start_sandbox_cmd 2>&1
  if [[ ${PIPESTATUS[0]} != 0 ]] ; then
    echo
    echo "ERROR: Failed to run $DEVENV_CONTAINER_NAME container."
    exit 1
  fi

  echo $DEVENV_CONTAINER_NAME created.
else
  if is_container_up "$DEVENV_CONTAINER_NAME"; then
    echo "INFO: $DEVENV_CONTAINER_NAME already running."
  else
    echo "INFO: $(mysudo docker start $DEVENV_CONTAINER_NAME) started."
  fi
fi

if [[ "$stage" == 'none' || "$stage" == 'frozen' ]] ; then
  echo "INFO: don't run any stages"
  exit 0
fi

if [[ "$stage" == 'test' ]] && which atop >/dev/null 2>&1 ; then
   nohup sudo atop -w ${WORKSPACE}/output/logs/atop 60 > ${WORKSPACE}/output/logs/atop.log 2>&1 < /dev/null &
fi

echo "INFO: run stage $stage with target $target"
mysudo docker exec -i $DEVENV_CONTAINER_NAME /root/tf-dev-env/container/run.sh $stage $target
result=${PIPESTATUS[0]}

if [[ "$BIND_CONTRAIL_DIR" != 'false' ]] ; then
  # do chown for sources that were cloned with root inside container
  if ! mysudo chown -R $(id -u):$(id -g) $CONTRAIL_DIR ; then
    echo "WARNING: owner for sources folder was not changed correctly."
  fi
fi

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
  echo "  upload    - push tf-dev-env to container registry"
  echo "  none      - create the tf-dev-env container empty"
  echo "  frozen    - fetch frozen tf-dev-env from Ci registry, you still have to use run.sh or fetch/configure to get sources"
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
