#!/bin/bash

set -o nounset
set -o errexit

scriptdir=$(realpath $(dirname "$0"))
cd "$scriptdir"
setup_only=0
own_vm=0
DEVENVTAG=latest
IMAGE=opencontrailnightly/developer-sandbox
options=""
log_path=""

# variables that can be redefined outside

AUTOBUILD=${AUTOBUILD:-0}
BUILD_DEV_ENV=${BUILD_DEV_ENV:-0}
SRC_ROOT=${SRC_ROOT:-}
EXTERNAL_REPOS=${EXTERNAL_REPOS:-}
REGISTRY_PORT=${REGISTRY_PORT:-6666}
REGISTRY_IP=${REGISTRY_IP:-}
BUILD_TEST_CONTAINERS=${BUILD_TEST_CONTAINERS:-0}
CANONICAL_HOSTNAME=${CANONICAL_HOSTNAME:-"review.opencontrail.org"}

while getopts ":t:i:sb" opt; do
  case $opt in
    i)
      IMAGE=$OPTARG
      ;;
    t)
      DEVENVTAG=$OPTARG
      ;;
    s)
      setup_only=1
      ;;
    b)
      own_vm=1
      ;;
    \?)
      echo "Invalid option: $opt"
      exit 1
      ;;
  esac
done

function is_created () {
  local container=$1
  docker ps -a --format '{{ .Names }}' | grep "$container" > /dev/null
  return $?
}

function is_up () {
  local container=$1
  docker inspect --format '{{ .State.Status }}' $container | grep "running" > /dev/null
  return $?
}

function install_docker() {
  (yum install -y yum-utils device-mapper-persistent-data lvm2 \
  && yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo \
  && yum install -y docker-ce docker-ce-cli containerd.io) \
  || (echo Failed to install docker with error $? && exit 1)
}

echo contrail-dev-env startup
echo
echo '[docker setup]'

