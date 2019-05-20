#!/bin/bash
set -e

CANONICAL_HOSTNAME=${CANONICAL_HOSTNAME:-"review.opencontrail.org"}

if [[ -d /config ]]; then
  cp -rf /config/* /
fi

if [[ "${AUTOBUILD}" -eq 1 ]]; then
    cd $CONTRAIL_DEV_ENV

    if [[ "${SRC_MOUNTED}" != "1" ]]; then
        make sync
    fi

    make setup dep fetch_packages
    make rpm

    if [[ "${BUILD_TEST_CONTAINERS}" == "1" ]]; then
        make containers deployers | sed "s/^/containers: /" &
        containers_pid=$!

        make test-containers | sed "s/^/test_containers: /" &
        test_containers_pid=$!

        wait $containers_pid
        containers_status=$?

        wait $test_containers_pid
        test_containers_status=$?

        echo Build of containers with deployers has finished with status $containers_status
        echo Build of test containers has finished with status $test_containers_status

        if [[ "$containers_status" != "0" ]]; then
            exit $containers_status
        fi

        if [[ "$test_containers_status" != "0" ]]; then
            exit $test_containers_status
        fi
    else
        make containers deployers
    fi

    exit 0
fi

/bin/bash
