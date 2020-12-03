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

cd $HOME/contrail

project=$(echo $GERRIT_PROJECT | cut -d '/' -f 2)
echo "INFO: short project name: $project"
path=$(./repo list -f -r $project | awk '{print $1}')
echo "INFO: project path: $path"

logs_path="/output/logs"
mkdir -p "$logs_path"
mkdir -p $path/.tox/$target_set/log

echo "read all symlink before"
ls -lR / | grep ^l
echo "for test 00"
ls $logs_path -la
echo "for test 01"
sudo ls "$path/.tox" -la
echo "for test 019"
ls "$path/.tox" -la
echo "for test 02"
ls "/tmp/.tox" -la
echo "for test 03"
ls $logs_path/ -la
echo "for test 03"

res=0
pushd $path
if [ ! -e tox.ini ]; then
  echo "WARNING: tox.ini is absent. Skipping tests."
  exit 0
fi

tox -e $target_set || res=1
popd

echo "read all symlink after"
ls -lR / | grep ^l
echo "for test 10"
ls $logs_path -la
echo "for test 11"
sudo ls $path/.tox -la
echo "for test 119"
ls $path/.tox -la
echo "for test 12"
ls /tmp/.tox -la
echo "for test 13"
ls /tmp/.tox/$target_set -la
echo "for test 14"
ls /tmp/.tox/$target_set/log -la
echo "for test 15"

# gather log files
sudo cp -R $path/.tox/$target_set/log/ $logs_path/ || /bin/true

echo "for test 20"
ls $logs_path -la
echo "for test 21"


# gzip .log files - they consume several Gb unpacked
pushd $logs_path
time find $(pwd) -name '*.log' | xargs gzip
popd

if [[ "$res" != '0' ]]; then
  echo "ERROR: some UT failed"
fi
exit $res
