#!/bin/bash

TARGET=${1:-}
JOBS=${JOBS:-$(nproc)}

scriptdir=$(realpath $(dirname "$0"))

cd /root/contrail

function controller_ut() {
  local logs_path='/root/contrail/logs'
  mkdir -p "$logs_path"

  local utest
  local targets_file='/root/contrail/unittest_targets'
  if [[ ! -f "$targets_file" ]] ; then
    targets_file='/tmp/unittest_targets'
    rm "$targets_file" && touch "$targets_file"
    for utest in $(jq -r ".[].scons_test_targets[]"  controller/ci_unittests.json| sort | uniq) ; do
      if [[ -z "$TARGET" || "$utest" == *"$TARGET"* ]]; then
        echo "$utest" >> "$targets_file"
      fi
    done
  fi

  local res=0
  echo "INFO: targets to run:"
  cat "$targets_file"
  echo ; echo
  for utest in $(cat "$targets_file") ; do
    echo "INFO: Starting unit tests for target $utest"
    local logfilename=$(echo $utest | cut -f 1 -d ':' | rev | cut -f 1 -d '/' | rev)
    if ! $scriptdir/run-tests.py -j $JOBS $utest  &> $logs_path/$logfilename ; then
      res=1
      echo "ERROR: $utest failed"
    fi
    echo "INFO: Unit test log is available at $logs_path/$logfilename"
  done

  if [[ "$res" != '0' ]]; then
    echo "ERROR: some UT failed"
  fi
  return $res
}

if [[ "$TARGET" == 'ui' ]]; then
  echo "INFO: Running web ui tests"
elif [[ "$TARGET" == 'vcenter' ]]; then
  echo "INFO: Running vcenter tests"
else
  echo "INFO: Running controller tests"
  controller_ut
fi

exit $res
