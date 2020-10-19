#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../common/common.sh"
source_env

echo "INFO: compile tpp if needed $(date)"

if [ -z "${REPODIR}" ] ; then
  echo "ERROR: env variable REPODIR is required"
  exit 1
fi

patchsets_info_file="${CONTRAIL_INPUT_DIR:-/input}/patchsets-info.json"
if [[ ! -e "$patchsets_info_file" ]] ; then
    echo "INFO: skip tpp: there is no patchset info"
    exit
fi
files=$(cat "$patchsets_info_file" | jq -r '.[] | select(.project | contains("tf-third-party-packages")) | select(has("files")) | .files[]')
if [[ -z "$files" ]] ; then 
    echo "INFO: skip tpp: there is no changes in the files for tf-third-party-packages"
    exit
fi

# check path third_party/contrail-third-party-packages because 
# in vnc it is downloaded into contrail-third-party-packages
tpp_dir=${REPODIR}/third_party/contrail-third-party-packages
if [[ ! -e $tpp_dir ]] ; then
    echo "ERROR: there are changes in tpp but no project $tpp_dir"
    exit 1
fi

export BUILD_BASE=${REPODIR}
pushd ${tpp_dir}/upstream/rpm
echo "INFO: tpp: make list"
make list
echo "INFO: tpp: make prep"
make prep
echo "INFO: tpp: make all"
make all
popd

if [[ ! -e /etc/yum.repos.d/contrail.repo ]] ; then
    echo "INFO: enable contrail repo for next compilation steps"
    # enable contrail repo for dev-env if not created
    # (it is for tpp to be available during compile stage)
    cat <<EOF | tee /etc/yum.repos.d/contrail.repo
[contrail]
name = Contrail repo
baseurl = ${CONTRAIL_REPOSITORY}
enabled = 1
gpgcheck = 0
EOF
else
    echo "INFO: contrail repo is already created"
fi

echo "INFO: contrail repo info"
cat /etc/yum.repos.d/contrail.repo
