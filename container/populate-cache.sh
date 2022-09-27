#!/bin/bash -e

if ! which wget; then
   echo "ERROR: wget is not found. please install it. exit"
   exit 1
fi

CACHE_DIR=${CACHE_DIR:-'/tmp/cache'}

mkdir -p $CACHE_DIR || true
pushd $CACHE_DIR

wget -nv -t3 -P pip/2.7 https://bootstrap.pypa.io/pip/2.7/get-pip.py
wget -nv -t3 -P go https://dl.google.com/go/go1.14.2.linux-amd64.tar.gz
wget -nv -t3 -P operator-framework/operator-sdk/releases/download/v0.17.2 https://github.com/operator-framework/operator-sdk/releases/download/v0.17.2/operator-sdk-v0.17.2-x86_64-linux-gnu
wget -nv -t3 -P operator-framework/operator-sdk/releases/download/v0.18.2 https://github.com/operator-framework/operator-sdk/releases/download/v0.18.2/operator-sdk-v0.18.2-x86_64-linux-gnu

wget -nv -t3 -P el8/extras/x86_64 https://pkgs.dyn.su/el8/extras/x86_64/compat-openssl10-devel-1.0.2o-3.el8.x86_64.rpm
wget -nv -t3 -P pkgs/packages/compat-openssl10/1.0.2o/3.el8/x86_64 https://koji.mbox.centos.org/pkgs/packages/compat-openssl10/1.0.2o/3.el8/x86_64/compat-openssl10-debugsource-1.0.2o-3.el8.x86_64.rpm

#Upgrading git in centos7
#default git 1.18 causes fail (HTTP 402) in fetch-sources job when it's working with gitlab
wget -nv -t3 -P rhel/7/os/x86_64/git-core-2.37.1-1.ep7.x86_64.rpm https://packages.endpointdev.com/rhel/7/os/x86_64/git-core-2.37.1-1.ep7.x86_64.rpm
wget -nv -t3 -P rhel/7/os/x86_64/git-2.37.1-1.ep7.x86_64.rpm https://packages.endpointdev.com/rhel/7/os/x86_64/git-2.37.1-1.ep7.x86_64.rpm
wget -nv -t3 -P rhel/7/os/x86_64/git-core-doc-2.37.1-1.ep7.noarch.rpm https://packages.endpointdev.com/rhel/7/os/x86_64/git-core-doc-2.37.1-1.ep7.noarch.rpm
wget -nv -t3 -P rhel/7/os/x86_64/perl-Git-2.37.1-1.ep7.noarch.rpm https://packages.endpointdev.com/rhel/7/os/x86_64/perl-Git-2.37.1-1.ep7.noarch.rpm

popd
