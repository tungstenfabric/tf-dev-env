#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common.sh
source ${scriptdir}/functions.sh

CONTRAIL_SETUP_DOCKER=${CONTRAIL_SETUP_DOCKER:-1}
[[ "$CONTRAIL_SETUP_DOCKER" != 1 ]] && { echo "INFO: setup docker skipped" && exit ; }

registry_ip=$(sudo -E ${scriptdir}/setup_docker_root.sh | awk '/^REGISTRY_IP: .*/{print($2)}' | head -n 1)
export REGISTRY_IP=${registry_ip}
save_tf_devenv_profile
