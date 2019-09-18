#!/bin/bash -x


# REDHAT EL 8 is implemented over podman instead pf docker

set -o nounset
set -o errexit

scriptdir=$(realpath $(dirname "$0"))
cd "$scriptdir"
setup_only=0
own_vm=0
#IMAGE=${IMAGE:-"opencontrailnightly/developer-sandbox"}
IMAGE=${IMAGE:-"opencontrail/developer-sandbox"}
DEVENVTAG=${DEVENVTAG:-"latest"}
options="-e LC_ALL=en_US.UTF-8 -e LANG=en_US.UTF-8 -e LANGUAGE=en_US.UTF-8 "
log_path=""

# Python interpriter
PYTHON_EXEC=$(which python || which python2 || which python3)

# variables that can be redefined outside

AUTOBUILD=${AUTOBUILD:-0}
BUILD_DEV_ENV=${BUILD_DEV_ENV:-0}
BUILD_DEV_ENV_ON_PULL_FAIL=${BUILD_DEV_ENV_ON_PULL_FAIL:-0}
SRC_ROOT=${SRC_ROOT:-}
EXTERNAL_REPOS=${EXTERNAL_REPOS:-/root/src}
REGISTRY_PORT=${REGISTRY_PORT:-6666}
REGISTRY_IP=${REGISTRY_IP:-}
BUILD_TEST_CONTAINERS=${BUILD_TEST_CONTAINERS:-0}
CANONICAL_HOSTNAME=${CANONICAL_HOSTNAME:-"review.opencontrail.org"}
SITE_MIRROR=${SITE_MIRROR:-}

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

VNC_BRANCH="master"
if [[ "$DEVENVTAG" != "latest" ]]; then
  VNC_BRANCH="$DEVENVTAG"
fi

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
  yum install -y yum-utils device-mapper-persistent-data lvm2
  if ! yum info docker-ce &> /dev/null ; then
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  fi
  yum install -y docker-ce docker-ce-cli containerd.io
}

<<<<<<< HEAD
function install_docker_rhel() {
  subscription-manager repos \
    --enable rhel-7-server-extras-rpms \
    --enable rhel-7-server-optional-rpms
  yum install -y docker device-mapper-libs device-mapper-event-libs
}

=======
>>>>>>> Version to build and run RHEL8 containers
function check_docker_value() {
  local name=$1
  local value=$2
  if ! [ "$distro" == 'rhel' -a "$rhel_version_id" == "8.0" ]; then
    ${PYTHON_EXEC} -c "import json; f=open('/etc/docker/daemon.json'); data=json.load(f); print(data.get('$name'));" 2>/dev/null| grep -qi "$value"
  else
    podman info --format json | \
      ${PYTHON_EXEC} -c "import sys, json; data=json.load(sys.stdin); print(data.get('$name'));" 2>/dev/null| grep -qi "$value"
  fi
}

