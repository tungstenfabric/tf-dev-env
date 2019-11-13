#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common/common.sh
source ${scriptdir}/common/functions.sh

if is_container_up "$TF_DEVENV_CONTAINER_NAME"; then
  docker logs -f $TF_DEVENV_CONTAINER_NAME
fi

exit_code=$(docker inspect $TF_DEVENV_CONTAINER_NAME --format='{{.State.ExitCode}}')
if [[ $exit_code != 0 ]] ; then
  echo ERROR: Build failed with exit code $exit_code
  docker logs --tail 1000 $TF_DEVENV_CONTAINER_NAME
  exit $exit_code
fi

echo Build succeeded
