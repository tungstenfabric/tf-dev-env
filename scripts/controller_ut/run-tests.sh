#!/bin/bash

TARGET=${1:-}
JOBS=${JOBS:-$(nproc)}

scriptdir=$(realpath $(dirname "$0"))

cd /root/contrail
logs_path='/root/contrail/logs'
mkdir -p "$logs_path"

targets_file='/root/contrail/unittest_targets'
if [[ ! -f "$targets_file" ]] ; then
  targets_file='/tmp/unittest_targets'
  rm "$targets_file" && touch "$targets_file"
  for utest in $(jq -r ".[].scons_test_targets[]"  controller/ci_unittests.json| sort | uniq) ; do
    if [[ -z "$TARGET" || "$utest" == *"$TARGET"* ]]; then
      echo "$utest" >> "$targets_file"
    fi
  done
fi

res=0
echo "INFO: targets to run:"
cat "$targets_file"
echo ; echo
for utest in $(cat "$targets_file") ; do
  echo "INFO: Starting unit tests for target $utest"
  logfilename=$(echo $utest | cut -f 1 -d ':' | rev | cut -f 1 -d '/' | rev)
  if ! "$scriptdir/run-tests.py" -j $JOBS $utest  &> $logs_path/$logfilename ; then
    res=1
    echo "ERROR: $utest failed"
  fi
  echo "INFO: Unit test log is available at $logs_path/$logfilename"

  # TODO: remove this hack. it's added to speed up testing for now
  break

done

if [[ "$res" != '0' ]]; then
  echo "ERROR: some UT failed"
fi
exit $res
