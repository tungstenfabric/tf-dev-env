#!/bin/bash
set -eo pipefail

CANONICAL_HOSTNAME=${CANONICAL_HOSTNAME:-"review.opencontrail.org"}

if [[ -d /config ]]; then
  cp -rf /config/* /
fi

if [[ "${AUTOBUILD}" -eq 1 ]]; then
    cd $CONTRAIL_DEV_ENV

    if [[ "${SRC_MOUNTED}" != "1" ]]; then
        echo "INFO: make sync  $(date)"
        make sync
    fi
    
    echo "INFO: make setup  $(date)"
    make setup
    echo "INFO: make dep fetch_packages  $(date)"
    make -j 2 dep fetch_packages
    echo "INFO: make rpm  $(date)"
    make rpm

    echo "INFO: make containers  $(date)"
    if [[ "${BUILD_TEST_CONTAINERS}" == "1" ]]; then
        # prepare rpm repo and repos
        echo "INFO: make create-repo prepare-containers prepare-deployers prepare-test-containers  $(date)"
        make -j 4 create-repo prepare-containers prepare-deployers prepare-test-containers
        build_status=$?
        if [[ "$build_status" != "0" ]]; then
            echo "INFO: make prepare containers failed with code $build_status  $(date)"
            exit $build_status
        fi
        
        # prebuild general base as it might be used by deployers
        echo "INFO: make container-general-base  $(date)"
        make container-general-base | sed "s/^/containers: /"
        build_status=$?
        if [[ "$build_status" != "0" ]]; then
            echo "INFO: make general-base container failed with code $build_status $(date)"
            exit $build_status
        fi

        # build containers
        echo "INFO: make containers-only deployers-only test-containers-only  $(date)"
        make -j 3 containers-only deployers-only test-containers-only | sed "s/^/containers: /"
        build_status=$?
        if [[ "$build_status" != "0" ]]; then
            echo "INFO: make containers failed with code $build_status $(date)"
            exit $build_status
        fi

        echo Build of containers with deployers has finished successfully
    else
        echo "INFO: make create-repo prepare-containers prepare-deployers   $(date)"
        make -j 3 create-repo prepare-containers prepare-deployers 
        echo "INFO: make container-general-base   $(date)"
        make container-general-base
        echo "INFO: make containers-only deployers-only   $(date)"
        make -j 2 containers-only deployers-only
    fi

    echo "INFO: make successful  $(date)"
    exit 0
fi

/bin/bash
