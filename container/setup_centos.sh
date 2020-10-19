#!/bin/bash -e

# userspace-rcu has a conflict (epel vs tpc repo), golang RPM conflict with third-party package
yum -y remove userspace-rcu golang golang-bin golang-src

if ! yum info jq ; then yum -y install epel-release ; fi
yum -y update

# get python2 pip, but reinstall python3-pip if present because get-pip.py breaks it.
curl --retry 3 --retry-delay 10 https://bootstrap.pypa.io/get-pip.py | python2 - 'pip==20.1'
yum -y reinstall python3-pip || true

# install packages required for build that may be missing
yum -y install python3 python3-pip iproute \
               autoconf automake createrepo docker-python gcc gdb git git-review jq libtool \
               make python-devel python-lxml rpm-build vim wget yum-utils redhat-lsb-core \
               rpmdevtools sudo gcc-c++ net-tools httpd \
               python-virtualenv python-future python-tox \
               google-chrome-stable \
               elfutils-libelf-devel \
               rsync PyYAML bind-utils

# Install docker and clean up yum if docker is missing.
# This allows installing on a host with a newer docker.
# This will be true when building a container.
if ! which docker; then
  yum -y install docker-client
  yum clean all
  rm -rf /var/cache/yum
fi
pip3 install --retries=10 --timeout 200 --upgrade tox setuptools lxml jinja2 yq

# NOTE: we have to remove /usr/local/bin/virtualenv after installing tox by python3 because it has python3 as shebang and masked
# /usr/bin/virtualenv with python2 shebang. it can be removed later when all code will be ready for python3
rm -f /usr/local/bin/virtualenv