distro=$(cat /etc/*release | egrep '^ID=' | awk -F= '{print $2}' | tr -d \")
echo $distro detected.
if [ x"$distro" == x"centos" ]; then
  which docker || install_docker
  systemctl start docker
  systemctl stop firewalld || true
  systemctl start docker
#  grep 'dm.basesize=20G' /etc/sysconfig/docker-storage || sed -i 's/DOCKER_STORAGE_OPTIONS=/DOCKER_STORAGE_OPTIONS=--storage-opt dm.basesize=20G /g' /etc/sysconfig/docker-storage
#  systemctl restart docker
elif [ x"$distro" == x"ubuntu" ]; then
  which docker || apt install -y docker.io
fi

test "$setup_only" -eq 1 && exit

echo
echo '[environment setup]'
if [[ ! -z "${SRC_ROOT}" ]]; then
  rpm_source=${SRC_ROOT}/RPMS
  mkdir -p ${rpm_source}
  options="${options} -v ${SRC_ROOT}:/root/contrail -e SRC_MOUNTED=1"
elif [[ "$own_vm" -eq 0 ]]; then
  rpm_source=$(docker volume create --name contrail-dev-env-rpm-volume)
  options="${options} -v ${rpm_source}:/root/contrail/RPMS"
else
  contrail_dir=$(realpath ${scriptdir}/../contrail)
  rpm_source=${contrail_dir}/RPMS
  mkdir -p ${rpm_source}
  options="${options} -v ${rpm_source}:/root/contrail/RPMS"
fi
echo "${rpm_source} created."

if [[ ! -z "${EXTERNAL_REPOS}" ]]; then
  options="${options} -v ${EXTERNAL_REPOS}:/root/src"
fi

if ! is_created "contrail-dev-env-rpm-repo"; then
  docker run --privileged --name contrail-dev-env-rpm-repo \
    -d -p 6667:80 \
    -v ${rpm_source}:/var/www/localhost/htdocs \
    sebp/lighttpd >/dev/null
  echo contrail-dev-env-rpm-repo created.
else
  if is_up "contrail-dev-env-rpm-repo"; then
    echo "contrail-dev-env-rpm-repo already running."
  else
    echo $(docker start contrail-dev-env-rpm-repo) started.
  fi
fi

if ! is_created "contrail-dev-env-registry"; then
  docker run --privileged --name contrail-dev-env-registry \
    -d -p $REGISTRY_PORT:5000 \
    registry:2 >/dev/null
  echo contrail-dev-env-registry created.
else
  if is_up "contrail-dev-env-registry"; then
    echo "contrail-dev-env-registry already running."
  else
    echo $(docker start contrail-dev-env-registry) started.
  fi
fi

echo
echo '[configuration update]'
rpm_repo_ip=$(docker inspect --format '{{ .NetworkSettings.Gateway }}' contrail-dev-env-rpm-repo)
registry_ip=${REGISTRY_IP}
if [ -z $registry_ip ]; then
  registry_ip=$(docker inspect --format '{{ .NetworkSettings.Gateway }}' contrail-dev-env-registry)
fi

sed -e "s/rpm-repo/${rpm_repo_ip}/g" -e "s/registry/${registry_ip}/g" -e "s/6666/${REGISTRY_PORT}/g" common.env.tmpl > common.env
sed -e "s/rpm-repo/${rpm_repo_ip}/g" -e "s/contrail-registry/${registry_ip}/g" -e "s/6666/${REGISTRY_PORT}/g" vars.yaml.tmpl > vars.yaml
sed -e "s/rpm-repo/${rpm_repo_ip}/g" -e "s/registry/${registry_ip}/g" dev_config.yaml.tmpl > dev_config.yaml
sed -e "s/registry/${registry_ip}/g" -e "s/6666/${REGISTRY_PORT}/g" daemon.json.tmpl > daemon.json

if [ x"$distro" == x"centos" ]; then
  if ! diff daemon.json /etc/docker/daemon.json; then
    cp daemon.json /etc/docker/daemon.json
    systemctl restart docker
    docker start contrail-dev-env-rpm-repo contrail-dev-env-registry
  fi
elif [ x"$distro" == x"ubuntu" ]; then
  diff daemon.json /etc/docker/daemon.json || (cp daemon.json /etc/docker/daemon.json && service docker reload)
fi

if [[ "$own_vm" -eq 0 ]]; then
  if ! is_created "contrail-developer-sandbox"; then
    if [[ "$BUILD_TEST_CONTAINERS" == "1" ]]; then
      options="${options} -e BUILD_TEST_CONTAINERS=1"
    fi

    if [[ ! -z "${CANONICAL_HOSTNAME}" ]]; then
      options="${options} -e CANONICAL_HOSTNAME=${CANONICAL_HOSTNAME}"
    fi

    if [[ "${AUTOBUILD}" -eq 1 ]]; then
      options="${options} -t -e AUTOBUILD=1"
      timestamp=$(date +"%d_%m_%Y__%H_%M_%S")
      log_path="/${HOME}/build_${timestamp}.log"
    else
      options="${options} -itd"
    fi

    if [[ x"$DEVENVTAG" == x"latest" ]]; then
      if [[ "$BUILD_DEV_ENV" -eq 1 ]]; then
        echo Build ${IMAGE}:${DEVENVTAG} docker image
        cd ${scriptdir}/container && ./build.sh -i ${IMAGE} ${DEVENVTAG}
        cd ${scriptdir}
      else
        docker pull ${IMAGE}:${DEVENVTAG}
      fi
    fi

    start_sandbox_cmd="docker run --privileged --name contrail-developer-sandbox \
      -w /root ${options} \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v ${scriptdir}:/root/contrail-dev-env \
      -e CONTRAIL_DEV_ENV=/root/contrail-dev-env \
      -v ${scriptdir}/container/entrypoint.sh:/root/entrypoint.sh \
      ${IMAGE}:${DEVENVTAG}"

    if [[ -z "${log_path}" ]]; then
      eval $start_sandbox_cmd &>/dev/null
    else
      eval $start_sandbox_cmd |& tee ${log_path}
    fi

    echo contrail-developer-sandbox created.
  else
    if is_up "contrail-developer-sandbox"; then
      echo "contrail-developer-sandbox already running."
    else
      echo $(docker start contrail-developer-sandbox) started.
    fi
  fi
fi

echo
echo '[READY]'
test "$own_vm" -eq 0 && echo "You can now connect to the sandbox container by using: $ docker attach contrail-developer-sandbox"
