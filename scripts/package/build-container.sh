#!/bin/bash

workdir=$1
container=$2

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../../common/common.sh"
source_env

set -eo pipefail
[ -n "$DEBUG" ] && set -x

${workdir}/containers/build.sh $containers
