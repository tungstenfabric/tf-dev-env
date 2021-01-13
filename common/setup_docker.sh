#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common.sh
source ${scriptdir}/functions.sh

CONTRAIL_SETUP_DOCKER=${CONTRAIL_SETUP_DOCKER:-1}
[[ "$CONTRAIL_SETUP_DOCKER" != 1 ]] && { echo "INFO: setup docker skipped" && exit ; }
if [ $DISTRO == "macosx" ] ; then
  output=$(${scriptdir}/setup_docker_macosx.sh)
else
  output=$(sudo -E ${scriptdir}/setup_docker_root.sh)
fi
echo "$output"

export REGISTRY_IP=$(echo "$output" | awk '/^REGISTRY_IP: .*/{print($2)}' | head -n 1)
save_tf_devenv_profile
