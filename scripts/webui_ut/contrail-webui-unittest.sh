#!/usr/bin/env bash

set -o pipefail
set -xe

workspace=/root/contrail
cd $workspace
logs_path='/root/contrail/logs'
mkdir -p "$logs_path"

export test_reports_dir="$logs_path/test-reports"
export coverage_reports_dir="$logs_path/coverage-reports"
mkdir -p "$test_reports_dir"
mkdir -p "$coverage_reports_dir"

function pre_test_setup() {
    #Update the featurePkg path in contrail-web-core/config/config.global.js  with Controller, Storage and Server Manager features
    cd $workspace/contrail-web-core

    # Controller
    cat config/config.global.js | sed -e "s%/usr/src/contrail/contrail-web-controller%$workspace/contrail-web-controller%" > $workspace/contrail-web-core/config/config.global.js.tmp
    cp $workspace/contrail-web-core/config/config.global.js.tmp $workspace/contrail-web-core/config/config.global.js
    rm $workspace/contrail-web-core/config/config.global.js.tmp
    touch config/config.global.js

    #fetch dependent packages
    make fetch-pkgs-dev
}

# Build unittests
function build_unittest() {
    #Setup the Prod Environment
    make prod-env REPO=webController
    #Setup the Test Environment
    make test-env REPO=webController

    # Run Controller related Unit Testcase
    cd $workspace/contrail-web-controller
    ./webroot/test/ui/run_tests.sh 2>&1 | tee $logs_path/web_controller_unittests.log
}

function copy_reports(){
    cd $workspace
    report_dir=webroot/test/ui/reports

    echo "info: gathering XML test reports..."
    cp -p contrail-web*/$report_dir/tests/*-test-results.xml $test_reports_dir || true

    echo "info: gathering XML coverage reports..."
    cp -p /root/contrail/contrail-web-controller/$report_dir/coverage/*/*/cobertura-coverage.xml $coverage_reports_dir/controller-cobertura-coverage.xml || true
}

function main() {
    #This installs node, npm and does a fetch_packages, make prod env, test setup
    pre_test_setup

    # run unit test case
    build_unittest

    # copy the generated reports to specific directory
    copy_reports
}

env
main