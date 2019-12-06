#!/usr/bin/env python

import json
import os
import requests


def convert_path(path):
    if "contrail-sandesh/" in path:
        path = path.replace("contrail-sandesh/", "tools/sandesh/")
    elif "contrail-generateDS/" in path:
        path = path.replace("contrail-generateDS/", "tools/generateds/")
    elif "contrail-vrouter/" in path:
        path = path.replace("contrail-vrouter/", "vrouter/")
    elif "contrail-common/" in path:
        path = path.replace("contrail-common/", "src/contrail-common/")
    elif "contrail-analytics/" in path:
        path = path.replace("contrail-analytics/", "src/contrail-analytics/")
    elif "contrail-api-client/" in path:
        path = path.replace("contrail-api-client/", "src/contrail-api-client/")
    else:
        path = "controller/" + path
    return path


change_number = os.getenv("GERRIT_CHANGE_NUMBER")
patchset = os.getenv("GERRIT_PATCHSET_NUMBER")
project_fqdn = os.getenv("GERRIT_PROJECT").replace("/", "%2F")
project = os.getenv("GERRIT_PROJECT").split("/")[1]
url = "https://review.opencontrail.org/changes/{}~{}/revisions/{}/files".format(project_fqdn, change_number, patchset)

response = requests.get(url=url)
response.raise_for_status()
json_files = json.loads(response.content.decode("utf-8")[4:])
review_files = [project + '/' + key for key in json_files.keys() if key != "/COMMIT_MSG"]

with open("/root/contrail/controller/ci_unittests.json") as fh:
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
