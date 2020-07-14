#!/bin/bash

TARGET=${1:-}
TARGET_TIMEOUT=${TARGET_TIMEOUT:-"120m"}

scriptdir=$(realpath $(dirname "$0"))
source $scriptdir/definitions.sh

cd $HOME/contrail
logs_path="/output/logs"
mkdir -p "$logs_path"

# contrail code assumes this in tests, since it uses socket.fqdn(..) but expects the result
# to be 'localhost' when for CentOS it would return 'localhost.localdomain'
# see e.g.: https://github.com/Juniper/contrail-analytics/blob/b488e3cd608643ae5dd1e0dcbc03c9e8768178ce/contrail-opserver/alarmgen.py#L872
bash -c 'echo "127.0.0.1 localhost" > /etc/hosts'
bash -c 'echo "::1 localhost" >> /etc/hosts'

unset BUILD_ONLY

echo "INFO: Prepare targets $(date)"
targets_file="/input/unittest_targets.lst"
if [[ ! -f "$targets_file" ]] ; then
  targets_file='/tmp/unittest_targets.lst'
  rm "$targets_file" && touch "$targets_file"
  if [ -f controller/ci_skip_tests ]; then
    skip_tests=($(cat controller/ci_skip_tests | tr "\n" " "))
  else
    skip_tests=()
  fi
  for utest in $(jq -r ".[].scons_test_targets[]"  controller/ci_unittests.json| sort | uniq) ; do
    if [[ -z "$TARGET" || "$utest" == *"$TARGET"* ]]; then
      if [[ ! " ${skip_tests[@]} " =~ " ${utest} " ]]; then
        echo "$utest" >> "$targets_file"
      fi
    fi
  done
fi

res=0
echo "INFO: targets to run:"
cat "$targets_file"
echo ; echo
for utest in $(cat "$targets_file") ; do
  echo "INFO: $(date) Starting unit tests for target $utest"
  logfilename=$(echo $utest | cut -f 1 -d ':' | rev | cut -f 1 -d '/' | rev)
  if ! timeout $TARGET_TIMEOUT "$scriptdir/run-tests.py" --less-strict -j $JOBS $utest &> $logs_path/$logfilename ; then
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
    dst_file=$(echo $file | sed "s~$HOME/contrail~$logs_path~g")
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
