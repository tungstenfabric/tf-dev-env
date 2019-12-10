#!/bin/bash

TARGET=${1:-}
JOBS=${JOBS:-$(nproc)}

scriptdir=$(realpath $(dirname "$0"))

cd /root/contrail 
res=0
if [[ -f ./unittest_targets ]] ; then
  echo "INFO: targets to run:"
  cat ./unittest_targets
  echo ; echo
  for utest in $(cat ./unittest_targets) ; do
    echo "INFO: Starting unit tests for target $utest"
    if ! $scriptdir/run-tests.py -j $JOBS $utest ; then
      res=1
      echo "ERROR: $utest failed"
    fi
  done
else
  for utest in $(jq -r ".[].scons_test_targets[]"  controller/ci_unittests.json| sort | uniq) ; do
    if [[ -n "$TARGET" && "$utest" != *"$TARGET"* ]]; then
      continue
    fi
    echo "INFO: Starting unit tests for target $utest"
    if ! $scriptdir/run-tests.py -j $JOBS $utest >> /root/contrail/logs/unit_test.log; then
      res=1
      echo "ERROR: $utest failed"
    fi
  done
fi

if [[ "$res" != '0' ]]; then
  echo "ERROR: some UT failed"
fi

exit $res
