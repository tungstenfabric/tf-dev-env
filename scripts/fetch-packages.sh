#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../common/common.sh"
source_env

opts=''
if [[ -n "${SITE_MIRROR}" ]]; then
  opts="--site-mirror ${SITE_MIRROR}"
fi
cd "${ROOT_CONTRAIL:-$HOME/contrail}/third_party"
if ! output=`python3 -u fetch_packages.py $opts 2>&1` ; then
  echo "$output"
  exit 1
fi

echo "$output" | grep -Ei 'Processing|patching'
