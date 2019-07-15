#!/bin/bash -e
BRANCH=master
IMAGE=opencontrail/developer-sandbox

while getopts ":b:i:" opt; do
    case $opt in
      b) BRANCH=$OPTARG
         ;;
      i) IMAGE=$OPTARG
         ;;
      \?) echo "Invalid option: $opt"; exit 1;;
    esac
done

shift $((OPTIND-1))

TAG=${1:-latest}
echo Building tf-dev-env image: ${IMAGE}:${TAG}
cp ../tpc.repo.template tpc.repo
docker build --build-arg LC_ALL=en_US.UTF-8 --build-arg LANG=en_US.UTF-8 --build-arg LANGUAGE=en_US.UTF-8 --build-arg BRANCH=${BRANCH} --no-cache --tag ${IMAGE}:${TAG} .
