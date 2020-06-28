#!/usr/bin/env python3

import os
import random
import sys
import json
import jinja2
import argparse
import subprocess
import string
import logging
import shutil
from lxml import etree

logging.basicConfig(level=logging.DEBUG)


class TestResult:
    SUCCESS = 0
    FAILURE = 1
    MISSING_XML = 2
    MISSING_LOG = 3


class TestSuite:
    def __init__(self, name):
        self.name = name
        self.disabled = None
        self.errors = self.failures = None
        self.test_cases = []

    @property
    def failed(self):
        return any([t.status != "run" for t in self.test_cases])


class TestCase:
    def __init__(self, name):
        self.name = name
        self.classname = None
        self.status = None
        self.time = None
        self.failures = []


class TestFailure:
    def __init__(self):
        self.message = ""
        self.type = ""
        self.data = ""


class TungstenTestRunner(object):
    def __init__(self):
        self.args = None
        self.tests = []
        self.test_results = {}

    def parse_arguments(self):
        parser = argparse.ArgumentParser(description="Tungsten Test Runner")
        parser.add_argument("--debug", dest="debug", action="store_true")
        parser.add_argument("--less-strict", dest="strict", action="store_false")
        parser.add_argument("-j", help="Allow N jobs at once for scons run.", dest="job_count", type=int)
        parser.add_argument("targets", type=str, nargs="+")

        self.args = parser.parse_args()
        if not self.args.job_count:
            self.args.job_count = os.cpu_count()

    def _get_relative_path(self, path):
        rel_start = path.find("build/")
        return path[rel_start:]

    def describe_tests(self):
        logging.info("Gathering tests for the following targets: %s", (self.args.targets))
        command = [shutil.which("python2"),
                   shutil.which("scons"),
                   "--describe-tests"] + self.args.targets
        lines = subprocess.check_output(command).decode('utf-8').split("\n")
        for line in lines:
            if len(line) == 0 or line[0] != '{':
                logging.debug("Not a valid JSON: '%s'", line)
                continue
            test_details = json.loads(line)
            if test_details['matched']:
                self.tests += [test_details]
        for test in self.tests:
            key = self._get_relative_path(test['node_path'])
            self.test_results[key] = {"result": "SUCCESS", "details": []}
        logging.debug("Found %d tests for targets.", len(self.tests))

    def run_tests(self, targets=None):
        """Run tests with SCons, optionally overriding targets to execute."""
        if targets is None:
            targets = self.args.targets
        scons_env = os.environ.copy()
        args = []
        if 'KVERS' in scons_env:
            args += ['--kernel-dir=/lib/modules/{}/build'.format(scons_env['KVERS'])]
        if not self.args.strict:
            scons_env['NO_HEAPCHECK'] = '1'
        command = [shutil.which("python2"),
                   shutil.which("scons"),
                   "-j", str(self.args.job_count),
                   "--keep-going"] + args + targets
        logging.info("Executing SCons command: %s", " ".join(command))
        rc = subprocess.call(command, env=scons_env)
        return rc, targets

    def _parse_junit_xml(self, xml_path):
        """Parse the XML file and return all tests that were executed."""
        if not os.path.exists(xml_path):
            return (TestResult.MISSING_XML, None)

        logging.debug("Parsing %s", xml_path)
        with open(xml_path, "rb") as fh:
            xml_doc = fh.read()

        soup = etree.fromstring(xml_doc)

        status = TestResult.SUCCESS
        suite_objs = []

        # check if the root tag is testsuite, and if not, find
        # all testsuite tags under the root tag.
        if soup.tag == 'testsuite':
            suites = [soup]
        else:
            assert soup.tag == 'testsuites'
            suites = soup.findall("testsuite")

        for suite in suites:
            if int(suite.attrib["errors"]) > 0 or int(suite.attrib["failures"]) > 0:
                status = TestResult.FAILURE

            suite_obj = TestSuite(name=suite.attrib["name"])

            # XXX(kklimonda): see if those can be generated from test cases
            for attr in ["disabled", "errors", "failures"]:
                if attr in suite.attrib:
                    setattr(suite_obj, attr, suite.attrib[attr])
            for test in suite.findall('testcase'):
                test_obj = TestCase(name=test.attrib['name'])
                for attr in ["classname", "status", "time"]:
                    if attr in test.attrib:
                        setattr(test_obj, attr, test.attrib[attr])

                failures = test.findall('failure')
                if failures:
                    for failure in failures:
                        fail_obj = TestFailure()
                        for attr in ["message", "type"]:
                            if attr in failure.attrib:
                                setattr(fail_obj, attr, failure.attrib[attr])
                        fail_obj.data = failure.text
                        test_obj.failures += [fail_obj]

                suite_obj.test_cases += [test_obj]
            suite_objs += [suite_obj]
        return status, suite_objs

    def _store_test_results(self, suite, result, tests):
        key = self._get_relative_path(suite['node_path'])
        xml_basepath = self._get_relative_path(os.path.splitext(suite['xml_path'])[0])
        log_basepath = self._get_relative_path(os.path.splitext(suite['log_path'])[0])
        rnd_suffix_len = 8

        # If there is no log file, assume a total failure and store that info.
        if not os.path.exists(suite['log_path']):
            result = TestResult.MISSING_LOG

        while True:
            random_string = "".join([random.choice(string.ascii_lowercase) for i in range(rnd_suffix_len)])
            xml_path = xml_basepath + "." + random_string + ".xml"
            log_path = log_basepath + "." + random_string + ".log"
            if not (os.path.exists(xml_path) or os.path.exists(log_path)):
                break

        if os.path.exists(suite['xml_path']):
            os.rename(suite['xml_path'], xml_path)
        else:
            logging.warning('{} does not exist!'.format(suite['xml_path']))

        if os.path.exists(suite['log_path']):
            os.rename(suite['log_path'], log_path)
        else:
            logging.warning('{} does not exist!'.format(suite['log_path']))

        result_text = "SUCCESS" if result == TestResult.SUCCESS else "FAILURE"
        self.test_results[key]['result'] = result_text
        self.test_results[key]["details"] += [{
            "result": result,
            "xml_path": xml_path,
            "log_path": log_path,
            "tests": tests
        }]

    def _get_test_for_target(self, target):
        for test in self.tests:
            if self._get_relative_path(test['node_path']) == target:
                return test
        raise RuntimeError("No test found for target " + target)

    def analyze_test_results(self, targets=None):
        """Parses XML output from tests looking for failures.

        Parse XML output from tests and keep track of any failures, also
        renaming XML and log files so they are not overwritten by consecutive
        runs.
        """
        global_status = TestResult.SUCCESS
        failed_targets = []

        # if we have not received targets, we want to analyze everything - pull
        # targets directly from self.tests.
        if not targets:
            targets = [self._get_relative_path(t['node_path']) for t in self.tests]

        for target in targets:
            test = self._get_test_for_target(target)
            logging.debug("Analyzing test results for %s", test['node_path'])

            status, tests = self._parse_junit_xml(test['xml_path'])
            if status == TestResult.MISSING_XML:
                logging.warning("Test %s generated no XML - assuming failure.", test['node_path'])
            self._store_test_results(test, status, tests)

            if status != TestResult.SUCCESS:
                global_status = TestResult.FAILURE
                failed_targets += [self._get_relative_path(test['node_path'])]
        return global_status, failed_targets

    def generate_test_report(self, scons_rc, final_result):
        tpl = """Tungsten Test Runner Results
============================

SCons targets executed:
{% for target in scons_targets %}
    {{ target }}
{% endfor %}
SCons Result:		{{ scons_rc }}
Analyzer Result:	{{ final_result }}

Test Results:
{% for key, values in results.items() %}
========================
SCons target:	{{ key }}
Result:		{{ values['result'] }}
------------------------
{% for test in values['details'] %}
Run #{{ loop.index }}
Result:	        {{ test.result }}
Tests:	        {{ test.test | length }}
Failures:       {{ test.failures }}
Errors:         {{ test.errors }}
XML Log:        {{ test.xml_path }}
Console Log:    {{ test.log_path }}

Details:
{% for test_suite in test.tests -%}
{% for test_case in test_suite.test_cases -%}
{% if test_case.failures | length > 0 %}
{{- test_suite.name }}.{{- test_case.name }} - FAILED
{% for failure in test_case.failures %}
{{- failure.data -}}
{%- endfor -%}
{% elif test_case.status == "notrun" -%}
{{- test_suite.name }}.{{- test_case.name }} - SKIPPED
{% else %}
{{- test_suite.name }}.{{- test_case.name }} - SUCCESS
{% endif -%}
{% endfor -%}
{% endfor -%}
{% endfor -%}
{% endfor -%}
"""
        text = ''
        template = jinja2.Template(tpl)
        ctx = {
            "scons_targets": self.args.targets,
            "scons_rc": scons_rc,
            "final_result": final_result,
            "results": self.test_results}
        try:
            text = template.render(ctx)
        except Exception as e:
            print('Unit test report generation failed!')
            print('The exception is ignored to allow the job to successfully finish if no tests '
                  'failed.')
            print('See https://contrail-jws.atlassian.net/browse/JD-475 for more information.')
            print(e)
        print(text)


