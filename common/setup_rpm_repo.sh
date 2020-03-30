#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common.sh
source ${scriptdir}/functions.sh

echo
echo '[setup rpm repo]'

CONTRAIL_DEPLOY_RPM_REPO=${CONTRAIL_DEPLOY_RPM_REPO:-1}
[[ "$CONTRAIL_DEPLOY_RPM_REPO" != 1 ]] && { echo "INFO: RPM repo deployment skipped" && exit ; }

if [ -z "${CONTRAIL_DIR}" ] ; then
  echo "ERROR: env variable CONTRAIL_DIR is required"\
  exit 1
fi

rpm_source="${CONTRAIL_DIR}/RPMS"
mkdir -p "$rpm_source"

if ! is_container_up "$RPM_CONTAINER_NAME" ; then 
  ensure_port_free ${RPM_REPO_PORT}

  if ! is_container_created "$RPM_CONTAINER_NAME"; then
    mysudo docker run -t --name "$RPM_CONTAINER_NAME" \
      -d -p ${RPM_REPO_PORT}:80 \
      -v ${rpm_source}:/var/www/localhost/htdocs:z \
      m4rcu5/lighttpd >/dev/null
    echo "$RPM_CONTAINER_NAME created"
  else
    echo "$(mysudo docker start $RPM_CONTAINER_NAME) started"
  fi

else
    echo "$RPM_CONTAINER_NAME already running."
fi

echo
echo '[read rpm repo ip from docker container properties]'
for ((i=0; i<10; ++i)); do
  rpm_repo_ip=$(mysudo docker inspect --format '{{ .NetworkSettings.Gateway }}' "$RPM_CONTAINER_NAME")
  if [[ -n "$rpm_repo_ip" ]]; then
    break
  fi
  sleep 2
done
if [[ -z "$rpm_repo_ip" ]]; then
  echo "ERROR: failed to obtain IP of local RPM repository"
  mysudo docker ps -a
  mysudo docker logs "$RPM_CONTAINER_NAME"
  exit 1
fi
echo "rpm repo ip $rpm_repo_ip"

export RPM_REPO_IP=$rpm_repo_ip
save_tf_devenv_profile
