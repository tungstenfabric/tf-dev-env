#!/bin/bash

TARGET=${1:-}
JOBS=${JOBS:-$(nproc)}

scriptdir=$(realpath $(dirname "$0"))

cd /root/contrail
logs_path='/root/contrail/logs'
mkdir -p "$logs_path"

echo "INFO: Run full build first $(date)"
export CONTRAIL_COMPILE_WITHOUT_SYMBOLS=yes
BUILD_ONLY=1 scons -j $JOBS &> $logs_path/build_full
unset BUILD_ONLY

echo "INFO: Prepare targets $(date)"
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
  echo "INFO: $(date) Starting unit tests for target $utest"
  # sandesh tests don't work in parallel due to races
  jobs=$JOBS ; if [[ "$utest" == "sandesh:test" ]]; then jobs=1 ; fi
  logfilename=$(echo $utest | cut -f 1 -d ':' | rev | cut -f 1 -d '/' | rev)
  if ! "$scriptdir/run-tests.py" -j $jobs $utest  &> $logs_path/$logfilename ; then
    res=1
    echo "ERROR: $utest failed"
  fi
  echo "INFO: $(date) Unit test log is available at $logs_path/$logfilename"
done

function process_file() {
  local src_file=$1
  local ext=$2
  if [[ "$src_file" == 'null' ]]; then
    return
  fi
  for file in $(ls -1 ${src_file%.${ext}}.*.${ext} 2>/dev/null) ; do
    dst_file=$(echo $file | sed "s~/root/contrail~$logs_path~g")
    mkdir -p $(dirname $dst_file)
    cp $file $dst_file
  done
}

# gather scons logs
input="$logs_path/scons_describe_tests.txt"
scons -Q --warn=no-all --describe-tests $(cat $targets_file | tr '\n' ' ') > $input
while IFS= read -r line
do
  process_file "$(echo $line | jq -r ".log_path" 2>/dev/null)" 'log'
  process_file "$(echo $line | jq -r ".xml_path" 2>/dev/null)" 'xml'
done < "$input"

if [[ "$res" != '0' ]]; then
  echo "ERROR: some UT failed"
fi
exit $res
