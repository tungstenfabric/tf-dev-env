#!/bin/bash

[ -n "$DEBUG" ] && set -x
set -o nounset
set -o errexit

# working environment 
export WORKSPACE=${WORKSPACE:-$(pwd)}
export TF_CONFIG_DIR="${WORKSPACE}/.tf"
export TF_DEVENV_PROFILE="${TF_CONFIG_DIR}/dev.env"

[ -e "$TF_DEVENV_PROFILE" ] && source "$TF_DEVENV_PROFILE"

# determined variables
export DISTRO=$(cat /etc/*release | egrep '^ID=' | awk -F= '{print $2}' | tr -d \")

# build options
export AUTOBUILD=${AUTOBUILD:-0}
export BUILD_DEV_ENV=${BUILD_DEV_ENV:-0}
export BUILD_DEV_ENV_ON_PULL_FAIL=${BUILD_DEV_ENV_ON_PULL_FAIL:-1}
export BUILD_TEST_CONTAINERS=${BUILD_TEST_CONTAINERS:-0}
export CONTRAIL_BUILD_FROM_SOURCE=${CONTRAIL_BUILD_FROM_SOURCE:-}

# working build directories
export SRC_ROOT=${SRC_ROOT:-}
export CONTRAIL_DIR="${SRC_ROOT:-${WORKSPACE}/contrail}"

# build environment preparation options
export CONTRAIL_SYNC_REPOS=${CONTRAIL_SYNC_REPOS:-1}
export CONTRAIL_DEPLOY_REGISTRY=${CONTRAIL_DEPLOY_REGISTRY:-1}
export CONTRAIL_DEPLOY_RPM_REPO=${CONTRAIL_DEPLOY_RPM_REPO:-1}
export REGISTRY_PORT=${REGISTRY_PORT:-5000}
export REGISTRY_IP=${REGISTRY_IP:-'localhost'}
export RPM_REPO_IP=${RPM_REPO_IP:-'localhost'}
export REGISTRY_CONTAINER_NAME=${REGISTRY_CONTAINER_NAME:-"tf-dev-env-registry"}
export RPM_CONTAINER_NAME=${RPM_CONTAINER_NAME:-"tf-dev-env-rpm-repo"}
export TF_DEVENV_CONTAINER_NAME=${TF_DEVENV_CONTAINER_NAME:-"tf-developer-sandbox"}

# tf-dev-env sandbox parameters
export IMAGE=${IMAGE:-"tungstenfabric/developer-sandbox"}
export DEVENVTAG=${DEVENVTAG:-"latest"}
export DEVENV_IMAGE=${IMAGE}:${DEVENVTAG}

# RHEL specific build options
export ENABLE_RHSM_REPOS=${ENABLE_RHSM_REPOS:-1}

# versions info
export CONTRAIL_VERSION=${CONTRAIL_VERSION:-'dev'}
export VENDOR_NAME="Tungsten Fabric"
export VENDOR_DOMAIN="tungsten.io"
