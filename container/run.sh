#!/bin/bash

my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"
source "$my_dir/../common/common.sh"
source "$my_dir/../common/functions.sh"
source "$my_dir/../common/tf_functions.sh"

stage="$1"
target="$2"

echo "INFO: run stage $stage with target $target"

set -eo pipefail

source_env
prepare_infra
cd $DEV_ENV_ROOT

[ -n "$DEBUG" ] && set -x

declare -a all_stages=(fetch configure compile package test freeze)
declare -a default_stages=(fetch configure)
declare -a build_stages=(fetch configure compile package)

function fetch() {
    # Sync sources
    echo "INFO: make sync  $(date)"
    make sync
}

function configure() {
    echo "INFO: make setup  $(date)"
    sudo make setup

    echo "INFO: make dep fetch_packages  $(date)"
    # targets can use yum and will block each other. don't run them in parallel
    sudo make dep 
    make fetch_packages

    # disable byte compiling
    if [[ ! -f /usr/lib/rpm/brp-python-bytecompile.org  ]] ; then
        echo "INFO: disable byte compiling for python"
        sudo mv /usr/lib/rpm/brp-python-bytecompile /usr/lib/rpm/brp-python-bytecompile.org
        cat <<EOF | sudo tee /usr/lib/rpm/brp-python-bytecompile
#!/bin/bash
# disabled byte compiling
exit 0
EOF
        sudo chmod +x /usr/lib/rpm/brp-python-bytecompile
    fi
}

function compile() {
    echo "INFO: Check variables used by makefile"
    uname -a
    make info

    echo "INFO: create rpm repo $(date)"
    # Workaround for symlinked RPMS - rename of repodata to .oldata in createrepo utility fails otherwise
    rm -rf $WORK_DIR/RPMS/repodata
    make create-repo
    echo "INFO: make tpp $(date)"
    make build-tpp
    echo "INFO: update rpm repo $(date)"
    make update-repo
    echo "INFO: package tpp $(date)"
    # TODO: for now it does packaging for all rpms found in repo, 
    # at this moment tpp packages are built only if there are changes there 
    # from gerrit. So, for now it relies on tha fact that it is first step of RPMs.
    make package-tpp
    echo "INFO: make rpm  $(date)"
    make rpm
    echo "INFO: update rpm repo $(date)"
    make update-repo
}

function test() {
    echo "INFO: Starting unit tests"
    uname -a
    TEST_PACKAGE=$1 make test
}

function package() {
    #Package everything
    echo "INFO: Check variables used by makefile"
    uname -a
    make info

    # Setup and start httpd for RPM repo if not present
    if ! pidof httpd ; then
        setup_httpd
    fi

    # Check if we're packaging only a single target
    if [[ -n "$target" ]] ; then
        echo "INFO: packaging only ${target}"
        make $target
        return $?
    fi

    echo "INFO: make containers  $(date)"
    # prepare rpm repo and repos
    echo "INFO: make prepare-containers prepare-deployers  $(date)"
    make -j 2 prepare-containers prepare-deployers
    build_status=$?
    if [[ "$build_status" != "0" ]]; then
        echo "INFO: make prepare containers failed with code $build_status  $(date)"
        exit $build_status
    fi

    # prebuild general base as it might be used by deployers
    echo "INFO: make container-general-base  $(date)"
    make container-general-base
    build_status=$?
    if [[ "$build_status" != "0" ]]; then
        echo "INFO: make general-base container failed with code $build_status $(date)"
        exit $build_status
    fi

    # build containers
    echo "INFO: make containers-only deployers-only test-containers  $(date)"
    make -j 8 containers-only deployers-only test-containers src-containers
    build_status=$?
    if [[ "$build_status" != "0" ]]; then
        echo "INFO: make containers failed with code $build_status $(date)"
        exit $build_status
    fi

    echo Build of containers with deployers has finished successfully
}

function freeze() {
    # Prepare this container for pushing
    # Unlink all symlinks in contrail folder
    find $HOME/contrail -maxdepth 1 -type l | xargs -L 1 unlink
    # scons rewrites .sconsign.dblite so as double protection we'll save it if it's still in contrail
    if [[ -e "${HOME}/contrail/.sconsign.dblite" ]]; then
        rm -f ${HOME}/work/.sconsign.dblite
        mv ${HOME}/contrail/.sconsign.dblite ${HOME}/work/
    fi
    # Check if sources (contrail folder) are mounted from outside and remove if not
    if ! mount | grep "contrail type" ; then
        rm -rf $HOME/contrail || /bin/true
    fi
}

function run_stage() {
    $1 $2
    touch $STAGES_DIR/$1 || true
}

function finished_stage() {
    [ -e $STAGES_DIR/$1 ]
}

function cleanup() {
    local stage=${1:-'*'}
    rm -f $STAGES_DIR/$stage
}

function enabled() {
    [[ "$1" =~ "$2" ]]
}

# select default stages
if [[ -z "$stage" ]] ; then
    for dstage in ${default_stages[@]} ; do
        if ! finished_stage "$dstage" ; then
            run_stage $dstage
        fi
    done
elif [[ "$stage" =~ 'build' ]] ; then
    # run default stages for 'build' option
    for bstage in ${build_stages[@]} ; do
        if ! finished_stage "$bstage" ; then
            run_stage $bstage $target
        fi
    done
else
    # run selected stage
    run_stage $stage $target
fi

echo "INFO: make successful  $(date)"
