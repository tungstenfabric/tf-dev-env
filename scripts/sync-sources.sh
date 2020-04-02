#!/bin/bash

exit 123

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

repo_init_defauilts='--repo-branch=repo-1'
repo_sync_defauilts='--no-tags --no-clone-bundle -q'
[ -n "$DEBUG" ] && repo_init_defauilts+=' -q' && repo_sync_defauilts+=' -q'


REPO_INIT_MANIFEST_URL=${REPO_INIT_MANIFEST_URL:-${CONTRAIL_FETCH_REPO}}
if [[ -n "$CONTRAIL_BRANCH" ]] ; then
  # reset branch to master if no such branch in vnc: openshift-ansible,
  # contrail-tripleo-puppet, contrail-trieplo-heat-templates do not 
  # depend on contrail branch and are openstack depended.
  if ! curl -s https://review.opencontrail.org/projects/Juniper%2Fcontrail-vnc/branches | grep 'ref' | grep -q "${CONTRAIL_BRANCH}" ; then
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
  curl -s -o $REPO_TOOL https://storage.googleapis.com/git-repo-downloads/repo-1 || exit 1
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

# resolve changes if any
if [ ! -e "$patchsets_info_file" ] ; then
  echo "INFO: There is no file $patchsets_info_file - skipping cherry-picking."
else
  echo "INFO: gerrit URL = ${GERRIT_URL}"
  cat $patchsets_info_file | jq '.'
  vnc_changes=$(cat $patchsets_info_file | jq -r '.[] | select(.project == "Juniper/contrail-vnc") | .project + " " + .ref + " " + .branch')
  if [[ -n "$vnc_changes" ]] ; then
    # clone from GERRIT_URL cause this is taken from patchsets
    vnc_branch=$(echo "$vnc_changes" | head -n 1 | awk '{print($3)}')
    rm -rf contrail-vnc
    cmd="git clone --depth=1 --single-branch -b $vnc_branch ${GERRIT_URL}Juniper/contrail-vnc"
    echo "INFO: $cmd"
    eval "$cmd" || {
        echo "ERROR: failed to $cmd"
        exit 1
    }
    pushd contrail-vnc
    echo "$vnc_changes" | while read project ref branch; do
      cmd="git fetch ${GERRIT_URL}Juniper/contrail-vnc $ref && git cherry-pick FETCH_HEAD "
      echo "INFO: apply patch: $cmd"
      eval "$cmd" || {
        echo "ERROR: failed to $cmd"
        exit 1
      }
    done
    popd
    echo "INFO: replace manifest from review"
    cp -f contrail-vnc/default.xml .repo/manifest.xml
  fi

  echo "INFO: patching manifest.xml for repo tool"
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
# switch to branches
while read repo_project ; do
  while read repo_path && read commit && read revision ; do
    pushd $repo_path
      remote=$(git log -1 --pretty=%d HEAD | tr -d '(,)' | awk '{print($3)}')
      [ -n "$remote" ] || {
        echo "ERROR: failed to get remote for tracking branch $revision for $repo_path : $repo_project"
        exit 1
      }
      [[ 'refs/heads/master' ==  $revision ]] && revision='master'
      echo "INFO: set tracking branch $revision to $remote for $repo_path : $repo_project"
      git checkout --track -b $revision $remote || git checkout $revision || {
        echo "ERROR: failed switch to branch $revision with remote $remote for $repo_path : $repo_project"
        exit 1
      }
    popd
  done < <($REPO_TOOL info -l $repo_project | awk '/Mount path:|Current revision:|Manifest revision:/ {print($3)}')
done < <($REPO_TOOL list --name-only | sort -u)


if [[ $? != 0 ]] ; then
  echo  "ERROR: $REPO_TOOL start failed"
  exit 1
fi

# TODO: remove this hack after reelase of R2003
if [[ "$GERRIT_BRANCH" == 'R2003' ]]; then
  rm -rf ${REPODIR}/contrail-deployers-containers/containers/helm-deployer
  rm -rf ${REPODIR}/tf-charms
fi

if [ -e "$patchsets_info_file" ] ; then
  echo "INFO: gathering UT targets"
  ${scriptdir}/gather-unittest-targets.py < $patchsets_info_file > ./unittest_targets || exit 1
  cat ./unittest_targets
  echo

  # apply patches
  echo "INFO: review dependencies"
  cat $patchsets_info_file | jq -r '.[] | select(.project != "Juniper/contrail-vnc") | .project + " " + .ref' | while read project ref; do
    short_name=$(echo $project | cut -d '/' -f 2)
    repo_projects=$($REPO_TOOL list -r "^${short_name}$" | tr -d ':' )
    # use manual filter as repo forall -regex checks both path and project
    while read -r repo_path repo_project ; do
      echo "INFO: process repo_path=$repo_path , repo_project=$repo_project"
      if [[ "$short_name" != "$repo_project" ]] ; then
        echo "INFO: doesnt match to $short_name .. skipped"
        continue
      fi
      echo "INFO: apply change $ref for $project"
      echo "INFO: cmd: git fetch $GERRIT_URL/$project $ref && git cherry-pick FETCH_HEAD"
      pushd $repo_path
      git fetch $GERRIT_URL/$project $ref && git cherry-pick FETCH_HEAD || {
        echo "ERROR: failed to cherry-pick"
        exit 1
      }
      popd
    done <<< "$repo_projects"
  done
  [[ $? != 0 ]] && exit 1
fi

echo "INFO: replace symlinks inside .git folder to real files to be able to use them at deployment stage"
# replace symlinks with target files for all .git files
for item in $(find ${REPODIR}/ -type l -print | grep "/.git/") ; do
  idir=$(dirname $item)
  target=$(realpath $item)
  rm -f "$item"
  cp -arf $target $idir/
done

exit 0
