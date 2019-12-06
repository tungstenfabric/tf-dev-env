#!/bin/bash

[ -n "$DEBUG" ] && set -x

set -o pipefail

scriptdir=$(realpath $(dirname "$0"))

echo
echo '[setup contrail git sources]'

if [ -z "${REPODIR}" ] ; then
  echo "ERROR: env variable REPODIR is required"\
  exit 1
fi

cd $REPODIR
echo "INFO: current folder is ${pwd}"

repo_init_defauilts='--depth=1'
repo_sync_defauilts='--current-branch --no-tags --no-clone-bundle'
if [ -n "$GERRIT_CHANGE_URL" ] ; then
  # for cherry-pick it is needed to have history
  repo_init_defauilts=''
fi
[ -n "$DEBUG" ] && repo_init_defauilts+=' -q' && repo_sync_defauilts+=' -q'


REPO_INIT_MANIFEST_BRANCH=${REPO_INIT_MANIFEST_BRANCH:-'master'}
REPO_INIT_MANIFEST_URL=${REPO_INIT_MANIFEST_URL:-"https://github.com/Juniper/contrail-vnc"}
REPO_INIT_OPTS=${REPO_INIT_OPTS:-${repo_init_defauilts}}
REPO_SYNC_OPTS=${REPO_SYNC_OPTS:-${repo_sync_defauilts}}
REPO_TOOL=${REPO_TOOL:-"./repo"}

if [[ ! -e $REPO_TOOL ]] ; then
  echo "INFO: Download repo tool"
  curl -s -o $REPO_TOOL https://storage.googleapis.com/git-repo-downloads/repo || exit 1
  chmod a+x $REPO_TOOL
fi

echo "INFO: Init contrail sources git repos"
# check if git is setup for current user,
# use a default for repo sync if not
git config --get user.name >/dev/null  2>&1 || git config --global user.name "tf-dev-env"
git config --get user.email >/dev/null 2>&1 || git config --global user.email "tf-dev-env@tf"

REPO_INIT_OPTS+=" -u $REPO_INIT_MANIFEST_URL -b $REPO_INIT_MANIFEST_BRANCH"
echo "INFO: cmd: $REPO_TOOL init $REPO_INIT_OPTS"
# disable pipefail because 'yes' fails if repo init doesnt read at least once 
set +o pipefail
yes | $REPO_TOOL init $REPO_INIT_OPTS
if [[ $? != 0 ]] ; then
  echo  "ERROR: repo init failed"
  exit 1
fi
set -o pipefail


if [[ -n "$GERRIT_CHANGE_URL" ]] ; then
  # set new remote
  gerrit=$(echo "$GERRIT_CHANGE_URL" | grep -io 'http[s]\{0,1\}://[^\/]\+')
  ${scriptdir}/patch-repo-manifest.py \
    --remote "$gerrit" \
    --source ./.repo/manifest.xml \
    --output ./.repo/manifest.xml || exit 1
    echo "INFO: patched manifest.xml"
    cat ./.repo/manifest.xml
    echo
fi

echo "INFO: Sync contrail sources git repos"
threads=$(( $(nproc) * 8 ))
if (( threads > 16 )) ; then
  threads=16
fi
echo "INFO: cmd: $REPO_TOOL sync $REPO_SYNC_OPTS -j $threads"
$REPO_TOOL sync $REPO_SYNC_OPTS -j $threads
if [[ $? != 0 ]] ; then
  echo  "ERROR: repo sync failed"
  exit 1
fi

if [[ -n "$GERRIT_CHANGE_ID" ]] ; then
  [ -z "$gerrit" ] && {
    echo "ERROR: GERRIT_CHANGE_ID is provided but GERRIT_CHANGE_URL is not"
    exit 1
  }
  echo "INFO: gathering UT targets"
  ${scriptdir}/gather-unittest-targets.py > ./unittest_targets || exit 1
  cat ./unittest_targets
  echo "INFO: resolve patchsets"
  # apply patches
  ${scriptdir}/resolve-patchsets.py \
    --gerrit $gerrit \
    --review $GERRIT_CHANGE_ID \
    --branch $GERRIT_BRANCH \
    --output /tmp/patches.json || exit 1
  echo "INFO: review dependencies"
  cat /tmp/patches.json | jq '.'
  cat /tmp/patches.json | jq -r '.[] | .project + " " + .ref + " " + .number' | while read project ref number; do
    short_name=$(echo $project | cut -d '/' -f 2)
    [ -z "$number" ] && number=$(echo $ref | cut -d '/' -f 4)
    echo "INFO: apply change $ref for $project"
    echo "INFO: cmd: $REPO_TOOL download --cherry-pick $short_name $number"
    $REPO_TOOL download --cherry-pick $short_name $number || {
      echo "ERROR: failed to cherry-pick"
      exit 1
    }
  done
  [[ $? != 0 ]] && exit 1
fi

exit 0