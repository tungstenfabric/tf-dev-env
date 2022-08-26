#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common.sh
source ${scriptdir}/functions.sh

ensure_root

function retry() {
  local i
  for ((i=0; i<5; ++i)) ; do
    if $@ ; then
      break
    fi
    sleep 5
  done
  if [[ $i == 5 ]]; then
    return 1
  fi
}

function install_docker_ubuntu() {
  export DEBIAN_FRONTEND=noninteractive
  which docker && return
  apt-get update
  apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  add-apt-repository -y -u "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  retry apt-get install -y "docker-ce=18.06.3~ce~3-0~ubuntu"
}

function install_docker_centos() {
  which docker && return
  yum install -y yum-utils device-mapper-persistent-data lvm2
  if ! yum info docker-ce &> /dev/null ; then
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  fi
  retry yum install -y docker-ce-18.03.1.ce
}

function install_docker_rhel_7() {
  which docker && return
  if [[ "$ENABLE_RHSM_REPOS" == "true" ]]; then
    subscription-manager repos \
      --enable rhel-7-server-extras-rpms \
      --enable rhel-7-server-optional-rpms
  fi
  retry yum install -y docker device-mapper-libs device-mapper-event-libs
  systemctl start docker
}

function install_docker_rhel_8() {
  which podman && return
  if [[ "$ENABLE_RHSM_REPOS" == "true" ]]; then
    subscription-manager repos \
      --enable rhel-8-server-extras-rpms \
      --enable rhel-8-server-optional-rpms
  fi
  echo "INFO: dnf disable modules container-tools"
  dnf module disable -y container-tools || true
  declare -A ct_vers=(["8.2"]="2.0" ["8.4"]="3.0")
  echo "INFO: dnf enable container-tools:${ct_vers[$DISTRO_VER]}"
  dnf module enable -y container-tools:${ct_vers[$DISTRO_VER]}
  retry dnf install -y podman-docker podman device-mapper-libs device-mapper-event-libs
  touch /etc/containers/nodocker
  sed -i 's/.*image_default_format.*/image_default_format = "v2s2"/g' /usr/share/containers/containers.conf
  sed -i 's/.*image_build_format.*/image_build_format = "docker"/g' /usr/share/containers/containers.conf
}

declare -A install_docker_rhel=(
  ['7.8']=install_docker_rhel_7
  ['7.9']=install_docker_rhel_7
  ['8.2']=install_docker_rhel_8
  ['8.4']=install_docker_rhel_8
)

function check_docker_value() {
  local name=$1
  local value=$2
  python -c "import json; f=open('/etc/docker/daemon.json'); data=json.load(f); print(data.get('$name'));" 2>/dev/null| grep -qi "$value"
}

function check_insecure_registry() {
  case ${DISTRO}_${DISTRO_VER} in
    rhel_8.2|rhel_8.4)
        grep -A 1 '\[registries.insecure\]' /etc/containers/registries.conf | \
          grep -o 'registries[ ]*='.* | cut -d '=' -f 2 | \
          jq -cr '.[]' | \
          grep -q "^$1$"
      ;;
    *)
      check_docker_value "insecure-registries" "$1"
      ;;
  esac
}

function update_config_docker() {
  local insecure_registries="$1"
  local default_iface_mtu="$2"
  case ${DISTRO}_${DISTRO_VER} in
    rhel_8.2|rhel_8.4)
      local cf="/etc/containers/registries.conf"
      echo "INFO: update insecure registries in config $cf"
      local ir
      local cr=$(grep -A 1 '\[registries.insecure\]' $cf \
        | grep -o 'registries[ ]*='.* | cut -d '=' -f 2 \
        | jq -c ".")
      for ir in ${insecure_registries//,/ } ; do
        cr=$(echo "$cr" | jq -c ". += [ \"$ir\" ]")
      done
      cp $cf ${cf}.bkp
      awk "{ if (s==1) {s=0; print(\"registries = ${cr//\"/\\\"}\")} else if (\$1==\"[registries.insecure]\") {print(\$0); s=1} else {print(\$0)} }" $cf > ${cf}.tf
      mv ${cf}.tf $cf
      local pcf="/etc/cni/net.d/87-podman-bridge.conflist"
      echo "INFO: update mtu in $pcf"
      python <<EOF
import json
data = dict()
conf = "$pcf"
try:
  with open(conf) as f:
    data = json.load(f)
    for d in data["plugins"]:
      if d["type"] == "bridge" and d["bridge"] == "cni-podman0":
        d["mtu"] = $default_iface_mtu
except Exception as e:
  print("ERROR: failed to update mtu in %s: %s" % (conf, e))
  import sys
  sys.exit(1)
with open(conf, "w") as f:
  data = json.dump(data, f, sort_keys=True, indent=4)
EOF
      ;;
    *)
      [ ! -e /etc/docker/daemon.json ] && touch /etc/docker/daemon.json
      python <<EOF
import json
data=dict()
try:
  with open("/etc/docker/daemon.json") as f:
    data = json.load(f)
except Exception:
  pass
if "$UPDATE_INSECURE_REGISTRY" == "true":
  data.setdefault("insecure-registries", list())
  for i in "$insecure_registries".split(','):
    if i not in data["insecure-registries"]:
      data["insecure-registries"].append(i)
