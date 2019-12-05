#!/bin/bash -e

TARGET=${1:-}
JOBS=${JOBS:-1}

scriptdir=$(realpath $(dirname "$0"))

res=0
if [[ -f /root/contrail/unittest_targets ]] ; then
  for utest in $(cat unittest_targets) ; do
    echo "INFO: Starting unit tests for package $utest"
    $scriptdir/run-tests.py -j $JOBS $utest || res=1
  done
else
  for utest in $(jq -r ".[].scons_test_targets[]"  controller/ci_unittests.json| sort | uniq) ; do
    if [[ -n "$TARGET" && "$utest" != *"$TARGET"* ]]; then
      continue
    fi
    echo "INFO: Starting unit tests for package $utest"
    $scriptdir/run-tests.py -j $JOBS $utest || res=1
  done
fi

if [[ "$res" != '0' ]]; then
  echo "ERROR: some UT failed"
fi

exit $res
