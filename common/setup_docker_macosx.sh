#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common.sh
source ${scriptdir}/functions.sh

echo
echo '[docker install]'
if ! which docker >/dev/null 2>&1 ; then
    brew install docker
else
  echo "docker installed: $(docker --version)"
fi

echo docker ps > /dev/null 2>&1
if [[ $? != 0 ]]; then
  echo "Please start Docker Deskop (Docker.app) before to continue..."
  exit 1
fi

echo
echo '[docker config]'
default_iface=`route get 1 | grep interface | awk  '{print $2}'`
registry_ip=${REGISTRY_IP}
if [ -z $registry_ip ]; then
  # use default ip as registry ip if it's not passed to the script
  registry_ip=`ifconfig $default_iface | grep 'inet ' | awk '{print $2}'`
fi
default_iface_mtu=`ifconfig $default_iface | grep 'mtu ' | awk '{print $4}'`

# TODO: docker config like we have for GNU/Linux related distro.

echo "REGISTRY_IP: $registry_ip"
