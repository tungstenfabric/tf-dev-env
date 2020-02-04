#!/bin/bash
#TODO:
#What to collect size, rpms, pip2,pip3 count, size of the most biggest layers, count of layers
#1. Create list of containers to compare
#2. Note that you need to define the repository
JUNIPER_REPO=${JUNIPER_REPO:-"opencontrailnightly"}
JUNIPER_TAG=${JUNIPER_TAG:-"2003-latest"}
TF_LOCAL_REPO=${TF_LOCAL_REPO:-"localhost:5000"}
TF_LOCAL_TAG=${TF_LOCAL_TAG:-"dev"}
#3. Get the table with size and image name
#image_name from_source_size rpm_size