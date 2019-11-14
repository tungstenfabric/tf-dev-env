#!/bin/bash

echo
echo '[setup contrail git sources]'

if [ -z "${REPODIR}" ] ; then
  echo "ERROR: env variable REPODIR is required"\
  exit 1
fi

cd $REPODIR

INIT_FETCH_OPTS=${INIT_FETCH_OPTS:-'--depth=1 -q'}
FETCH_OPTS=${FETCH_OPTS:-'--current-branch --no-tags --no-clone-bundle -q'}

if [ ! -e ./repo ] ; then
  echo "INFO: Download repo tool"
  curl -s https://storage.googleapis.com/git-repo-downloads/repo > ./repo
  chmod a+x ./repo
fi

if [ ! -e ./.repo ] ; then
  echo "INFO: Init contrail sources git repos"
  vnc_branch="master"
  if [[ "$DEVENVTAG" != "latest" ]]; then
    vnc_branch="$DEVENVTAG"
  fi
  # check if git is setup for current user,
  # use a default for repo sync if not
  git config --get user.name >/dev/null  2>&1 || git config --global user.name "tf-dev-env"
  git config --get user.email >/dev/null 2>&1 || git config --global user.email "tf-dev-env@tf"
  yes | ./repo init $INIT_FETCH_OPTS -u https://github.com/Juniper/contrail-vnc -b $vnc_branch
fi

echo "INFO: Sync contrail sources git repos"
threads=$(( $(nproc) * 2 ))
./repo sync $FETCH_OPTS -j $threads
