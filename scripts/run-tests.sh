#!/bin/bash -e

TARGET=${1:-"."}
JOBS=${JOBS:-1}

cd /root/contrail/
if [[ $TARGET == *":test" ]]; then
  echo "INFO: Starting unit tests for provided target: " $TARGET
  python3 ../tf-dev-env/scripts/run-tests.py -j $JOBS $TARGET
else
  echo "INFO: Starting unit tests for package:" $TARGET
  for file in $(find . -name *.json) ; do
     for I in $(grep "$TARGET" $file |  grep ":test" ); do
       python3 ../tf-dev-env/scripts/run-tests.py -j $JOBS $I
       done;
  done
fi

