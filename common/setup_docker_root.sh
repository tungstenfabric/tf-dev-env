#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common.sh
source ${scriptdir}/functions.sh

ensure_root

function install_docker_ubuntu() {
  export DEBIAN_FRONTEND=noninteractive
  which docker && return
  apt-get update
  apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  add-apt-repository -y -u "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  apt-get install -y "docker-ce=18.06.3~ce~3-0~ubuntu"
}

function install_docker_centos() {
  which docker && return
  yum install -y yum-utils device-mapper-persistent-data lvm2
  if ! yum info docker-ce &> /dev/null ; then
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  fi
  yum install -y docker-ce-18.03.1.ce
}

function install_docker_rhel() {
  which docker && return
  if [[ "$ENABLE_RHSM_REPOS" == "0" ]]; then
    subscription-manager repos \
      --enable rhel-7-server-extras-rpms \
      --enable rhel-7-server-optional-rpms
  fi
  yum install -y docker device-mapper-libs device-mapper-event-libs
}

function check_docker_value() {
  local name=$1
  local value=$2
  python -c "import json; f=open('/etc/docker/daemon.json'); data=json.load(f); print(data.get('$name'));" 2>/dev/null| grep -qi "$value"
}

echo
echo '[docker install]'
echo "$DISTRO detected"
if ! which docker >/dev/null 2>&1 ; then
  if [ x"$DISTRO" == x"centos" ]; then
    systemctl stop firewalld || true
    install_docker_centos
    systemctl start docker
  #  grep 'dm.basesize=20G' /etc/sysconfig/docker-storage || sed -i 's/DOCKER_STORAGE_OPTIONS=/DOCKER_STORAGE_OPTIONS=--storage-opt dm.basesize=20G /g' /etc/sysconfig/docker-storage
  #  systemctl restart docker
  elif [ x"$DISTRO" == x"rhel" ]; then
    systemctl stop firewalld || true
    install_docker_rhel
    systemctl start docker
    # Apply workaround for contrail-build-containers
    docker pull registry.redhat.io/rhel7:latest
    docker tag registry.redhat.io/rhel7:latest rhel7:latest
  elif [ x"$DISTRO" == x"ubuntu" ]; then
    install_docker_ubuntu
  fi
else
  echo "docker installed: $(docker --version)"
fi


echo
echo '[docker config]'
default_iface=`ip route get 1 | grep -o "dev.*" | awk '{print $2}'`
registry_ip=${REGISTRY_IP}
if [ -z $registry_ip ]; then
  # use default ip as registry ip if it's not passed to the script
  registry_ip=`ip addr show dev $default_iface | awk '/inet /{print $2}' | cut -f '1' -d '/'`
fi
default_iface_mtu=`ip link show $default_iface | grep -o "mtu.*" | awk '{print $2}'`

docker_reload=0
[ ! -e /etc/docker/daemon.json ] && touch /etc/docker/daemon.json
if ! check_docker_value "insecure-registries" "${registry_ip}:${REGISTRY_PORT}" || ! check_docker_value mtu "$default_iface_mtu" || ! check_docker_value "live-restore" "true" ; then
  python <<EOF
import json
data=dict()
try:
  with open("/etc/docker/daemon.json") as f:
    data = json.load(f)
except Exception:
  pass
data.setdefault("insecure-registries", list()).append("${registry_ip}:${REGISTRY_PORT}")
data["mtu"] = $default_iface_mtu
data["live-restore"] = True
with open("/etc/docker/daemon.json", "w") as f:
  data = json.dump(data, f, sort_keys=True, indent=4)
EOF
  docker_reload=1
else
  echo "no config changes required"
fi

runtime_docker_mtu=`docker network inspect --format='{{index .Options "com.docker.network.driver.mtu"}}' bridge`
if [[ "$default_iface_mtu" != "$runtime_docker_mtu" || "$docker_reload" == '1' ]]; then
  echo "set docker0 mtu to $default_iface_mtu"
  ifconfig docker0 mtu $default_iface_mtu || true
  echo 'restart docker'
  if [ x"$DISTRO" == x"centos" -o x"$DISTRO" == x"rhel" ]; then
    systemctl restart docker
  elif [ x"$DISTRO" == x"ubuntu" ]; then
    service docker reload
  else
    echo "ERROR: unknown distro $DISTRO"
    exit 1
  fi
else
  echo "no docker service restart required"
fi
echo "REGISTRY_IP: $registry_ip"
