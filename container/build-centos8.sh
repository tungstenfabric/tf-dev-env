#!/bin/bash -e

if ! yum info git-review ; then
  yum -y install epel-release
fi

if [ -f /etc/yum.repos.d/pip.conf ] ; then
  mv /etc/yum.repos.d/pip.conf /etc/
fi

# to fix locale warning
yum install -y langpacks-en glibc-all-langpacks

yum -y install \
  python3 iproute autoconf automake createrepo gdb git git-review jq libtool \
  make python3-devel python3-lxml rpm-build vim wget yum-utils redhat-lsb-core \
  rpmdevtools sudo gcc-c++ net-tools httpd elfutils-libelf-devel \
  python3-virtualenv python3-future python3-tox \
  python2-devel python2 python2-setuptools
yum clean all
rm -rf /var/cache/yum

pip3 install --retries=10 --timeout 200 --upgrade tox setuptools lxml jinja2

echo export CONTRAIL=$CONTRAIL >> $HOME/.bashrc
echo export LD_LIBRARY_PATH=$CONTRAIL/build/lib >> $HOME/.bashrc

wget -nv ${SITE_MIRROR:-"https://dl.google.com"}/go/go1.14.2.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.14.2.linux-amd64.tar.gz
rm -f go1.14.2.linux-amd64.tar.gz
echo export PATH=$PATH:/usr/local/go/bin >> $HOME/.bashrc
wget -nv ${SITE_MIRROR:-"https://github.com"}/operator-framework/operator-sdk/releases/download/v0.17.2/operator-sdk-v0.17.2-x86_64-linux-gnu -O /usr/local/bin/operator-sdk
chmod u+x /usr/local/bin/operator-sdk

# this is required to compile boost-1.53 from tpp
alternatives --verbose --set python /usr/bin/python2
