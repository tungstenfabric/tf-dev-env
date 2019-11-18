#!/bin/bash -e

PACKAGE=${1:-"."}
JOBS=${JOBS:-1}

cd /root/contrail/

scons -j $JOBS --keep-going  $PACKAGE
