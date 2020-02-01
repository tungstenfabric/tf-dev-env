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

if [[ -e ${REPODIR}/.env/tf-developer-sandbox.env ]] ; then
    echo "INFO: source env from ${REPODIR}/.env/tf-developer-sandbox.env"
    set -o allexport
    source ${REPODIR}/.env/tf-developer-sandbox.env
    set +o allexport
fi

cd $REPODIR
echo "INFO: current folder is ${pwd}"

repo_init_defauilts='--depth=1'
repo_sync_defauilts='--current-branch --no-tags --no-clone-bundle'
if [ -n "$GERRIT_URL" ] ; then
  # for cherry-pick it is needed to have history
  repo_init_defauilts=''
fi
[ -n "$DEBUG" ] && repo_init_defauilts+=' -q' && repo_sync_defauilts+=' -q'


REPO_INIT_MANIFEST_URL=${REPO_INIT_MANIFEST_URL:-${CONTRAIL_FETCH_REPO}}
if [[ -n "$CONTRAIL_BRANCH" ]] ; then
  # reset branch to master if no such branch in vnc: openshift-ansible,
  # contrail-tripleo-puppet, contrail-trieplo-heat-templates do not 
  # depend on contrail branch and are openstack depended.
  if ! curl https://review.opencontrail.org/projects/Juniper%2Fcontrail-vnc/branches | grep 'ref' | grep -q "${CONTRAIL_BRANCH}" ; then
    echo "Ther is no $CONTRAIL_BRANCH branch in contrail-vnc, use master for vnc"
    CONTRAIL_BRANCH="master"
    GERRIT_BRANCH=""
  fi
fi

REPO_INIT_MANIFEST_BRANCH=${REPO_INIT_MANIFEST_BRANCH:-${CONTRAIL_BRANCH}}
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

branch_opts=""
if [[ -n "$GERRIT_BRANCH" ]] ; then
  branch_opts+="--branch $GERRIT_BRANCH"
fi

# file for patchset info if any
patchsets_info_file=${REPODIR}/patchsets-info.json

if [[ -n "$GERRIT_CHANGE_ID" && -z "$GERRIT_URL" ]] ; then
  echo "ERROR: GERRIT_CHANGE_ID is provided but GERRIT_URL is not"
  exit 1
fi

# resolve changes if any
if [[ -n "$GERRIT_CHANGE_ID" ]] ; then
  echo "INFO: resolve patchsets to $patchsets_info_file"
  ${scriptdir}/resolve-patchsets.py \
    --gerrit $GERRIT_URL \
    --review $GERRIT_CHANGE_ID \
    $branch_opts \
    --changed_files \
    --output $patchsets_info_file || exit 1
fi

if [[ -n "$GERRIT_URL" ]] ; then
  ${scriptdir}/patch-repo-manifest.py \
    --remote "$GERRIT_URL" \
    $branch_opts \
    --source ./.repo/manifest.xml \
    --patchsets $patchsets_info_file \
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
  echo "INFO: gathering UT targets"
  ${scriptdir}/gather-unittest-targets.py < $patchsets_info_file > ./unittest_targets || exit 1
  cat ./unittest_targets

  # apply patches
  echo "INFO: review dependencies"
  cat $patchsets_info_file | jq '.'
  cat $patchsets_info_file | jq -r '.[] | .project + " " + .ref + " " + .number' | while read project ref number; do
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