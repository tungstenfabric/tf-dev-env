#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))

$scriptdir/startup.sh
res=$?

if [[ "$QUIT" == true ]] ; then
    exit $res
fi

/bin/bash
