#!/bin/bash

WORK_DIR="${HOME}/work"
CONTRAIL_DIR="${HOME}/contrail"
STAGES_DIR="${WORK_DIR}/.stages"

# Folders and artifacts which have to be symlinked in order to separate them from sources

declare -a work_folders=(build BUILDROOT BUILD RPMS SOURCES SRPMS SRPMSBUILD .sconf_temp  SPECS .stages)
declare -a work_files=(.sconsign.dblite)

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
    export src_volume_name=ContrailSources
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

function prepare_infra()
{
  if [[ -e /input/tf-developer-sandbox.env ]] ; then
      echo "INFO: source env from /input/tf-developer-sandbox.env"
      set -o allexport
      source /input/tf-developer-sandbox.env
      set +o allexport
  fi

  [ -n "$DEBUG" ] && set -x

  set -eo pipefail

  declare -a all_stages=(fetch configure compile package test freeze)
  declare -a default_stages=(fetch configure)
  declare -a build_stages=(fetch configure compile package)

  # Folders and artifacts which have to be symlinked in order to separate them from sources

  declare -a work_folders=(build BUILDROOT BUILD RPMS SOURCES SRPMS SRPMSBUILD .sconf_temp  SPECS .stages)
  declare -a work_files=(.sconsign.dblite)

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

  # Workaround for symlinked RPMS - rename of repodata to .oldata in createrepo utility fails otherwise
  rm -rf $WORK_DIR/RPMS/repodata
}