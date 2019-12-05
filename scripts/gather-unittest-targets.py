import json
import os
import requests


def convert_path(path):
    if "/contrail-sandesh/" in path  :
        path= path.replace("/contrail-sandesh/" ,"tools/sandesh" )
    elif "/contrail-generateDS/" in path  :
        path= path.replace("/contrail-generateDS/" ,"tools/generateds" )
    elif "/contrail-vrouter/" in path  :
        path= path.replace("/contrail-vrouter/" ,"vrouter" )
    elif "/contrail-common/" in path  :
        path= path.replace("/contrail-common/" ,"src/contrail-common" )
    elif "/contrail-analytics/" in path  :
        path= path.replace("/contrail-analytics/" ,"src/contrail-analytics" )
    elif "/contrail-sandesh/" in path  :
        path= path.replace("/contrail-api-client/" ,"src/contrail-api-client" )
    else:
        path = "controller/" + path
    return path


change_number=os.getenv("GERRIT_CHANGE_NUMBER")
patchset=os.getenv("GERRIT_PATCHSET")
project = os.getenv("GERRIT_PROJECT").replace("/","%2F")
URL = f"https://review.opencontrail.org/%2F{project}~{change_number}/revisions/{patchset}/files"

r = requests.get(url = URL )
response = ""
for valid_json in open("test"):
# for valid_json in r.iter_lines():
#     valid_json = valid_json.decode("utf-8")
    if valid_json != ")]}'":
        response+=valid_json
json_files = json.loads(response)
files = []
for key in json_files.keys():
    if key != "/COMMIT_MSG":
        files.append(key)

unittests = json.load(open("/root/contrail/controller/ci_unittests.json"))
actual_targets = set()
# TODO refactor this
for file in files:
    vnc_file = convert_path(file)
    for package in unittests.keys():
        for sd in unittests[package]["source_directories"]:
            if sd in vnc_file:
                for target in unittests[package]["scons_test_targets"]: actual_targets.add(target)
output_file =open("/root/tf-dev-env")
for target in actual_targets:
    print(target)


