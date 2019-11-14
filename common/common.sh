#!/bin/bash

[ -n "$DEBUG" ] && set -x
set -o errexit

# working environment 
export WORKSPACE=${WORKSPACE:-$(pwd)}
export TF_CONFIG_DIR="${WORKSPACE}/.tf"
export TF_DEVENV_PROFILE="${TF_CONFIG_DIR}/dev.env"

[ -e "$TF_DEVENV_PROFILE" ] && source "$TF_DEVENV_PROFILE"

# determined variables
export DISTRO=$(cat /etc/*release | egrep '^ID=' | awk -F= '{print $2}' | tr -d \")

# working build directories
export SRC_ROOT=${SRC_ROOT:-}
export CONTRAIL_DIR="${SRC_ROOT:-${WORKSPACE}/contrail}"

# build environment preparation options
export REGISTRY_PORT=${REGISTRY_PORT:-5000}
export REGISTRY_IP=${REGISTRY_IP:-'localhost'}
export RPM_REPO_IP=${RPM_REPO_IP:-}
export RPM_REPO_PORT=${RPM_REPO_PORT:-'6667'}
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
export CONTRAIL_CONTAINER_TAG=${CONTRAIL_CONTAINER_TAG:-'dev'}
export VENDOR_NAME="Tungsten Fabric"
export VENDOR_DOMAIN="tungsten.io"
