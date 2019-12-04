#!/bin/bash

stages=${1//,/ }
shift

echo "INFO: run stages $stages"

if [[ -e ${CONTRAIL}/.env/tf-developer-sandbox.env ]] ; then
    echo "INFO: source env from ${CONTRAIL}/.env/tf-developer-sandbox.env"
    set -o allexport
    source ${CONTRAIL}/.env/tf-developer-sandbox.env
    set +o allexport
fi

[ -n "$DEBUG" ] && set -x

set -eo pipefail

declare -a all_stages=(fetch configure compile package test)
declare -a build_stages=(fetch configure compile package)
declare -a test_stages=(fetch configure test)

export CANONICAL_HOSTNAME=${CANONICAL_HOSTNAME:-"review.opencontrail.org"}

if [[ -n "$CONTRAIL_CONFIG_DIR" && -d "$CONTRAIL_CONFIG_DIR" ]]; then
  cp -rf ${CONTRAIL_CONFIG_DIR}/* /
fi

cd $CONTRAIL_DEV_ENV
STAGES_DIR="${CONTRAIL}/.stages"
mkdir -p $STAGES_DIR

function fetch() {
    echo "INFO: make sync  $(date)"
    make sync
}

function configure() {
    echo "INFO: make setup  $(date)"
    make setup

    echo "INFO: make dep fetch_packages  $(date)"
    # targets can use yum and will block each other. don't run them in parallel
    make dep fetch_packages
}

function compile() {
    echo "INFO: Check variables used by makefile"
    uname -a
    make info
    echo "INFO: make rpm  $(date)"
    make rpm
    make create-repo
}

function test() {
    echo "INFO: Starting unit tests"
    uname -a
    TEST_PACKAGE=$1 make test
}

function package() {
    echo "INFO: Check variables used by makefile"
    uname -a
    make info
    echo "INFO: make containers  $(date)"
    # prepare rpm repo and repos
    echo "INFO: make create-repo prepare-containers prepare-deployers prepare-test-containers  $(date)"
    make -j 3 prepare-containers prepare-deployers prepare-test-containers
    build_status=$?
    if [[ "$build_status" != "0" ]]; then
        echo "INFO: make prepare containers failed with code $build_status  $(date)"
        exit $build_status
    fi

    # prebuild general base as it might be used by deployers
    echo "INFO: make container-general-base  $(date)"
    make container-general-base
    build_status=$?
    if [[ "$build_status" != "0" ]]; then
        echo "INFO: make general-base container failed with code $build_status $(date)"
        exit $build_status
    fi

    # build containers
    echo "INFO: make containers-only deployers-only test-containers-only  $(date)"
    make -j 6 containers-only deployers-only test-containers-only
    build_status=$?
    if [[ "$build_status" != "0" ]]; then
        echo "INFO: make containers failed with code $build_status $(date)"
        exit $build_status
    fi

    echo Build of containers with deployers has finished successfully
}

function run_stage() {
    $1 $2
    touch $STAGES_DIR/$1
}

function finished_stage() {
    [ -e $STAGES_DIR/$1 ]
}

function cleanup() {
    local stage=${1:-'*'}
    rm -f $STAGES_DIR/$stage
}

function enabled() {
    [[ "$1" =~ "$2" ]]
}

# select default stages
if [[ -z "$stages" ]] ; then
    if ! finished_stage 'fetch' ; then
        run_stage fetch
    fi
    if ! finished_stage 'configure' ; then
        run_stage configure
    fi
elif [[ "$stages" =~ 'build' ]] ; then
    # run default stages for 'build' option
    for stage in ${build_stages[@]} ; do
        if ! finished_stage "$stage" ; then
            run_stage $stage $@
        fi
    done
elif [[ "$stages" =~ 'test' ]] ; then
    # run default stages for 'build' option
    for stage in ${test_stages[@]} ; do
        if ! finished_stage "$stage" ; then
            run_stage $stage $@
        fi
    done
else
    # run selected stages
    for stage in ${stages} ; do
        if [[ "$stages" =~ $stage ]] ; then
          run_stage $stage $@
        fi
    done
fi


echo "INFO: make successful  $(date)"
