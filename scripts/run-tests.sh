#!/bin/bash -e

TARGET=${1:-}
JOBS=${JOBS:-1}


scriptdir=$(realpath $(dirname "$0"))
cd /root/contrail/

if [[ -f /root/tf-dev-env/ut_targets ]] ; then
  for utest in $(cat /root/tf-dev-env/ut_targets) ; do
    $scriptdir/run-tests.py -j $JOBS $utest
  done
else
  for utest in $(jq -r ".[].scons_test_targets[]"  controller/ci_unittests.json| sort | uniq) ; do
    if [ ! -z "$TARGET" ] && [[ $utest != *"$TARGET"* ]]
      then continue
    fi
    echo "INFO: Starting unit tests for package " $utest
    $scriptdir/run-tests.py -j $JOBS $utest
  done
fi
