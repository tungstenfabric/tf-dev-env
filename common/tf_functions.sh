#!/bin/bash

# Classification of TF projects dealing with containers.
# TODO: use vnc/default.xml for this information later (loaded to .repo/manifest.xml)
deployers_projects=("tf-charms" "tf-helm-deployer" "contrail-ansible-deployer" \
  "contrail-kolla-ansible" "contrail-tripleo-heat-templates" "contrail-container-builder" "openshift-ansible")
containers_projects=("contrail-container-builder")
tests_projects=("contrail-test")

changed_projects=()
changed_containers_projects=()
changed_deployers_projects=()
changed_tests_projects=()
changed_product_projects=()

# Check patchset and fill changed_projects
function patches_exist() {
  if [[ -e ${DEVENV_INPUT}/${DEVENV_PATCHSETS} ]] ; then
    changed_projects=()
    changed_containers_projects=()
    changed_deployers_projects=()
    changed_tests_projects=()
    changed_product_projects=()
    projects=$(jq '.[].project' "${DEVENV_INPUT}/${DEVENV_PATCHSETS}")
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