#!/bin/bash -ex

scriptdir=$(realpath $(dirname "$0"))

src_root=$HOME/contrail
cd $src_root

# ensure that all packages are installed
make dep-contrail-web-core
make dep-contrail-web-controller

logs_path="/output/logs"
test_reports_dir="$logs_path/test-reports"
coverage_reports_dir="$logs_path/coverage-reports"
mkdir -p "$logs_path" "$test_reports_dir" "$coverage_reports_dir"

function pre_test_setup() {
    #Update the featurePkg path in contrail-web-core/config/config.global.js  with Controller, Storage and Server Manager features
    cd $src_root/contrail-web-core

    # Controller
    cat config/config.global.js | sed -e "s%/usr/src/contrail/contrail-web-controller%$src_root/contrail-web-controller%" > $src_root/contrail-web-core/config/config.global.js.tmp
    cp $src_root/contrail-web-core/config/config.global.js.tmp $src_root/contrail-web-core/config/config.global.js
    rm $src_root/contrail-web-core/config/config.global.js.tmp
    touch config/config.global.js

    #fetch dependent packages
    make fetch-pkgs-dev
}

function build_unittest() {
    #Setup the Prod Environment
    make prod-env REPO=webController
    #Setup the Test Environment
    make test-env REPO=webController

    # Run Controller related Unit Testcase
    cd $src_root/contrail-web-controller
    ./webroot/test/ui/run_tests.sh 2>&1 | tee $logs_path/web_controller_unittests.log
}

function copy_reports(){
    cd $src_root
    report_dir=webroot/test/ui/reports

    echo "info: gathering XML test reports..."
    cp -p contrail-web*/$report_dir/tests/*-test-results.xml $test_reports_dir || true

    echo "info: gathering XML coverage reports..."
    cp -p $HOME/contrail/contrail-web-controller/$report_dir/coverage/*/*/cobertura-coverage.xml $coverage_reports_dir/controller-cobertura-coverage.xml || true
}

#This installs node, npm and does a fetch_packages, make prod env, test setup
pre_test_setup

# run unit test case
build_unittest

# copy the generated reports to specific directory
copy_reports

res=$?
if [[ "$res" != '0' ]]; then
  echo "ERROR: some UT failed"
fi
echo "INFO: Unit test log is available at contrail/output/logs/web_controller_unittests.log"
echo "INFO: Test report is available at  contrail/output/logs/test-reports/web-controller-test-results.xml"
echo "INFO: Coverage report is available at contrail/output/logs/coverage-reports/controller-cobertura-coverage.xml"
exit $res
