#!/bin/bash -e

PACKAGE=${1:-"."}
JOBS=${JOBS:-1}

cd /root/contrail/
echo "INFO: Starting unit tests for package:" $PACKAGE
scons -j $JOBS --keep-going  $PACKAGE
