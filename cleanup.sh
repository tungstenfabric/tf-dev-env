#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common/common.sh
source ${scriptdir}/common/functions.sh

function print_help() {
  echo -e "Usage:\n"\
    "./cleanup.sh               # cleanup build artefacts\n"\
    "             [-b | false ] # cleanup build artefacts and dev-env container & image\n"\
    "             [-a ] false ] # cleanup all (build artefacts, containers, iamges, configuration\n"\
    "             [-h ]         # print help\n"
}

remove_sources=1
remove_containers=0
remove_image=0
remove_tf_dev_config=0
while getopts ":abh" opt; do
  case $opt in
    a)
      remove_sources=1
      remove_containers=1
      remove_image=1
      remove_tf_dev_config=1
      ;;
    b)
      remove_sources=1
      remove_containers=1
      remove_image=1
      ;;
    h)
      print_help
      exit
      ;;
    *)
      echo "Invalid option: -$opt. Exiting..." >&2
      exit 1
      ;;

  esac
done

echo tf-dev-env cleanup
if [[ $remove_containers -eq 1 ]] ; then
  echo
  echo '[containers]'
  for container in tf-developer-sandbox $RPM_CONTAINER_NAME $REGISTRY_CONTAINER_NAME; do
    if is_container_created "$container" ; then
      echo -ne "$(sudo docker stop $container) stopped."\\r
      echo $(sudo docker rm $container) removed.
    else
      echo "$container not running."
    fi
  done
fi

if [[ $remove_image -eq 1 ]] ; then
  echo
  echo '[images]'
  sudo -E docker inspect ${DEVENV_IMAGE} >/dev/null 2>&1 && sudo docker rmi -f ${DEVENV_IMAGE}
  echo "image $DEVENV_IMAGE removed"
fi

if [[ $remove_sources -eq 1 ]] ; then
  echo
  echo '[folder]'
  [ -d "$CONTRAIL_DIR" ] && sudo -E rm -rf "$CONTRAIL_DIR"
fi

if [[ $remove_tf_dev_config -eq 1 ]] ; then
  echo
  echo '[tf dev config]'
  [ -d "$TF_CONFIG_DIR" ] && sudo -E rm -rf "$TF_CONFIG_DIR"
fi

echo tf-dev-env cleanup finished
