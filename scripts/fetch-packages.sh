#!/bin/bash
set -e

SITE_MIRROR=${SITE_MIRROR:-}
echo SITE_MIRROR=${SITE_MIRROR}
cd /root/contrail/third_party
if [[ ! -z "${SITE_MIRROR}" ]]; then
    python3 -u fetch_packages.py --site-mirror ${SITE_MIRROR} 2>&1 | grep -Ei 'Processing|patching'
else
    python3 -u fetch_packages.py 2>&1 | grep -Ei 'Processing|patching'
fi