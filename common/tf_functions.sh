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
export BUILD_MODE=${BUILD_MODE}
export DEV_ENV_ROOT=/root/tf-dev-env
export DEVENV_TAG=$DEVENV_TAG
export CONTRAIL_BUILD_FROM_SOURCE=${CONTRAIL_BUILD_FROM_SOURCE}
export SITE_MIRROR=${SITE_MIRROR}
export CONTRAIL_KEEP_LOG_FILES=${CONTRAIL_KEEP_LOG_FILES}
export CONTRAIL_BRANCH=${CONTRAIL_BRANCH}
export CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG}
export CONTRAIL_REPOSITORY=http://localhost:${RPM_REPO_PORT}
export CONTRAIL_REGISTRY=${CONTAINER_REGISTRY}
export VENDOR_NAME=$VENDOR_NAME
export VENDOR_DOMAIN=$VENDOR_DOMAIN
export MULTI_KERNEL_BUILD=$MULTI_KERNEL_BUILD
export KERNEL_REPOSITORIES_RHEL8="$KERNEL_REPOSITORIES_RHEL8"
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
}

# Classification of TF projects dealing with containers.
# TODO: use vnc/default.xml for this information later (loaded to .repo/manifest.xml)
deployers_projects=("tf-charms" "tf-helm-deployer" "tf-ansible-deployer" \
  "tf-kolla-ansible" "tf-tripleo-heat-templates" "tf-container-builder" "tf-openshift-ansible")
containers_projects=("tf-container-builder")
tests_projects=("tf-test" "tf-deployment-test")
vrouter_dpdk=("tf-dpdk")

changed_projects=()
changed_containers_projects=()
changed_deployers_projects=()
changed_tests_projects=()
changed_product_projects=()

# Check patchset and fill changed_projects
function patches_exist() {
  if [[ -e "/input/patchsets-info.json" ]] ; then
    changed_projects=()
    changed_containers_projects=()
    changed_deployers_projects=()
    changed_tests_projects=()
    changed_product_projects=()
    projects=$(jq '.[].project' "/input/patchsets-info.json")
    for project in ${projects[@]}; do
      project=$(echo $project | cut -f 2 -d "/" | tr -d '"')
      changed_projects+=$project
      non_container_project=false
      if [[ ${containers_projects[@]} =~ $project ]] ; then
        changed_containers_projects+=$project
        non_container_project=true
      fi
      if [[ ${deployers_projects[@]} =~ $project ]] ; then
        changed_deployers_projects+=$project
        non_container_project=true
      fi
      if [[ ${tests_projects[@]} =~ $project ]] ; then
        changed_tests_projects+=$project
        non_container_project=true
      fi
      if $non_container_project ; then
        changed_product_projects+=$project
      fi
    done
    return 0
  fi
  return 1
}