def main():
    runner = TungstenTestRunner()
    runner.parse_arguments()
    runner.describe_tests()

    failed_targets = None
    for counter in range(3):
        rc, targets = runner.run_tests(targets=failed_targets)
        if rc > 0:
            logging.info("SCons failed with exit code {}. Analyzing results.".format(rc))
        else:
            logging.info("SCons succeeded. Analyzing results.")

        # First analysis is done over all tests, because at this point
        # a) we want to analyze everything
        # b) targets that we have are "generic", not for each test - can't
        #    match it against tests that we store.
        result, failed_targets = runner.analyze_test_results(targets=(None if counter == 0 else targets))
        logging.info("Analyzer result is " + ("SUCCESS" if result == TestResult.SUCCESS else "FAILURE"))
        if rc > 0 and result == TestResult.SUCCESS:
            logging.error("SCons failed, but analyzer didn't find any errors.")
            if not failed_targets:
                logging.critical("Analyzer didn't find targets to retry. Exiting.")
                sys.exit(rc)

        if result == TestResult.SUCCESS:
            break

        logging.warning("Test Failure, {} targets failed:\n".format(len(failed_targets)) +
                        "\n\t".join(failed_targets))
        logging.info("Retrying, %d attempts remaining.", counter)

    runner.generate_test_report(rc, "SUCCESS" if result == TestResult.SUCCESS else "FAILURE")
    sys.exit(rc)


if __name__ == "__main__":
    main()
