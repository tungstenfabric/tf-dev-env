#!/bin/bash

TARGET=${1:-}
TARGET_TIMEOUT=${TARGET_TIMEOUT:-"120m"}

scriptdir=$(realpath $(dirname "$0"))

if [ ! -e /input/target_set ]; then
  echo "ERROR: /input/target_set must be present for tox tests"
  exit 1
fi
if [ -z "$GERRIT_PROJECT" ]; then
  echo "ERROR: GERRIT_PROJECT must be set for tox tests"
  exit 1
fi

target_set=$(cat /input/target_set)
echo "INFO: Running tox tests for project: $GERRIT_PROJECT, tox target: $TARGET_SET"

cd $PROJECT???

tox -e $TARGET_SET || res=1

logs_path="/output/logs"
mkdir -p "$logs_path"

# gather log files
cp -R $PROJECT???/.tox/$TARGET_SET/logs/ $logs_path/

# gzip .log files - they consume several Gb unpacked
pushd $logs_path
time find $(pwd) -name '*.log' | xargs gzip
popd

if [[ "$res" != '0' ]]; then
  echo "ERROR: some UT failed"
fi
exit $res
