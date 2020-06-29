#!/bin/bash

workdir=$1
container=$2

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../../common/common.sh"
source_env

${workdir}/containers/build.sh $container
