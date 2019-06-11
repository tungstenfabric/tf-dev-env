#!/bin/bash

remove_volume=0
while getopts ":v" opt; do
  case $opt in
    v)
      remove_volume=1
      ;;
    \?)
      echo "Invalid option: -$opt. Exiting..." >&2
      exit 1
      ;;
  esac
done

echo tf-dev-env cleanup
echo
echo '[containers]'
for container in tf-developer-sandbox tf-dev-env-registry tf-dev-env-rpm-repo; do
  if docker ps -a --format '{{ .Names }}' | grep "$container" > /dev/null; then
    echo -ne "$(docker stop $container) stopped."\\r
    echo $(docker rm $container) removed.
  else
    echo "$container not running."
  fi
done

if [[ $remove_volume -eq 1 ]]; then
  echo
  echo '[volumes]'
  volume_name=tf-dev-env-rpms
  if docker volume list --format '{{ .Name }}' | grep "$volume_name" >/dev/null; then
    echo $(docker volume rm $volume_name) removed.
  else
    echo "$volume_name does not exist."
  fi
fi
