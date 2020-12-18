#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../common/common.sh"
source_env

TARGET=${1:-}
export JOBS=${JOBS:-$(nproc)}

scriptdir=$(realpath $(dirname "$0"))

if [[ -n "$CONTRAIL_CONFIG_DIR" && -d "$CONTRAIL_CONFIG_DIR" && -n "$(ls ${CONTRAIL_CONFIG_DIR}/)" ]]; then
  cp -rf ${CONTRAIL_CONFIG_DIR}/* /
fi

if [[ "$TARGET" == 'ui' ]]; then
  echo "INFO: Running web ui tests"
  $scriptdir/webui_ut/run-tests.sh
elif [[ "$TARGET" == 'tox' ]]; then
  $scriptdir/tox/run-tests.sh
else
  echo "INFO: Running controller tests"
  $scriptdir/controller_ut/run-tests.sh $TARGET
fi
