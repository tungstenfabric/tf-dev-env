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

function setup_httpd() {
  RPM_REPO_PORT='6667'

  mkdir -p $HOME/contrail/RPMS
  sudo mkdir -p /run/httpd # For some reason it's not created automatically

  sudo sed -i "s/Listen 80/Listen $RPM_REPO_PORT/" /etc/httpd/conf/httpd.conf
  sudo sed -i "s/\/var\/www\/html\"/\/var\/www\/html\/repo\"/" /etc/httpd/conf/httpd.conf
  sudo ln -s $HOME/contrail/RPMS /var/www/html/repo

  # The following is a workaround for when tf-dev-env is run as root (which shouldn't usually happen)
  sudo chmod 755 -R /var/www/html/repo
  sudo chmod 755 /root

  sudo /usr/sbin/httpd
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
CONTAINER_REGISTRY=\${CONTAINER_REGISTRY:-${CONTAINER_REGISTRY}}
RPM_REPO_IP='localhost'
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

function install_prerequisites_centos() {
  local pkgs=""
  which lsof || pkgs+=" lsof"
  which python || pkgs+=" python"
  if [ -n "$pkgs" ] ; then
    mysudo yum install -y $pkgs
  fi
}

function install_prerequisites_rhel() {
  install_prerequisites_centos
}

function install_prerequisites_ubuntu() {
  local pkgs=""
  which lsof || pkgs+=" lsof"
  which python || pkgs+=" python-minimal"
  if [ -n "$pkgs" ] ; then
    DEBIAN_FRONTEND=noninteractive
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

function create_env_file() {
  # exports 'src_volume_name' as return result
  local tf_container_env_file=$1
  cat <<EOF > $tf_container_env_file
DEBUG=${DEBUG}
DEBUGINFO=${DEBUGINFO}
LINUX_DISTR=${LINUX_DISTR}
CONTRAIL_DEV_ENV=/${DEVENV_USER}/tf-dev-env
DEVENV_TAG=$DEVENV_TAG
CONTRAIL_BUILD_FROM_SOURCE=${CONTRAIL_BUILD_FROM_SOURCE}
OPENSTACK_VERSIONS=${OPENSTACK_VERSIONS}
SITE_MIRROR=${SITE_MIRROR}
CONTRAIL_KEEP_LOG_FILES=${CONTRAIL_KEEP_LOG_FILES}
CONTRAIL_BRANCH=${CONTRAIL_BRANCH}
CONTRAIL_FETCH_REPO=${CONTRAIL_FETCH_REPO}
CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG}
CONTRAIL_REPOSITORY=http://localhost:${RPM_REPO_PORT}
CONTRAIL_REGISTRY=${CONTAINER_REGISTRY}
VENDOR_NAME=$VENDOR_NAME
VENDOR_DOMAIN=$VENDOR_DOMAIN
EOF
  if [[ -n "$CONTRAIL_BUILD_FROM_SOURCE" && "$BIND_CONTRAIL_DIR" == 'false' ]] ; then
    src_volume_name=ContrailSources
    echo "CONTRAIL_SOURCE=${src_volume_name}" >> $tf_container_env_file  
  else
    echo "CONTRAIL_SOURCE=${CONTRAIL_DIR}" >> $tf_container_env_file
  fi
  if [[ -n "${GENERAL_EXTRA_RPMS+x}" ]] ; then
    echo "GENERAL_EXTRA_RPMS=${GENERAL_EXTRA_RPMS}" >> $tf_container_env_file
  fi
  if [[ -n "${BASE_EXTRA_RPMS+x}" ]] ; then
    echo "BASE_EXTRA_RPMS=${BASE_EXTRA_RPMS}" >> $tf_container_env_file
  fi
  if [[ -n "${RHEL_HOST_REPOS+x}" ]] ; then
    echo "RHEL_HOST_REPOS=${RHEL_HOST_REPOS}" >> $tf_container_env_file
  fi

  if [[ -d "${scriptdir}/config" ]]; then
    echo "CONTRAIL_CONFIG_DIR=${CONTRAIL_CONFIG_DIR:-'/config'}" >> $tf_container_env_file
  fi

  # code review system options
  if [[ -n "$GERRIT_URL" ]]; then 
    echo "GERRIT_URL=${GERRIT_URL}" >> $tf_container_env_file
  fi
  if [[ -n "$GERRIT_BRANCH" ]]; then
    echo "GERRIT_BRANCH=${GERRIT_BRANCH}" >> $tf_container_env_file
  fi
}
