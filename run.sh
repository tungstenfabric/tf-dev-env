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

# enable build from sources (w/o RPMs)
export CONTRAIL_BUILD_FROM_SOURCE=${CONTRAIL_BUILD_FROM_SOURCE:-}

# variables that can be redefined outside (for CI)
SITE_MIRROR=${SITE_MIRROR:-}

# very specific stage - here all containers must be up and all prerequisites must be inatalled
if [[ "$stage" == 'upload' ]]; then
  # Pushes devenv (or potentially other containers) to external registry
  echo "INFO: pushing devenv to container registry"
  mysudo docker stop ${DEVENV_CONTAINER_NAME}
  mysudo docker commit ${DEVENV_CONTAINER_NAME} ${CONTAINER_REGISTRY}/${DEVENV_IMAGE_NAME}:${DEVENV_PUSH_TAG}
  mysudo docker push ${CONTAINER_REGISTRY}/${DEVENV_IMAGE_NAME}:${DEVENV_PUSH_TAG}
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

devenv_image="$CONTAINER_REGISTRY/$DEVENV_IMAGE"

echo
echo '[environment setup]'

# set paths used to build inside the container
. "$tf_container_env_file"

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
      echo "No image $devenv_image is available. Try to build."
      BUILD_DEV_ENV=1
    fi
  fi

  if [[ "$BUILD_DEV_ENV" == '1' ]]; then
    echo "Build $DEVENV_IMAGE_NAME:$DEVENV_TAG docker image"
    cd ${scriptdir}/container
    ./build.sh -i ${DEVENV_IMAGE_NAME} ${DEVENV_TAG}
    cd ${scriptdir}
  fi

  volumes=""
  if [[ $DISTRO != "macosx" ]]; then
    volumes+=" -v /var/run:/var/run:${DOCKER_VOLUME_OPTIONS}"
    volumes+=" -v /etc/localtime:/etc/localtime:${DOCKER_VOLUME_OPTIONS}"
  fi
  volumes+=" -v ${scriptdir}:${DEV_ENV_ROOT}:${DOCKER_VOLUME_OPTIONS}"
  if [[ "$BIND_CONTRAIL_DIR" != 'false' ]] ; then
    # make dir to create them under current user
    mkdir -p ${CONTRAIL_DIR}
    volumes+=" -v ${CONTRAIL_DIR}:${ROOT_CONTRAIL}:${DOCKER_VOLUME_OPTIONS}"
  elif [[ -n "$CONTRAIL_BUILD_FROM_SOURCE" && -n "${src_volume_name}" ]] ; then
    volumes+=" -v ${src_volume_name}:${ROOT_CONTRAIL}:${DOCKER_VOLUME_OPTIONS}"
  fi

  # make dir to create them under current user
  mkdir -p ${WORKSPACE}/output
  volumes+=" -v ${WORKSPACE}/output:${CONTRAIL_OUTPUT_DIR}:${DOCKER_VOLUME_OPTIONS}"
  volumes+=" -v ${input_dir}:${CONTRAIL_INPUT_DIR}:${DOCKER_VOLUME_OPTIONS}"
  volumes+=" -v ${scriptdir}/config:${CONTRAIL_CONFIG_DIR}:${DOCKER_VOLUME_OPTIONS}"
  # Provide env variables because:
  #  - there is backward compatibility case with manual doing docker exec
  #  into container and user of make.
  #  - TF Jenkins CI use non-bind folder for sources
  start_sandbox_cmd="mysudo docker run --network host --privileged --detach \
    --name $DEVENV_CONTAINER_NAME \
    -w /root \
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
    echo "$DEVENV_CONTAINER_NAME already running."
  else
    echo "$(mysudo docker start $DEVENV_CONTAINER_NAME) started."
  fi
fi

if [[ "$stage" == @(none|frozen) ]] ; then
  echo "INFO: don't run any stages"
  exit 0
fi

echo "run stage(s) ${stage:-${default_stages[@]}} with target ${target:-all}"
mysudo docker exec -i $DEVENV_CONTAINER_NAME "${DEV_ENV_ROOT}/container/run.sh" $stage $target
result=${PIPESTATUS[0]}

if [[ "$BIND_CONTRAIL_DIR" != 'false' ]] ; then
  # do chown for sources that were cloned with root inside container
  if ! mysudo chown -R $(id -u):$(id -g) $CONTRAIL_DIR ; then
    echo "WARNING: owner for sources folder was not changed correctly."
  fi
fi

if [[ $result == 0 ]] ; then
  help
else
  echo
  echo 'ERROR: There were failures. See logs for details.'
fi

exit $result
