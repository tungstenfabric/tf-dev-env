#!/bin/bash

declare -a default_stages=(fetch configure)

[ -n "$DEBUG" ] && set -x
set -o errexit

# extract DEBUGINFO
# Should be set to TRUE to produce debuginfo
export DEBUGINFO=${DEBUGINFO:-FALSE}

# working environment
# WORKSPACE and two next vars are applicable only outside of sandbox container - on host.
export WORKSPACE=${WORKSPACE:-$(pwd)}
export TF_CONFIG_DIR=${TF_CONFIG_DIR:-"${HOME}/.tf"}
export TF_DEVENV_PROFILE="${TF_CONFIG_DIR}/dev.env"

# Build mode allows skipping stages or targets after freeze if patchset is present - values full, fast
export BUILD_MODE=${BUILD_MODE:-"fast"}

[ -e "$TF_DEVENV_PROFILE" ] && source "$TF_DEVENV_PROFILE"

# determined variables
if [[ "$OSTYPE" == "linux-gnu" ]]; then
  export DISTRO=$(cat /etc/*release | egrep '^ID=' | awk -F= '{print $2}' | tr -d \")
elif [[ "$OSTYPE" == "darwin"* ]]; then
  export DISTRO="macosx"
else
  echo "Unsupported platform."
  exit 1
fi

# working build directories
# CONTRAIL_DIR is useful only outside of sandbox container
if [ -z "${CONTRAIL_DIR+x}" ] ; then
  # not defined => use default
  CONTRAIL_DIR=${WORKSPACE}/contrail
elif [ -z "$CONTRAIL_DIR" ] ; then
  # defined empty => dont bind contrail dir to host: tf jenkins
  CONTRAIL_DIR=${WORKSPACE}/contrail
  BIND_CONTRAIL_DIR=false
fi
export CONTRAIL_DIR

# build environment preparation options
export CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-"localhost:5001"}
# check if container registry is in ip:port format
if [[ $CONTAINER_REGISTRY == *":"* ]]; then
  export REGISTRY_IP=$(echo $CONTAINER_REGISTRY | cut -f 1 -d ':')
  export REGISTRY_PORT=$(echo $CONTAINER_REGISTRY | cut -f 2 -d ':')
else
  # no need to setup local registry while using docker hub
  export CONTRAIL_DEPLOY_REGISTRY=0
  # skip updating insecure registry for docker
  export CONTRAIL_SKIP_INSECURE_REGISTRY=1
fi
# FROZEN_REGISTRY is the source container registry where existing containers reside to skip rebuilding unchanged ones
# Also it is the registry to take frozen tf-dev-sandbox container from
export FROZEN_REGISTRY=${FROZEN_REGISTRY:-"tf-nexus.progmaticlab.com:5001"}

# Gerrit URL is used when patchsets-info.json is provided
export GERRIT_URL=https://review.opencontrail.org/

export RPM_REPO_IP='localhost'
export RPM_REPO_PORT='6667'
export REGISTRY_CONTAINER_NAME=${REGISTRY_CONTAINER_NAME:-"tf-dev-env-registry"}
export DEVENV_CONTAINER_NAME=${DEVENV_CONTAINER_NAME:-"tf-dev-sandbox"}
export CONTRAIL_PARALLEL_BUILD=${CONTRAIL_PARALLEL_BUILD:-true}

# tf-dev-env sandbox parameters
export DEVENV_IMAGE_NAME=${DEVENV_IMAGE_NAME:-"tf-dev-sandbox"}
export DEVENV_TAG=${DEVENV_TAG:-"latest"}
export DEVENV_PUSH_TAG=${DEVENV_PUSH_TAG:-"frozen"}
export DEVENV_IMAGE=${DEVENV_IMAGE:-"${DEVENV_IMAGE_NAME}:${DEVENV_TAG}"}

# build options
export MULTI_KERNEL_BUILD=${MULTI_KERNEL_BUILD:-"false"}

# RHEL specific build options
export ENABLE_RHSM_REPOS=${ENABLE_RHSM_REPOS:-'false'}

# versions info
export CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-'dev'}
# tag for existing prebuilt containers reflecting current merged code in gerrit.
# It's determined automatically taken from http://tf-nexus.progmaticlab.com:8082/frozen/tag during fetch stage
export FROZEN_TAG=""
# note: there is spaces available in names below
export VENDOR_NAME=${VENDOR_NAME:-"TungstenFabric"}
export VENDOR_DOMAIN=${VENDOR_DOMAIN:-"tungsten.io"}

# Contrail repo branches options
export CONTRAIL_BRANCH=${CONTRAIL_BRANCH:-${GERRIT_BRANCH:-'master'}}

# Docker options
if [ -z "${DOCKER_VOLUME_OPTIONS}" ] ; then
  export DOCKER_VOLUME_OPTIONS="z"
  if [[ $DISTRO == "macosx" ]]; then
    # Performance issue with osxfs, this option is making the
    # writes async from the container to the host. This means a
    # difference can happen from the host POV, but that should not
    # be an issue since we are not expecting anything to update
    # the source code. Based on test this option increase the perf
    # of about 10% but it still quite slow comparativly to a host
    # using GNU/Linux.
    DOCKER_VOLUME_OPTIONS+=",delegated"
  fi
fi

function source_env()
{
  tf_env="${CONTRAIL_INPUT_DIR:-/input}/tf-developer-sandbox.env"
  if [[ -e "$tf_env" ]] ; then
    echo "INFO: source env from $tf_env"
    source "$tf_env"
  fi

  common_env="$DEV_ENV_ROOT/common.env" 
  if [[ -e "$common_env" ]] ; then
    echo "INFO: source env from $common_env"
    set -o allexport
    source "$common_env"
    set +o allexport
  fi
}
