#!/bin/bash

TARGET=${1:-}
TARGET_TIMEOUT=${TARGET_TIMEOUT:-"120m"}

scriptdir=$(realpath $(dirname "$0"))
source $scriptdir/definitions.sh

cd "${ROOT_CONTRAIL:-$HOME/contrail}"
dump_path="${CONTRAIL_OUTPUT_DIR:-/output}/cores"
logs_path="${CONTRAIL_OUTPUT_DIR:-/output}/logs"
mkdir -p "$logs_path"
rm -rf "$dump_path"
mkdir -p "$dump_path"

# contrail code assumes this in tests, since it uses socket.fqdn(..) but expects the result
# to be 'localhost' when for CentOS it would return 'localhost.localdomain'
# see e.g.: https://github.com/Juniper/contrail-analytics/blob/b488e3cd608643ae5dd1e0dcbc03c9e8768178ce/contrail-opserver/alarmgen.py#L872
bash -c 'echo "127.0.0.1 localhost" > /etc/hosts'
bash -c 'echo "::1 localhost" >> /etc/hosts'

unset BUILD_ONLY

echo "INFO: Prepare targets $(date)"
targets_file="${CONTRAIL_INPUT_DIR:-/input}/unittest_targets.lst"
if [[ ! -f "$targets_file" ]] ; then
  targets_file='/tmp/unittest_targets.lst'
  rm "$targets_file" && touch "$targets_file"
  for utest in $(jq -r ".[].scons_test_targets[]"  controller/ci_unittests.json| sort | uniq) ; do
    if [[ -z "$TARGET" || "$utest" == *"$TARGET"* ]]; then
      echo "$utest" >> "$targets_file"
    fi
  done
fi

# target_set as an additional key for some log names
target_set_file="${CONTRAIL_INPUT_DIR:-/input}/target_set" 
if [ -e "$target_set_file" ]; then
  target_set=$(cat "$target_set_file")
fi

res=0
echo "INFO: enable core dumps"
ulimit -c unlimited
echo "$dump_path/core-%i-%p-%E" > /proc/sys/kernel/core_pattern

echo "INFO: targets to run:"
cat "$targets_file"
echo ; echo
for utest in $(cat "$targets_file") ; do
  echo "INFO: $(date) Starting unit tests for target $utest"
  logfilename="$(echo $utest | cut -f 1 -d ':' | rev | cut -f 1 -d '/' | rev).log"
  if ! timeout $TARGET_TIMEOUT "$scriptdir/run-tests.py" --less-strict -j $JOBS --skip-tests $DEV_ENV_ROOT/skip_tests $utest &> $logs_path/$logfilename ; then
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
    dst_file=$(echo $file | sed "s~${ROOT_CONTRAIL:-$HOME/contrail}~$logs_path~g")
    mkdir -p $(dirname $dst_file)
    cp $file $dst_file
  done
}

# gather scons logs
test_list="$logs_path/scons_describe_tests.txt"
if [[ -n "$target_set" ]] ; then test_list+=".$target_set" ; fi
scons -Q --warn=no-all --describe-tests $(cat $targets_file | tr '\n' ' ') > $test_list
while IFS= read -r line
do
  process_file "$(echo $line | jq -r ".log_path" 2>/dev/null)" 'log'
  process_file "$(echo $line | jq -r ".xml_path" 2>/dev/null)" 'xml'
done < "$test_list"

# gather core dumps
cat <<COMMAND > /tmp/commands.txt
set height 0
t a a bt
quit
COMMAND
echo "INFO: cores: $(ls -l $dump_path/)"
for core in $(ls -1 $dump_path/core-*) ; do
  x=$(basename "${core}")
  y=${x/#core-*[0-9]-*[0-9]-/}
  y=${y//\!//}
  timeout -s 9 30 gdb --command=/tmp/commands.txt -c $core $y > build/$x-bt.log
done
rm -rf $dump_path

# gather test logs
for file in $(find build/ -name '*.log' ! -size 0) ; do 
  mkdir -p $logs_path/$(dirname $file)
  cp -u $file $logs_path/$file
done

# gzip .log files - they consume several Gb unpacked
pushd $logs_path
time find $(pwd) -name '*.log' | xargs gzip
popd

if [[ "$res" != '0' ]]; then
  echo "ERROR: some UT failed"
fi
exit $res
