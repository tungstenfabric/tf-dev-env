#!/bin/bash

function help() {
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

  # if tf-dev-env is running, explain how to use it
  if [[ -z "$(docker ps -q -f "name=${DEVENV_CONTAINER_NAME}$")" ]]; then
    echo
    return 0
  fi

  echo "For advanced usage You can now connect to the sandbox container by using:"
  if [[ $DISTRO != "macosx" ]]; then
    echo "  sudo docker exec -it $DEVENV_CONTAINER_NAME bash"
  else
    echo "  docker exec -it $DEVENV_CONTAINER_NAME bash"
  fi
  echo
}

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
    sudo --preserve-env "$@"
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
  local -a pkgs
  for pkg in lsof python "$@"; do
    which $pkg &>/dev/null || pkgs+=($pkg)
  done
  if [ -n "$pkgs" ] ; then
    mysudo yum install -y "${pkgs[@]}"
  fi
}

function install_prerequisites_dev_centos() {
  if ! grep -q 'CentOS-7' /etc/os-release 2>/dev/null; then
    die "Only CentOS 7 supported"
  fi

  # enable and start docker in case is was just installed
  systemctl enable docker
  systemctl start docker
  # disable selinux right now
  setenforce 0 || true
  # keep selinux disabled after reboot
  sed -i 's:^SELINUX=.*:SELINUX=disabled:' /etc/selinux/config
  # disable firewalld to avoid test execution problems
  systemctl disable firewalld || true
  systemctl stop firewalld || true
  # disable automatic updates to avoid breaking contrail rev-locked dependendencies
  if systemctl status packagekit &>/dev/null; then
    append_if_missing 'WritePreparedUpdates=false' /etc/PackageKit/PackageKit.conf
    systemctl restart packagekit &>/dev/null
  fi

  # runtime requirements
  install_prerequisites_centos || return 1
}

function install_prerequisites_rhel() {
  install_prerequisites_centos
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

function warn() {
  echo
  echo "WARNING: $*"
}

function die() {
  echo
  echo "ERROR: $*"
  exit 1
}

function append_if_missing() {
  line="$1"
  file="$2"
  grep -qF "$line" "$file" || echo "$line" >>"$file"
}
