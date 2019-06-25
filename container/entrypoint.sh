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
    echo "INFO: make dep  $(date)"
    make dep
    echo "INFO: make fetch_packages  $(date)"
    make fetch_packages
    echo "INFO: make rpm  $(date)"
    make rpm
    echo "INFO: make create-repo  $(date)"
    make create-repo

    echo "INFO: make containers  $(date)"
    if [[ "${BUILD_TEST_CONTAINERS}" == "1" ]]; then
        make prepare-containers containers-only prepare-deployers deployers-only | sed "s/^/containers: /" &
        containers_pid=$!

        make prepare-test-containers test-containers-only | sed "s/^/test_containers: /" &
        test_containers_pid=$!

        wait $test_containers_pid
        test_containers_status=$?
        echo Build of test containers has finished with status $test_containers_status

        if [[ "$test_containers_status" != "0" ]]; then
            echo Termination build containers job
            kill $containers_pid
            echo "INFO: make test containers failed  $(date)"
            exit $test_containers_status
        fi

        wait $containers_pid
        containers_status=$?

        echo Build of containers with deployers has finished with status $containers_status

        if [[ "$containers_status" != "0" ]]; then
            echo "INFO: make containers failed  $(date)"
            exit $containers_status
        fi
    else
        make prepare-containers containers-only
        make prepare-deployers deployers-only
    fi

    echo "INFO: make successful  $(date)"
    exit 0
fi

/bin/bash
