#!/bin/bash
set -e

if [[ "${AUTOBUILD}" -eq 1 ]]; then
    cd $CONTRAIL_DEV_ENV
    make setup dep fetch_packages
    make rpm containers deployers
    exit 0
fi

/bin/bash
