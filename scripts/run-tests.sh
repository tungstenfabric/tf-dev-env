#!/bin/bash -e

TARGET=${1:-}
JOBS=${JOBS:-1}

cd /root/contrail/
if [[ $TARGET == *":test" ]]; then
  echo "INFO: Starting unit tests for provided target: " $TARGET
  python3 ../tf-dev-env/scripts/run-tests.py -j $JOBS $TARGET
else
  echo "INFO: Starting unit tests for package: " $TARGET
  for test in $( jq -r .default.scons_test_targets[] controller/ci_unittests.json) ; do
    if [[ $test == *"$TARGET"* ]] ; then
      python3 ../tf-dev-env/scripts/run-tests.py -j $JOBS $test
    fi;
  done;
fi

