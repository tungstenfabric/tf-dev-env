#!/bin/bash

TARGET=${1:-}
TARGET_TIMEOUT=${TARGET_TIMEOUT:-"120m"}

scriptdir=$(realpath $(dirname "$0"))

if [ -z "$GERRIT_PROJECT" ]; then
  echo "ERROR: GERRIT_PROJECT must be set for tox tests"
  exit 1
fi

if [ ! -e /input/target_set ]; then
  echo "INFO: /input/target_set is absent - run all tox targets"
  target_set="ALL"
else
  target_set=$(cat /input/target_set)
fi

echo "INFO: Running tox tests for project: $GERRIT_PROJECT, tox target: $target_set"

cd $HOME/contrail

project=$(echo $GERRIT_PROJECT | cut -d '/' -f 2)
echo "INFO: short project name: $project"
path=$(./repo list -f -r $project | awk '{print $1}' | head -1)
echo "INFO: project path: $path"

res=0
pushd $path
if [ ! -e tox.ini ]; then
  echo "WARNING: tox.ini is absent. Skipping tests."
  exit 0
fi

tox -e $target_set || res=1
popd

logs_path="/output/logs"
mkdir -p "$logs_path"
# gather log files
cp -R $path/.tox/$target_set/log/ $logs_path/ || /bin/true

# gzip .log files - they consume several Gb unpacked
pushd $logs_path
time find $(pwd) -name '*.log' | xargs gzip
popd

if [[ "$res" != '0' ]]; then
  echo "ERROR: some UT failed"
fi
exit $res
