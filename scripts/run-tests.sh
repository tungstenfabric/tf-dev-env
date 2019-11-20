#!/bin/bash -e

TARGET=${1:-}
JOBS=${JOBS:-1}

cd /root/contrail/
for test in $(jq -r ".[].scons_test_targets[]"  controller/ci_unittests.json| sort | uniq) ; do
  if [ ! -z "$TARGET" ] && [[ $test != *"$TARGET"* ]]
    then continue
  fi
echo "INFO: Starting unit tests for package " $test
python3 $scriptdir/run-tests.py -j $JOBS $test
done;