echo tf-dev-env startup
echo
echo '[docker install]'
distro=$(cat /etc/*release | egrep '^ID=' | awk -F= '{print $2}' | tr -d \")
echo $distro detected.
if [ x"$distro" == x"centos" ]; then
  which docker || install_docker
  systemctl start docker
  systemctl stop firewalld || true
  systemctl start docker
#  grep 'dm.basesize=20G' /etc/sysconfig/docker-storage || sed -i 's/DOCKER_STORAGE_OPTIONS=/DOCKER_STORAGE_OPTIONS=--storage-opt dm.basesize=20G /g' /etc/sysconfig/docker-storage
#  systemctl restart docker
elif [ x"$distro" == x"rhel" ]; then
  which docker || yum install -y docker
  rhel_version_id=$(grep '^VERSION_ID=' /etc/*release | awk -F= '{print $2}' | tr -d \")
elif [ x"$distro" == x"ubuntu" ]; then
  which docker || apt install -y docker.io
fi
if ! [ "$distro" == 'rhel' -a "$rhel_version_id" == "8.0" ]; then
  touch /etc/docker/daemon.json
fi

echo
echo '[docker setup]'
default_iface=`ip route get 1 | grep -o "dev.*" | awk '{print $2}'`
registry_ip=${REGISTRY_IP}
if [ -z $registry_ip ]; then
  # use default ip as registry ip if it's not passed to the script
  registry_ip=`ip addr show dev $default_iface | awk '/inet /{print $2}' | cut -f '1' -d '/'`
fi
defailt_iface_mtu=`ip link show $default_iface | grep -o "mtu.*" | awk '{print $2}'`

docker_reload=0

if ! [ "$distro" == 'rhel' -a "$rhel_version_id" == "8.0" ]; then
  if ! check_docker_value "insecure-registries" "${registry_ip}:${REGISTRY_PORT}" || ! check_docker_value mtu "$defailt_iface_mtu" || ! check_docker_value "live-restore" "true" ; then
    ${PYTHON_EXEC} <<EOF
  import json
  data=dict()
  try:
    with open("/etc/docker/daemon.json") as f:
      data = json.load(f)
  except Exception:
    pass
  data.setdefault("insecure-registries", list()).append("${registry_ip}:${REGISTRY_PORT}")
  data["mtu"] = $defailt_iface_mtu
  data["live-restore"] = True
  with open("/etc/docker/daemon.json", "w") as f:
    data = json.dump(data, f, sort_keys=True, indent=4)
EOF
    docker_reload=1
  fi
  runtime_docker_mtu=`sudo docker network inspect --format='{{index .Options "com.docker.network.driver.mtu"}}' bridge`
  if [[ "$defailt_iface_mtu" != "$runtime_docker_mtu" || "$docker_reload" == '1' ]]; then
    if [ x"$distro" == x"centos" ]; then
      systemctl restart docker
    elif [ x"$distro" == x"ubuntu" ]; then
      service docker reload
    fi
  fi
else #RHEL 8

  if ! check_docker_value "insecure registries" "${registry_ip}:${REGISTRY_PORT}" ; then
    ${PYTHON_EXEC}  <<EOF
conf_str=open("/etc/containers/registries.conf","r").read()
bi=conf_str.find( '[',  conf_str.find('registries', conf_str.find('[registries.insecure]') + len('[registries.insecure]') ) )
ei=conf_str.find( ']', bi )
print( conf_str[bi + 1:ei] )

if conf_str[bi + 1:ei].find("'") == -1:
  new_conf_str=conf_str[:bi + 1] + "'" + "${registry_ip}:${REGISTRY_PORT}" + "'" + conf_str[ei:]
else:
  new_conf_str=conf_str[:ei] + ", '" + "${registry_ip}:${REGISTRY_PORT}" + "'" + conf_str[ei:]

open("/etc/containers/registries.conf","w").write(new_conf_str)

EOF
  fi
fi
test "$setup_only" -eq 1 && exit

echo
echo '[environment setup]'
if [[ -n "${SRC_ROOT}" ]]; then
  rpm_source=${SRC_ROOT}/RPMS
  mkdir -p ${rpm_source}
  options="${options} -v ${SRC_ROOT}:/root/contrail -e SRC_MOUNTED=1"
elif [[ "$own_vm" -eq 0 ]]; then

  if ! [ "$distro" == 'rhel' -a "$rhel_version_id" == "8.0" ]; then
    rpm_source=$(docker volume create --name tf-dev-env-rpm-volume)
  else
    rpm_source=$(docker volume create  tf-dev-env-rpm-volume)
  fi 
  options="${options} -v ${rpm_source}:/root/contrail/RPMS"
else
  contrail_dir=$(realpath ${scriptdir}/../contrail)
  rpm_source=${contrail_dir}/RPMS
  mkdir -p ${rpm_source}
  options="${options} -v ${rpm_source}:/root/contrail/RPMS"
fi
<<<<<<< HEAD
rpm_source="${contrail_dir}/RPMS"
mkdir -p ${rpm_source}
echo "${rpm_source} created."
options="${options} -v ${EXTERNAL_REPOS}:${EXTERNAL_REPOS}"
=======
echo "${rpm_source} created."

if [[ -n "${EXTERNAL_REPOS}" ]]; then
  options="${options} -v ${EXTERNAL_REPOS}:/root/src"
fi

>>>>>>> Version to build and run RHEL8 containers
if ! is_created "tf-dev-env-rpm-repo"; then
  docker run -t --name tf-dev-env-rpm-repo \
    -d -p 6667:80 \
    -v ${rpm_source}:/var/www/localhost/htdocs \
    sebp/lighttpd >/dev/null
  echo tf-dev-env-rpm-repo created.
else
  if is_up "tf-dev-env-rpm-repo"; then
    echo "tf-dev-env-rpm-repo already running."
  else
    echo $(docker start tf-dev-env-rpm-repo) started.
  fi
fi

if ! is_created "tf-dev-env-registry"; then
  docker run --name tf-dev-env-registry \
    -d -p $REGISTRY_PORT:5000 \
    registry:2 >/dev/null
  echo tf-dev-env-registry created.
else
  if is_up "tf-dev-env-registry"; then
    echo "tf-dev-env-registry already running."
  else
    echo $(docker start tf-dev-env-registry) started.
  fi
fi

echo
echo '[configuration update]'
for ((i=0; i<3; ++i)); do
  rpm_repo_ip=$(docker inspect --format '{{ .NetworkSettings.Gateway }}' tf-dev-env-rpm-repo)
  if [[ -n "$rpm_repo_ip" ]]; then
    break
  fi
  sleep 10
done
if [[ -z "$rpm_repo_ip" ]]; then
  echo "ERROR: failed to obtain IP of local RPM repository"
  docker ps -a
  docker logs tf-dev-env-rpm-repo
  exit 1
fi

sed -e "s/rpm-repo/${rpm_repo_ip}/g" -e "s/registry/${registry_ip}/g" -e "s/6666/${REGISTRY_PORT}/g" common.env.tmpl > common.env
echo "INFO: common.env content:"
cat common.env
sed -e "s/rpm-repo/${rpm_repo_ip}/g" -e "s/contrail-registry/${registry_ip}/g" -e "s/6666/${REGISTRY_PORT}/g" vars.yaml.tmpl > vars.yaml
sed -e "s/rpm-repo/${rpm_repo_ip}/g" -e "s/registry/${registry_ip}/g" dev_config.yaml.tmpl > dev_config.yaml

if [[ "$own_vm" == '0' ]]; then
  if ! is_created "tf-developer-sandbox"; then
    if [[ "$BUILD_TEST_CONTAINERS" == "1" ]]; then
      options="${options} -e BUILD_TEST_CONTAINERS=1"
    fi

    if [[ -n "${CANONICAL_HOSTNAME}" ]]; then
      options="${options} -e CANONICAL_HOSTNAME=${CANONICAL_HOSTNAME}"
    fi

    if [[ -n "${SITE_MIRROR}" ]]; then
      options="${options} -e SITE_MIRROR=${SITE_MIRROR}"
    fi

    if [[ "${AUTOBUILD}" == '1' ]]; then
      options="${options} -t -e AUTOBUILD=1"
      timestamp=$(date +"%d_%m_%Y__%H_%M_%S")
      log_path="/${HOME}/build_${timestamp}.log"
    else
      options="${options} -itd"
    fi

    if [[ "$BUILD_DEV_ENV" != '1' ]] && ! docker image inspect --format='{{.Id}}' ${IMAGE}:${DEVENVTAG} && ! docker pull ${IMAGE}:${DEVENVTAG}; then
      if [[ "$BUILD_DEV_ENV_ON_PULL_FAIL" != '1' ]]; then
        exit 1
      fi
      echo Failed to pull ${IMAGE}:${DEVENVTAG}. Trying to build image.
      BUILD_DEV_ENV=1
    fi

    if [[ "$BUILD_DEV_ENV" == '1' ]]; then
      echo Build ${IMAGE}:${DEVENVTAG} docker image
      if [[ -d ${scriptdir}/config/etc/yum.repos.d ]]; then
        cp -f ${scriptdir}/config/etc/yum.repos.d/* ${scriptdir}/container/
      fi
      cd ${scriptdir}/container
      ./build.sh -i ${IMAGE} -b ${VNC_BRANCH} ${DEVENVTAG}
      cd ${scriptdir}
    fi

    if ! [ "$distro" == 'rhel' -a "$rhel_version_id" == "8.0" ]; then
      volumes="-v /var/run/docker.sock:/var/run/docker.sock"
    else
      volumes=""
    fi
    volumes+=" -v ${scriptdir}:/root/tf-dev-env"
    volumes+=" -v ${scriptdir}/container/entrypoint.sh:/root/entrypoint.sh"
    if [[ -d "${scriptdir}/config" ]]; then
      volumes+=" -v ${scriptdir}/config:/config"
    fi
    start_sandbox_cmd="docker run --privileged --name tf-developer-sandbox \
      -w /root ${options} \
      -e CONTRAIL_DEV_ENV=/root/tf-dev-env \
      $volumes \
      ${IMAGE}:${DEVENVTAG}"

    if [[ -z "${log_path}" ]]; then
      eval $start_sandbox_cmd &>/dev/null
    else
      eval $start_sandbox_cmd |& tee ${log_path}
    fi

    if [[ "${AUTOBUILD}" == '1' ]]; then
      exit_code=$(docker inspect tf-developer-sandbox --format='{{.State.ExitCode}}')
      echo Build has compeleted with exit code $exit_code
      exit $exit_code
    else
      echo tf-developer-sandbox created.
    fi
  else
    if is_up "tf-developer-sandbox"; then
      echo "tf-developer-sandbox already running."
    else
      echo $(docker start tf-developer-sandbox) started.
    fi
  fi
fi

echo
echo '[READY]'
test "$own_vm" -eq 0 && echo "You can now connect to the sandbox container by using: $ docker attach tf-developer-sandbox"
