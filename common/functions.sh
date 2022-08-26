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
    return 1
  fi
}

function ensure_port_free() {
  local port=$1
  if mysudo lsof -Pn -sTCP:LISTEN -i :$port ; then
    echo "ERROR: Port $port is already opened by another process"
    return 1
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
FROZEN_TAG=\${FROZEN_TAG:-${FROZEN_TAG}}
FROZEN_REGISTRY=\${FROZEN_REGISTRY:-${FROZEN_REGISTRY}}
CONTAINER_REGISTRY=\${CONTAINER_REGISTRY:-${CONTAINER_REGISTRY}}
RPM_REPO_IP='localhost'
RPM_REPO_PORT=\${RPM_REPO_PORT:-${RPM_REPO_PORT}}
BUILD_MODE=\${BUILD_MODE:-${BUILD_MODE}}

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
    source "$TF_DEVENV_PROFILE"
  else
    echo
    echo '[there is no tf devenv configuration to load]'
  fi
}

function install_prerequisites_centos() {
  local pkgs="$1"
  which lsof || pkgs+=" lsof"
  which python3 || pkgs+=" python3"
  if [ -n "$pkgs" ] ; then
    mysudo yum install -y $pkgs
  fi
  which python || mysudo alternatives --verbose --set python /usr/bin/python3
  which pip || mysudo alternatives --verbose --install /usr/bin/pip pip $(which pip3) 100
}

function install_prerequisites_rhel() {
  local pkgs=""
  if [[ ${DISTRO}_${DISTRO_VER} == 'rhel_8.2' || ${DISTRO}_${DISTRO_VER} == 'rhel_8.4' ]]; then
    pkgs="jq"
  fi
  install_prerequisites_centos "$pkgs"
}

function install_prerequisites_ubuntu() {
  local pkgs=""
  which lsof || pkgs+=" lsof"
  which python || pkgs+=" python-minimal"
  if [ -n "$pkgs" ] ; then
    export DEBIAN_FRONTEND=noninteractive
    mysudo -E apt-get install -y $pkgs
  fi
}

function install_prerequisites_macosx() {
  local pkgs=""
  which lsof || pkgs+=" lsof"
  which python || pkgs+=" python"
  if [ -n "$pkgs" ] ; then
    brew install $pkgs
  fi
}

function install_prerequisites_arch() {
    local pkgs=""
    which lsof || pkgs+=" lsof"
    which python3 || pkgs+=" python3"
    if [ -n "$pkgs" ] ; then
        pacman -S $pkgs
    fi
}
