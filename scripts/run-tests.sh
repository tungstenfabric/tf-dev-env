#!/bin/bash -e

TARGET=${1:-}
export JOBS=${JOBS:-$(nproc)}

scriptdir=$(realpath $(dirname "$0"))

if [[ "$TARGET" == 'ui' ]]; then
  echo "INFO: Running web ui tests"
  $scriptdir/webui_ut/run-tests.sh
elif [[ "$TARGET" == 'vcenter' ]]; then
  echo "INFO: Running vcenter tests"
elif [[ "$TARGET" == 'containers' ]]; then
  echo "INFO: Running containers tests"
  $scriptdir/container_ut/run-tests.sh
else
  echo "INFO: Running controller tests"
  $scriptdir/controller_ut/run-tests.sh $TARGET
fi
