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
set -m
export DEBUG=${DEBUG}
export DEBUGINFO=${DEBUGINFO}
export LINUX_DISTR=${LINUX_DISTR}
export LINUX_DISTR_VER=${LINUX_DISTR_VER}
export BUILD_MODE=${BUILD_MODE}
export DEV_ENV_ROOT=/root/tf-dev-env
export DEVENV_TAG=$DEVENV_TAG
export SITE_MIRROR=${SITE_MIRROR}
export CONTRAIL_KEEP_LOG_FILES=${CONTRAIL_KEEP_LOG_FILES}
export CONTRAIL_BRANCH=${CONTRAIL_BRANCH}
export CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG}
export CONTRAIL_REPOSITORY=http://localhost:${RPM_REPO_PORT}
export CONTRAIL_REGISTRY=${CONTAINER_REGISTRY}
export CONTAINER_REGISTRY=${CONTAINER_REGISTRY}
export VENDOR_NAME=$VENDOR_NAME
export VENDOR_DOMAIN=$VENDOR_DOMAIN
export MULTI_KERNEL_BUILD=$MULTI_KERNEL_BUILD
export KERNEL_REPOSITORIES_RHEL8="$KERNEL_REPOSITORIES_RHEL8"
export CONTRAIL_SOURCE=${CONTRAIL_DIR}
export BUILDTAG=${CONTRAIL_CONTAINER_TAG//-/_}
export REPO_INIT_MANIFEST_URL=$REPO_INIT_MANIFEST_URL
export VNC_ORGANIZATION=$VNC_ORGANIZATION
EOF
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
  if [[ -n "$GERRIT_PROJECT" ]]; then
    echo "export GERRIT_PROJECT=${GERRIT_PROJECT}" >> $tf_container_env_file
  fi
}

function prepare_infra()
{
  echo "INFO: create symlinks to work directories with artifacts  $(date)"
  mkdir -p $HOME/work /root/contrail
  # /root/contrail will be defined later as REPODIR
  for folder in ${work_folders[@]} ; do
    [[ -e $WORK_DIR/$folder ]] || mkdir $WORK_DIR/$folder
    [[ -e /root/contrail/$folder ]] || ln -s $WORK_DIR/$folder /root/contrail/$folder
  done
  for file in ${work_files[@]} ; do
    touch $WORK_DIR/$file
    [[ -e /root/contrail/$file ]] || ln -s $WORK_DIR/$file /root/contrail/$file
  done
  # to re-read yum data before each run - mirror list or mirrors itself can be changed since previous run
  yum clean all
}

function get_current_container_tag()
{
  if curl -sI "http://tf-nexus.progmaticlab.com:8082/frozen/tag" | grep -q "HTTP/1.1 200 OK" ; then
    curl -s "http://tf-nexus.progmaticlab.com:8082/frozen/tag"
  fi
}

# Classification of TF projects dealing with containers.
# TODO: use vnc/default.xml for this information later (loaded to .repo/manifest.xml)
deployers_projects=("tf-charms" "tf-helm-deployer" "tf-ansible-deployer" "tf-operator" \
  "tf-kolla-ansible" "tf-tripleo-heat-templates" "tf-container-builder")
containers_projects=("tf-container-builder")
operator_projects=("tf-operator")
tests_projects=("tf-test" "tf-deployment-test")
vrouter_dpdk=("tf-dpdk")
infra_projects=("tf-jenkins" "tf-dev-env" "tf-devstack" "tf-dev-test")

changed_projects=()
changed_containers_projects=()
changed_deployers_projects=()
changed_operator_projects=()
changed_tests_projects=()
changed_product_projects=()
unchanged_containers=()

# Check patchset and fill changed_projects, also collect containers NOT to build
function patches_exist() {
  if [[ ! -e "/input/patchsets-info.json" ]] ; then
    return 1
  fi

  # First fetch existing containers list
  # TODO: detect protocol first
  frozen_containers=($(curl -fSs https://$FROZEN_REGISTRY/v2/_catalog | jq -r '.repositories | .[]'))
  # Next initialize projects lists and look for changes
  changed_projects=()
  changed_containers_projects=()
  changed_deployers_projects=()
  changed_operator_projects=()
  changed_tests_projects=()
  changed_product_projects=()
  projects=$(jq '.[].project' "/input/patchsets-info.json")
  for project in ${projects[@]}; do
    project=$(echo $project | cut -f 2 -d "/" | tr -d '"')
    changed_projects+=($project)
    non_container_project=true
    if [[ ${infra_projects[@]} =~ $project ]] ; then
      continue
    fi
    if [[ ${containers_projects[@]} =~ $project ]] ; then
      changed_containers_projects+=($project)
      non_container_project=false
    fi
    if [[ ${deployers_projects[@]} =~ $project ]] ; then
      changed_deployers_projects+=($project)
      non_container_project=false
    fi
    if [[ ${operator_projects[@]} =~ $project ]] ; then
      changed_operator_projects+=($project)
      non_container_project=false
    fi
    if [[ ${tests_projects[@]} =~ $project ]] ; then
      changed_tests_projects+=($project)
      non_container_project=false
    fi
    if $non_container_project ; then
      changed_product_projects+=($project)
      # No containers are reused in this case - all should be rebuilt
      frozen_containers=()
    fi
  done

  # Now scan through frozen containers and remove ones to rebuild
  for container in ${frozen_containers[@]}; do
    if [[ $container == *-test ]] ; then
      if [[ -z $changed_tests_projects ]] ; then
        unchanged_containers+=($container)
      fi
    elif [[ $container == *-src ]] ; then
      if [[ -z $changed_deployers_projects ]] ; then
        unchanged_containers+=($container)
      fi
    elif [[ $container == *-operator ]] ; then
      if [[ -z $changed_operator_projects ]] ; then
        unchanged_containers+=($container)
      fi
    else
      if [[ $container != *-sandbox ]] && [[ -z $changed_containers_projects ]] ; then
        unchanged_containers+=($container)
      fi
    fi
  done

  return 0
}