data["mtu"] = $default_iface_mtu
data["live-restore"] = True
with open("/etc/docker/daemon.json", "w") as f:
  data = json.dump(data, f, sort_keys=True, indent=4)
EOF
      ;;
  esac
}

function get_docker_mtu() {
  case ${DISTRO}_${DISTRO_VER} in
    rhel_8.2|rhel_8.4)
      jq -cr '.plugins[] | select(.type == "bridge") | select(.bridge == "cni-podman0") | .mtu' /etc/cni/net.d/87-podman-bridge.conflist | grep -v null || true
      ;;
    *)
      docker network inspect --format='{{index .Options "com.docker.network.driver.mtu"}}' bridge
      ;;
  esac
}

function set_docker_mtu() {
  local default_iface_mtu=$1
  echo "INFO: set docker0 mtu to $default_iface_mtu"
  case ${DISTRO}_${DISTRO_VER} in
    rhel_8.2|rhel_8.4)
      echo "INFO: rhel8.x - nothing to do to podman"
      ;;
    *)
      if [ -x "$(command -v ifconfig)" ]; then
          ifconfig docker0 mtu $default_iface_mtu || true
      else
          ip link set dev docker0 mtu $default_iface_mtu || true
      fi
      ;;
  esac
}
function restart_docker() {
  echo "INFO: restart docker"
  if [ x"$DISTRO" == x"centos" ] ; then
    systemctl restart docker
  elif [ x"$DISTRO" == x"rhel" ] ; then
    if [ ! "${DISTRO_VER}" =~ "8." ]; then
      systemctl restart docker
    else
      echo "INFO: restart docker skipped - no docker in ${DISTRO_VER}"
    fi
  elif [ x"$DISTRO" == x"ubuntu" ]; then
    service docker reload
  else
    echo "ERROR: unknown distro $DISTRO"
    exit 1
  fi
}

echo ""
echo "INFO: [docker install]"
echo "INFO: $DISTRO detected"
if ! which docker >/dev/null 2>&1 ; then
  if [ x"$DISTRO" == x"centos" ]; then
    systemctl stop firewalld || true
    install_docker_centos
    systemctl start docker
  #  grep 'dm.basesize=20G' /etc/sysconfig/docker-storage || sed -i 's/DOCKER_STORAGE_OPTIONS=/DOCKER_STORAGE_OPTIONS=--storage-opt dm.basesize=20G /g' /etc/sysconfig/docker-storage
  #  systemctl restart docker
  elif [ x"$DISTRO" == x"rhel" ]; then
    systemctl stop firewalld || true
    ${install_docker_rhel[$DISTRO_VER]}
  elif [ x"$DISTRO" == x"ubuntu" ]; then
    install_docker_ubuntu
  fi
else
  echo "INFO: docker installed: $(docker --version)"
  if [ x"$DISTRO" != x"rhel" ]; then
    version=$(docker version --format '{{.Client.Version}}' 2>/dev/null | head -1 | cut -d '.' -f 1)
    if (( version < 16)); then
      echo "ERROR: docker is too old. please remove it. tf-dev-env will install correct version."
      exit 1
    fi
  fi
fi


echo
echo "INFO: [docker config]"
default_iface=`ip route get 1 | grep -o "dev.*" | awk '{print $2}'`

CONTRAIL_SKIP_INSECURE_REGISTRY=${CONTRAIL_SKIP_INSECURE_REGISTRY:-0}
insecure_registries=${INSECURE_REGISTRIES:-}
registry_ip=${REGISTRY_IP}
UPDATE_INSECURE_REGISTRY=false
if [ "$CONTRAIL_SKIP_INSECURE_REGISTRY" != 0 ]; then
  echo "INFO: Docker config - setting insecure registry skipped"
else
  if [ -z $registry_ip ]; then
    # use default ip as registry ip if it's not passed to the script
    registry_ip=`ip addr show dev $default_iface | awk '/inet /{print $2}' | cut -f '1' -d '/'`
  fi
  if ! check_insecure_registry "${registry_ip}:${REGISTRY_PORT}" ; then
    if [ -n "$insecure_registries" ] ; then
      insecure_registries+=","
    fi
    insecure_registries+="${registry_ip}:${REGISTRY_PORT}"
  fi
fi
if [ -n "$insecure_registries" ] ; then
  UPDATE_INSECURE_REGISTRY=true
fi

default_iface_mtu=`ip link show $default_iface | grep -o "mtu.*" | awk '{print $2}'`

docker_reload=0
if $UPDATE_INSECURE_REGISTRY || ! check_docker_value mtu "$default_iface_mtu" || ! check_docker_value "live-restore" "true" ; then
  update_config_docker "$insecure_registries" "$default_iface_mtu"
  docker_reload=1
else
  echo "INFO: no config changes required"
fi

runtime_docker_mtu=$(get_docker_mtu)
if [[ "$default_iface_mtu" != "$runtime_docker_mtu" || "$docker_reload" == '1' ]]; then
  set_docker_mtu $default_iface_mtu
  restart_docker
else
  echo "INFO: no docker service restart required"
fi

echo "REGISTRY_IP: $registry_ip"
