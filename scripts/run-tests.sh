#!/bin/bash -e

TARGET=${1:-}
export JOBS=${JOBS:-$(nproc)}

scriptdir=$(realpath $(dirname "$0"))

if [[ "$TARGET" == 'ui' ]]; then
  echo "INFO: Running web ui tests"
elif [[ "$TARGET" == 'vcenter' ]]; then
  echo "INFO: Running vcenter tests"
else
  echo "INFO: Running controller tests"
  $scriptdir/controller_ut/run-tests.sh $TARGET
fi
