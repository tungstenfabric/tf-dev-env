#!/usr/bin/env python

import json
import sys
import os
from xml.etree import ElementTree


patchsets = json.load(sys.stdin)

home_dir = os.getenv("HOME", '/root')
with open("%s/contrail/controller/ci_unittests.json" % home_dir, 'r') as fh:
    unittests = json.load(fh)

# load vnc structure to evaluate UT targets
# stdin is a patchsets_info.json file wich has gerrit plain structure
# ci_unittests.json has vnc structure
with open("%s/contrail/.repo/manifest.xml" % home_dir, 'r') as f:
    vnc_raw = ElementTree.parse(f).getroot()
remotes = dict()
for remote in vnc_raw.findall(".//remote"):
    remotes[remote.get('name')] = remote.get('fetch').split('/')[-1]
projects = dict()
for project in vnc_raw.findall(".//project"):
    projects[remotes[project.get('remote')] + '/' + project.get('name')] = project.get('path')

review_files = set()
for patchset in patchsets:
    if patchset["project"] not in projects:
        continue
    path = projects[patchset["project"]]
    review_files.update([path + '/' + file for file in patchset["files"]])

actual_targets = set()
misc_targets = set()
for ffile in review_files:
    for package in unittests.keys():
        for sd in unittests[package]["source_directories"]:
            if sd in ffile:
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
