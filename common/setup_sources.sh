#!/bin/bash

scriptdir=$(realpath $(dirname "$0"))
source ${scriptdir}/common.sh
source ${scriptdir}/functions.sh

echo
echo '[setup contrail git sources]'

if [ -z "${CONTRAIL_DIR}" ] ; then
  echo "ERROR: env variable CONTRAIL_DIR is required"\
  exit 1
fi


mkdir -p "${CONTRAIL_DIR}/RPMS"
pushd $CONTRAIL_DIR

CONTRAIL_INIT_REPOS_OPTS=${CONTRAIL_INIT_REPOS_OPTS:-'--depth=1 -q'}
CONTRAIL_SYNC_REPOS_OPTS=${CONTRAIL_SYNC_REPOS_OPTS:-'--current-branch --no-tags --no-clone-bundle -q'}

if [ ! -e ./repo ] ; then
  echo "INFO: Download repo tool"
  curl -s https://storage.googleapis.com/git-repo-downloads/repo > ./repo
  chmod a+x ./repo
fi  

[ $CONTRAIL_SYNC_REPOS != 1 ] && { echo "INFO: TF git repos sync skipped" && exit ; }

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
  ./repo init $CONTRAIL_INIT_REPOS_OPTS -u https://github.com/Juniper/contrail-vnc -b $vnc_branch
fi

echo "INFO: Sync contrail sources git repos"
threads=$(( $(nproc) * 2 ))
./repo sync $CONTRAIL_SYNC_REPOS_OPTS -j $threads

popd
