#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common.sh
source ${scriptdir}/functions.sh

docker_cfg="$HOME/.docker/daemon.json"

function check_docker_value() {
  local name=$1
  local value=$2
  python -c "import json; f=open('$docker_cfg'); data=json.load(f); print(data.get('$name'));" 2>/dev/null| grep -qi "$value"
}

echo
echo "INFO: [docker install]"
if ! which docker >/dev/null 2>&1 ; then
    brew install docker
else
  echo "INFO: docker installed: $(docker --version)"
  version=$(docker version --format '{{.Client.Version}}' 2>/dev/null | head -1 | cut -d '.' -f 1)
  if (( version < 16)); then
    echo "ERROR: docker is too old. please remove it. tf-dev-env will install correct version."
    exit 1
  fi
fi

echo docker ps > /dev/null 2>&1
if [[ $? != 0 ]]; then
  echo "ERROR: Please start Docker Deskop (Docker.app) before to continue..."
  exit 1
fi

echo
echo "INFO: [docker config]"
default_iface=`route get 1 | grep interface | awk  '{print $2}'`
registry_ip=${REGISTRY_IP}
if [ -z $registry_ip ]; then
  # use default ip as registry ip if it's not passed to the script
  registry_ip=`ifconfig $default_iface | grep 'inet ' | awk '{print $2}'`
fi
default_iface_mtu=`ifconfig $default_iface | grep 'mtu ' | awk '{print $4}'`

docker_reload=0
if ! check_docker_value "insecure-registries" "${registry_ip}:${REGISTRY_PORT}" || ! check_docker_value mtu "$default_iface_mtu" || ! check_docker_value "live-restore" "true" ; then
  python <<EOF
import json
data=dict()
try:
  with open("{$docker_cfg}") as f:
    data = json.load(f)
except Exception:
  pass
data.setdefault("insecure-registries", list()).append("${registry_ip}:${REGISTRY_PORT}")
data["mtu"] = $default_iface_mtu
data["live-restore"] = True
with open("${docker_cfg}", "w") as f:
  data = json.dump(data, f, sort_keys=True, indent=4)
EOF
  docker_reload=1
else
  echo "INFO: no config changes required"
fi

runtime_docker_mtu=`docker network inspect --format='{{index .Options "com.docker.network.driver.mtu"}}' bridge`
if [[ "$default_iface_mtu" != "$runtime_docker_mtu" || "$docker_reload" == '1' ]]; then
  echo "INFO: set docker0 mtu to $default_iface_mtu"
  ifconfig docker0 mtu $default_iface_mtu || true
  echo "INFO: Please restart Docker Desktop."
else
  echo "INFO: no docker service restart required"
fi

echo "REGISTRY_IP: $registry_ip"
