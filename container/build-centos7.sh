#!/bin/bash -e

if ! yum info jq ; then
  yum -y install epel-release
fi

if [ -f /etc/yum.repos.d/pip.conf ] ; then
  mv /etc/yum.repos.d/pip.conf /etc/
fi

# NOTE: pin nss version due to bug https://bugzilla.redhat.com/show_bug.cgi?id=1896808
yum -y update -x nss*
yum -y downgrade nss*

curl --retry 3 --retry-delay 10 ${SITE_MIRROR:-"https://bootstrap.pypa.io"}/pip/2.7/get-pip.py | python2 - 'pip==20.1'

sclo=0
if ! yum repolist | grep -q "centos-sclo-rh" ; then
  sclo=1
  yum -y install centos-release-scl
fi
yum -y install \
  python3 iproute devtoolset-7-gcc devtoolset-7-binutils \
  autoconf automake createrepo docker-client docker-python gdb git git-review jq libtool \
  make python-devel python-lxml rpm-build vim wget yum-utils redhat-lsb-core \
  rpmdevtools sudo gcc-c++ net-tools httpd \
  python-virtualenv python-future python-tox \
  elfutils-libelf-devel
yum clean all
rm -rf /var/cache/yum
if [[ "$sclo" == '1' ]]; then
  yum -y remove centos-release-scl
  rm -rf /var/cache/yum /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo
fi

pip3 install --retries=10 --timeout 200 --upgrade tox setuptools lxml jinja2
# NOTE: we have to remove /usr/local/bin/virtualenv after installing tox by python3 because it has python3 as shebang and masked
# /usr/bin/virtualenv with python2 shebang. it can be removed later when all code will be ready for python3
rm -f /usr/local/bin/virtualenv

echo export CONTRAIL=$CONTRAIL >> $HOME/.bashrc
echo export LD_LIBRARY_PATH=$CONTRAIL/build/lib >> $HOME/.bashrc

wget -nv ${SITE_MIRROR:-"https://dl.google.com"}/go/go1.14.2.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.14.2.linux-amd64.tar.gz
rm -f go1.14.2.linux-amd64.tar.gz
echo export PATH=$PATH:/usr/local/go/bin >> $HOME/.bashrc
wget -nv ${SITE_MIRROR:-"https://github.com"}/operator-framework/operator-sdk/releases/download/v0.17.2/operator-sdk-v0.17.2-x86_64-linux-gnu -O /usr/local/bin/operator-sdk-v0.17
wget -nv ${SITE_MIRROR:-"https://github.com"}/operator-framework/operator-sdk/releases/download/v0.18.2/operator-sdk-v0.18.2-x86_64-linux-gnu -O /usr/local/bin/operator-sdk-v0.18
ln -s /usr/local/bin/operator-sdk-v0.18 /usr/local/bin/operator-sdk
chmod u+x /usr/local/bin/operator-sdk-v0.17 /usr/local/bin/operator-sdk-v0.18 /usr/local/bin/operator-sdk
