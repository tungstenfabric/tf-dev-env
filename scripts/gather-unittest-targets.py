#!/usr/bin/env python

import json
import sys
import os


def convert_path(path):
    if path.startswith("contrail-sandesh/"):
        path = path.replace("contrail-sandesh/", "tools/sandesh/")
    elif path.startswith("contrail-generateDS/"):
        path = path.replace("contrail-generateDS/", "tools/generateds/")
    elif path.startswith("contrail-vrouter/"):
        path = path.replace("contrail-vrouter/", "vrouter/")
    elif path.startswith("contrail-common/"):
        path = path.replace("contrail-common/", "src/contrail-common/")
    elif path.startswith("contrail-analytics/"):
        path = path.replace("contrail-analytics/", "src/contrail-analytics/")
    elif path.startswith("contrail-api-client/"):
        path = path.replace("contrail-api-client/", "src/contrail-api-client/")
    elif path.startswith("contrail-controller/"):
        path = path.replace("contrail-controller/", "controller/")
    return path


patchsets = json.load(sys.stdin)
review_files = set()
for patchset in patchsets:
    project = patchset["project"].split('/')[1]
    review_files.update([project + '/' + file for file in patchset["files"]])

home_dir = os.getenv("HOME", '/root')
with open("%s/contrail/controller/ci_unittests.json" % home_dir) as fh:
    unittests = json.load(fh)

actual_targets = set()
misc_targets = set()
for ffile in review_files:
    vnc_file = convert_path(ffile)
    for package in unittests.keys():
        for sd in unittests[package]["source_directories"]:
            if sd in vnc_file:
                actual_targets.update(unittests[package]["scons_test_targets"])
                misc_targets.update(unittests[package]["misc_test_targets"])
                break

if not actual_targets:
    actual_targets = set(unittests['default']["scons_test_targets"])
    misc_targets = set(unittests['default']["misc_test_targets"])

for misc_target in misc_targets:
    actual_targets.update(unittests[misc_target]["scons_test_targets"])

for target in actual_targets:
    print(target)
