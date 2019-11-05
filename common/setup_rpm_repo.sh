#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common.sh
source ${scriptdir}/functions.sh

[ $CONTRAIL_DEPLOY_RPM_REPO != 1 ] && { echo "INFO: RPM repo deployment skipped" && exit ; }

ensure_root

echo
echo '[setup rpm repo]'

if [ -z "${CONTRAIL_DIR}" ] ; then
  echo "ERROR: env variable CONTRAIL_DIR is required"\
  exit 1
fi

rpm_source="${CONTRAIL_DIR}/RPMS"

if [ ! -d "${rpm_source}" ] ; then
    echo "ERROR: ${rpm_source} does not exist. Run setup_sources.sh first."
    exit 1;
fi

is_container_up "$RPM_CONTAINER_NAME" && {
    echo "$RPM_CONTAINER_NAME already running."
    exit 0  
}

ensure_port_free 80

if ! is_container_created "$RPM_CONTAINER_NAME"; then
  docker run -t --name "$RPM_CONTAINER_NAME" \
    -d -p ${RPM_REPO_PORT}:80 \
    -v ${rpm_source}:/var/www/localhost/htdocs \
    m4rcu5/lighttpd >/dev/null
  echo "$RPM_CONTAINER_NAME created"
else
  echo "$(docker start $RPM_CONTAINER_NAME) started"
fi

echo
echo '[read rpm repo ip from docker container properties]'
for ((i=0; i<10; ++i)); do
  rpm_repo_ip=$(docker inspect --format '{{ .NetworkSettings.Gateway }}' "$RPM_CONTAINER_NAME")
  if [[ -n "$rpm_repo_ip" ]]; then
    break
  fi
  sleep 2
done
if [[ -z "$rpm_repo_ip" ]]; then
  echo "ERROR: failed to obtain IP of local RPM repository"
  docker ps -a
  docker logs "$RPM_CONTAINER_NAME"
  exit 1
fi
echo "rpm repo ip $rpm_repo_ip"

export RPM_REPO_IP=$rpm_repo_ip
update_tf_devenv_profile
