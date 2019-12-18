#!/bin/bash -ex

scriptdir=$(realpath $(dirname "$0"))

workspace=/root/contrail
cd $workspace
logs_path='/root/contrail/logs'
mkdir -p "$logs_path"

# Ensure that hostname is in /etc/hosts
host_name=`hostname`
host_ip=`hostname -i`
if ! grep -q "$host_ip $host_name" /etc/hosts; then
  echo $host_ip $host_name >> /etc/hosts
fi
# Add Google Chrome repo
cat <<EOF > /etc/yum.repos.d/Google-Chrome.repo
#Google-Chrome.repo

[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
gpgcheck=0
enabled=1
EOF

# Install the Development tools package group
yum install -y "@Development tools"

# Install additional packages used by unittest scripts
yum install -y nodejs-0.10.48 python-lxml wget google-chrome-stable

# Run unittest script
$scriptdir/contrail-webui-unittest.sh

res=$?
if [[ "$res" != '0' ]]; then
  echo "ERROR: some UT failed"
fi
echo "INFO: Unit test log is available at /root/contrail/logs/web_controller_unittests.log"
echo "INFO: Test report is available at  /root/contrail/logs/test-reports/web-controller-test-results.xml"
echo "INFO: Coverage report is available at /root/contrail/logs/coverage-reports/controller-cobertura-coverage.xml"
exit $res
