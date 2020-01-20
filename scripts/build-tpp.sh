#!/bin/bash -e

echo "INFO: compile tpp if needed $(date)"

if [ -z "${REPODIR}" ] ; then
  echo "ERROR: env variable REPODIR is required"\
  exit 1
fi

patchsets_info_file=${REPODIR}/patchsets-info.json
if [[ ! -e "$patchsets_info_file" ]] ; then
    echo "INFO: skip tpp: there is no patchset info"
    return
fi
files=$(cat $patchsets_info_file | jq -r '.[] | select(.project | contains("contrail-third-party-packages")) | select(has("files")) | .files[]')
if [[ -z "$files" ]] ; then 
    echo "INFO: skip tpp: there is no changes in the files for contrail-third-party-packages"
    return
fi

tpp_dir=${REPODIR}/third_party/contrail-third-party-packages
if [[ ! -e $tpp_dir ]] ; then
    echo "ERROR: there are changes in tpp but no project $tpp_dir"
    exit 1
fi

export BUILD_BASE=${REPODIR}
pushd ${tpp_dir}/upstream/rpm
make list
make prep
make all
popd
