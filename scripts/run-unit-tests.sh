#!/bin/bash


jobs=8
if [[ '{{ item }}' == 'sandesh:test' || '{{ item }}' == 'controller/src/cat:test' ]]; then jobs=1 ; fi
set -eo pipefail
for config_file in $( find $HOME/ -name "ci_unittests.json" ) ; do
  for test in $( cat $config_file | grep ":test"  | cut -f2 -d'"' ); do
    scons -Q --warn=no-all --describe-tests $test
  done
done;







