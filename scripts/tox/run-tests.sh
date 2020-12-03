#!/bin/bash -x

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

echo "HOME is $HOME"
echo "GERRIT_PROJECT is $GERRIT_PROJECT"

cd $HOME/contrail

project=$(echo $GERRIT_PROJECT | cut -d '/' -f 2)
echo "INFO: short project name: $project"
echo "my test 01"
echo "$(./repo list -f -r $project)"
echo "my test 02"
path=$(./repo list -f -r $project | awk '{print $1}')
echo "INFO: old project path: $path"
path="/root/contrail/contrail-container-builder"
echo "INFO: new project path: $path"
echo "my test 03"
ls "/root/contrail/contrail-container-builder" -la
echo "my test 04"
ls "/root/contrail/tf-container-builder" -la
echo "my test 05"

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
