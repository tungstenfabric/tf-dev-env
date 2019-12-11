#!/bin/bash

TARGET=${1:-}
JOBS=${JOBS:-$(nproc)}

scriptdir=$(realpath $(dirname "$0"))

cd /root/contrail

if [ ! -d logs ] ; then mkdir logs  ; fi

res=0
if [[ -f ./unittest_targets ]] ; then
  echo "INFO: targets to run:"
  cat ./unittest_targets
  echo ; echo
  for utest in $(cat ./unittest_targets) ; do
    echo "INFO: Starting unit tests for target $utest"
    logfilename=$( echo $utest |  cut -f1 -d ':' | rev | cut -f1 -d'/' | rev )
    if ! $scriptdir/run-tests.py -j $JOBS $utest  &> /root/contrail/logs/$logfilename ; then
      res=1
      echo "ERROR: $utest failed"
    fi
    echo "INFO: Unit test log is available at /root/contrail/logs/$logfilename"
  done
else
  for utest in $(jq -r ".[].scons_test_targets[]"  controller/ci_unittests.json| sort | uniq) ; do
    logfilename=$( echo $utest |  cut -f1 -d ':' | rev | cut -f1 -d'/' | rev )
    if [[ -n "$TARGET" && "$utest" != *"$TARGET"* ]]; then
      continue
    fi
    echo "INFO: Starting unit tests for target $utest"
    if ! $scriptdir/run-tests.py -j $JOBS $utest &> /root/contrail/logs/$logfilename ; then
      res=1
      echo "ERROR: $utest failed"
    fi
    echo "INFO: Unit test log is available at /root/contrail/logs/$logfilename"
  done
fi

if [[ "$res" != '0' ]]; then
  echo "ERROR: some UT failed"
fi

exit $res
