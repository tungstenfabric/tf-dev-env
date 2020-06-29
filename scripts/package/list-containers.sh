#!/bin/bash

workdir=$1
prefix=$2

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../../common/common.sh"
source_env

set -o pipefail

${workdir}/containers/build.sh list | grep -v INFO | sed -e 's,/,_,g' -e "s/^/${prefix}-/"
