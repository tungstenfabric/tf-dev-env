#!/bin/bash -e

scriptdir=$(realpath $(dirname "$0"))
source "$scriptdir/../common/common.sh"
source_env

function make_contrail_repo() {
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
cost = 100
EOF
    else
        echo "INFO: contrail repo is already created"
    fi
    echo "INFO: contrail repo info"
    cat /etc/yum.repos.d/contrail.repo
    yum clean all --disablerepo=* --enablerepo=contrail
}

echo "INFO: compile tpp if needed $(date) (BUILD_TPP_FORCE=$BUILD_TPP_FORCE)"

if [ -z "${REPODIR}" ] ; then
    echo "ERROR: env variable REPODIR is required"
    exit 1
fi

if [[ "${BUILD_TPP_FORCE,,}" != 'true' ]] ; then
    patchsets_info_file=/input/patchsets-info.json
    if [[ ! -e "$patchsets_info_file" ]] ; then
        echo "INFO: skip tpp: there is no patchset info"
        exit
    fi
    files=$(cat $patchsets_info_file | jq -r '.[] | select(.project | contains("tf-third-party-packages")) | select(has("files")) | .files[]')
    if [[ -z "$files" ]] ; then
        echo "INFO: skip tpp: there is no changes in the files for tf-third-party-packages"
        exit
    fi
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
all_targets=$(make list --no-print-directory)
echo "$all_targets"
all_targets=$(echo "$all_targets" | tr ' ' '\n')
echo "INFO: tpp: make prep"
make prep

# build packages which are required for next steps in determined order
# boost 1st (cpp 3d-party depends on it)
# python-mimeparse and python-extras (python-setuptools depends on it)
for pkg in boost python-mimeparse python-extras ; do
    target=$(echo "$all_targets" | grep $pkg)
    if [ -n "$target" ] ; then
        echo "INFO: tpp: make $target"
        make $target
        make_contrail_repo
        popd
        echo "INFO: update rpm repo $(date)"
        make update-repo
        pushd ${tpp_dir}/upstream/rpm
    fi
    all_targets=$(echo "$all_targets" | grep -v $pkg)
done

# rest targets
all_targets=$(echo "$all_targets" | tr '\n' ' ')
[ -n "$all_targets" ] || all_targets="all"
echo "INFO: tpp: make $all_targets"
make $all_targets
popd

make_contrail_repo
