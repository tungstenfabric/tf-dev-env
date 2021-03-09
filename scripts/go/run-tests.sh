#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))

if [ -z "$GERRIT_PROJECT" ]; then
  echo "ERROR: GERRIT_PROJECT must be set for tox tests"
  exit 1
fi

echo "INFO: Running go tests for project: $GERRIT_PROJECT"

type go >/dev/null 2>&1 || {
  export PATH=$PATH:/usr/local/go/bin
}

cd $HOME/contrail

project=$(echo $GERRIT_PROJECT | cut -d '/' -f 2)
echo "INFO: short project name: $project"
path=$(./repo list -f -r $project | awk '{print $1}' | head -1)
echo "INFO: project path: $path"

res=0
pushd $path

make test || res=1

popd

# collect log files if required

if [[ "$res" != '0' ]]; then
  echo "ERROR: some UT failed"
fi
exit $res
