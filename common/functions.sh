#!/bin/bash

function is_container_created() {
  local container=$1
  if ! mysudo docker ps -a --format '{{ .Names }}' | grep -x "$container" > /dev/null 2>&1 ; then
    return 1
  fi
}

function is_container_up() {
  local container=$1
  if ! mysudo docker inspect --format '{{ .State.Status }}' $container | grep -q "running" > /dev/null 2>&1 ; then
    return 1
  fi
}

function ensure_root() {
  local me=$(whoami)
  if [ "$me" != 'root' ] ; then
    echo "ERROR: this script requires root:"
    echo "       mysudo -E $0"
    exit 1;
  fi
}

function ensure_port_free() {
  local port=$1
  if mysudo lsof -Pn -sTCP:LISTEN -i :$port ; then
    echo "ERROR: Port $port is already opened by another process"
    exit 1
  fi
}

function mysudo() {
    if [[ $DISTRO == "macosx" ]]; then
	"$@"
    else
	sudo "$@"
    fi
}

function save_tf_devenv_profile() {
  local file=${1:-$TF_DEVENV_PROFILE}
  echo
  echo '[update tf devenv configuration]'
  mkdir -p "$(dirname $file)"
  cat <<EOF > $file
# dev env options
CONTRAIL_CONTAINER_TAG=\${CONTRAIL_CONTAINER_TAG:-${CONTRAIL_CONTAINER_TAG}}
REGISTRY_IP=\${REGISTRY_IP:-${REGISTRY_IP}}
REGISTRY_PORT=\${REGISTRY_PORT:-${REGISTRY_PORT}}
RPM_REPO_IP=\${RPM_REPO_IP:-${RPM_REPO_IP}}
[ -z "$RPM_REPO_IP" ] && RPM_REPO_IP=$REGISTRY_IP
RPM_REPO_PORT=\${RPM_REPO_PORT:-${RPM_REPO_PORT}}

# others
VENDOR_NAME="\${VENDOR_NAME:-${VENDOR_NAME}}"
VENDOR_DOMAIN="\${VENDOR_DOMAIN:-${VENDOR_DOMAIN}}"
EOF
  echo "tf setup profile $file"
  cat ${file}
}

function load_tf_devenv_profile() {
  if [ -e "$TF_DEVENV_PROFILE" ] ; then
    echo
    echo '[load tf devenv configuration]'
    set -o allexport
    source "$TF_DEVENV_PROFILE"
    set +o allexport
  else
    echo
    echo '[there is no tf devenv configuration to load]'
  fi   
}
