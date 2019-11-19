#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common.sh
source ${scriptdir}/functions.sh

CONTRAIL_DEPLOY_REGISTRY=${CONTRAIL_DEPLOY_REGISTRY-1}
[[ "$CONTRAIL_DEPLOY_REGISTRY" != 1 ]] && { echo "INFO: Docker registry deployment skipped" && exit ; }

ensure_root

echo
echo '[setup docker registry]'
if ! is_container_created "$REGISTRY_CONTAINER_NAME"; then
    ensure_port_free $REGISTRY_PORT
    docker run --name "$REGISTRY_CONTAINER_NAME" \
      -d -p $REGISTRY_PORT:5000 \
      registry:2 >/dev/null
    echo "INFO: $REGISTRY_CONTAINER_NAME created"
else
  if is_container_up "$REGISTRY_CONTAINER_NAME"; then
    echo "INFO: $REGISTRY_CONTAINER_NAME already running."
  else
    ensure_port_free $REGISTRY_PORT
    echo "INFO: $(docker start $REGISTRY_CONTAINER_NAME) started"
  fi
fi
