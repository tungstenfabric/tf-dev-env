#!/bin/bash

function is_container_created() {
  local container=$1
  if ! docker ps -a --format '{{ .Names }}' | grep "$container" > /dev/null 2>&1 ; then
    return 1
  fi
}

function is_container_up() {
  local container=$1
  if ! docker inspect --format '{{ .State.Status }}' $container | grep -q "running" > /dev/null 2>&1 ; then
    return 1
  fi
}

function ensure_root() {
  local me=$(whoami)
  if [ "$me" != 'root' ] ; then
    echo "ERROR: this script requires root:"
    echo "       sudo -E $0"
    exit 1;
  fi
}

function ensure_port_free() {
  ensure_root
  local port=$1
  if lsof -Pn -sTCP:LISTEN -i :$port ; then
    echo "ERROR: Port $port is already opened by another process"
    exit 1
  fi
}

function save_tf_devenv_profile() {
  local file=${1:-$TF_DEVENV_PROFILE}
  echo
  echo '[update tf devenv configuration]'
  mkdir -p "$(dirname $file)"
  cat <<EOF > $file
# build process options
AUTOBUILD=$AUTOBUILD
BUILD_DEV_ENV=$BUILD_DEV_ENV
BUILD_DEV_ENV_ON_PULL_FAIL=$BUILD_DEV_ENV_ON_PULL_FAIL
BUILD_TEST_CONTAINERS=$BUILD_TEST_CONTAINERS
CONTRAIL_SYNC_REPOS=$CONTRAIL_SYNC_REPOS
CONTRAIL_DEPLOY_REGISTRY=$CONTRAIL_DEPLOY_REGISTRY
CONTRAIL_DEPLOY_RPM_REPO=$CONTRAIL_DEPLOY_RPM_REPO

# build env options
CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG}
REGISTRY_IP=${REGISTRY_IP}
REGISTRY_PORT=${REGISTRY_PORT}
RPM_REPO_IP=${RPM_REPO_IP}
RPM_REPO_PORT=${RPM_REPO_PORT}

# others
VENDOR_NAME="${VENDOR_NAME}"
VENDOR_DOMAIN="${VENDOR_DOMAIN}"
EOF
  echo "tf setup profile $file"
  cat ${file}
}

function load_tf_devenv_profile() {
  if [ -e "$TF_DEVENV_PROFILE" ] ; then
    echo
    echo '[load tf devenv configuration]'
    source "$TF_DEVENV_PROFILE"
  else
    echo
    echo '[there is no tf devenv configuration to load]'
  fi   
}
