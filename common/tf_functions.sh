#!/bin/bash

WORK_DIR="${HOME}/work"
STAGES_DIR="${WORK_DIR}/.stages"

# Folders and artifacts which have to be symlinked in order to separate them from sources

declare -a work_folders=(build BUILDROOT BUILD RPMS SOURCES SRPMS SRPMSBUILD .sconf_temp  SPECS .stages)
declare -a work_files=(.sconsign.dblite)

function create_env_file() {
  # exports 'src_volume_name' as return result
  local tf_container_env_file=$1
  cat <<EOF > $tf_container_env_file
export DEBUG=${DEBUG}
export DEBUGINFO=${DEBUGINFO}
export LINUX_DISTR=${LINUX_DISTR}
export LINUX_DISTR_VER=${LINUX_DISTR_VER}
export CONTRAIL_DEV_ENV=/${DEVENV_USER}/tf-dev-env
export DEVENV_TAG=$DEVENV_TAG
export CONTRAIL_BUILD_FROM_SOURCE=${CONTRAIL_BUILD_FROM_SOURCE}
export OPENSTACK_VERSIONS=${OPENSTACK_VERSIONS}
export SITE_MIRROR=${SITE_MIRROR}
export CONTRAIL_KEEP_LOG_FILES=${CONTRAIL_KEEP_LOG_FILES}
export CONTRAIL_BRANCH=${CONTRAIL_BRANCH}
export CONTRAIL_FETCH_REPO=${CONTRAIL_FETCH_REPO}
export CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG}
export CONTRAIL_REPOSITORY=http://localhost:${RPM_REPO_PORT}
export CONTRAIL_REGISTRY=${CONTAINER_REGISTRY}
export VENDOR_NAME=$VENDOR_NAME
export VENDOR_DOMAIN=$VENDOR_DOMAIN
EOF
  if [[ -n "$CONTRAIL_BUILD_FROM_SOURCE" && "$BIND_CONTRAIL_DIR" == 'false' ]] ; then
    export src_volume_name=ContrailSources
    echo "export CONTRAIL_SOURCE=${src_volume_name}" >> $tf_container_env_file
  else
    echo "export CONTRAIL_SOURCE=${CONTRAIL_DIR}" >> $tf_container_env_file
  fi
  if [[ -n "${GENERAL_EXTRA_RPMS+x}" ]] ; then
    echo "export GENERAL_EXTRA_RPMS=${GENERAL_EXTRA_RPMS}" >> $tf_container_env_file
  fi
  if [[ -n "${BASE_EXTRA_RPMS+x}" ]] ; then
    echo "export BASE_EXTRA_RPMS=${BASE_EXTRA_RPMS}" >> $tf_container_env_file
  fi
  if [[ -n "${RHEL_HOST_REPOS+x}" ]] ; then
    echo "export RHEL_HOST_REPOS=${RHEL_HOST_REPOS}" >> $tf_container_env_file
  fi

  if [[ -d "${scriptdir}/config" ]]; then
    echo "export CONTRAIL_CONFIG_DIR=${CONTRAIL_CONFIG_DIR:-'/config'}" >> $tf_container_env_file
  fi

  # code review system options
  if [[ -n "$GERRIT_URL" ]]; then
    echo "export GERRIT_URL=${GERRIT_URL}" >> $tf_container_env_file
  fi
  if [[ -n "$GERRIT_BRANCH" ]]; then
    echo "export GERRIT_BRANCH=${GERRIT_BRANCH}" >> $tf_container_env_file
  fi
}

function prepare_infra()
{
  if [[ -e /input/tf-developer-sandbox.env ]] ; then
    echo "INFO: source env from /input/tf-developer-sandbox.env"
    source /input/tf-developer-sandbox.env
  fi

  cd $CONTRAIL_DEV_ENV
  if [[ -e common.env ]] ; then
    echo "INFO: source env from common.env"
    set -o allexport
    source common.env
    set +o allexport
  fi

  echo "INFO: create symlinks to work directories with artifacts  $(date)"
  mkdir -p $HOME/work
  for folder in ${work_folders[@]} ; do
    [[ -e $WORK_DIR/$folder ]] || mkdir $WORK_DIR/$folder
    [[ -e $CONTRAIL_DIR/$folder ]] || ln -s $WORK_DIR/$folder $CONTRAIL_DIR/$folder 
  done
  for file in ${work_files[@]} ; do
    touch $WORK_DIR/$file
    [[ -e $CONTRAIL_DIR/$file ]] || ln -s $WORK_DIR/$file $CONTRAIL_DIR/$file
  done
}
