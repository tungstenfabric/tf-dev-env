#!/bin/bash -e

opts=''
if [[ -n "${SITE_MIRROR}" ]]; then
  opts="--site-mirror ${SITE_MIRROR}"
fi
cd /root/contrail/third_party
if ! output=`python3 -u fetch_packages.py $opts 2>&1` ; then
  echo "$output"
  exit 1
fi
if [[ -z "${GERRIT_PROJECT}"]] ; then
  gather-unittest-targets.py > /root/tf-dev-env/ut_targets
fi

echo "$output" | grep -Ei 'Processing|patching'
