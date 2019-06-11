#!/bin/bash

DE_ROOT=$(realpath $(dirname "$0")/..)
WORKDIR=$(realpath ${DE_ROOT}/..)
no_sandbox=0;
while getopts ":n" opt; do
  case $opt in
    n) no_sandbox=1;;
    \?) echo use -n to not clone the sandbox; exit1;;
  esac
done

echo using ${WORKDIR} as top-level directory

echo adding contrail-tpc repository
sudo tee /etc/yum.repos.d/tpc.repo << EOF
[contrail-tpc]
name=Third parties for Contrail
baseurl=http://148.251.5.90/tpc/
enabled=1
gpgcheck=0
EOF

echo installing reuquired packages
sudo yum -y update
sudo yum -y install \
  createrepo \
  docker \
  docker-python \
  epel-release \
  gcc \
  gdb \
  git \
  kernel \
  make \
  python-devel \
  python-pip \
  rpm-build \
  vim \
  wget \
  yum-utils

sudo ip uninstall -y urlli3 setuptools
sudo yum reinstall -y python-setuptools

if [[ "$no_sandbox" -eq 1 ]]; then
  echo Not creating the sandbox, mount your own sandbox at ${WORKDIR}/contrail
else

  echo Creating directory ${WORKDIR}/contrail...
  mkdir -p ${WORKDIR}/contrail

  echo downloading repo tool...
  curl -s https://storage.googleapis.com/git-repo-downloads/repo > /tmp/repo \
    && sudo cp /tmp/repo /usr/bin/repo \
    && sudo chmod a+x /usr/bin/repo

  echo configuring  git
  git config --get user.email || git config --global user.email "${USER}@${HOSTNAME}"
  git config --get user.name  || git config --global user.name "${USER}"
  git config --get color.ui   || git config --global color.ui auto

  echo initializing sandbox...
  cd ${WORKDIR}/contrail

  test -d ${WORKDIR}/contrail/.repo || repo init --no-clone-bundle -q -u https://github.com/Juniper/contrail-vnc
  repo sync --no-clone-bundle -q -j $(($(nproc)*2 ))

fi

echo Sandbox directory: ${WORKDIR}/contrail
echo dev-env directory: ${WORKDIR}/tf-dev-env
echo
echo "use [sudo] tf-dev-env/startup.sh -b to run dev-env without tf-developer-sandbox container"
echo
