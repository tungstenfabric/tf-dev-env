#!/bin/bash

my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"
source "$my_dir/../common/common.sh"
source "$my_dir/../common/functions.sh"
source "$my_dir/../common/tf_functions.sh"

stage="$1"
target="$2"

echo "INFO: run stage $stage with target $target"

if [[ -e /input/tf-developer-sandbox.env ]] ; then
    echo "INFO: source env from /input/tf-developer-sandbox.env"
    set -o allexport
    source /input/tf-developer-sandbox.env
    set +o allexport
fi

[ -n "$DEBUG" ] && set -x

set -eo pipefail

declare -a all_stages=(fetch configure compile package test freeze)
declare -a default_stages=(fetch configure)
declare -a build_stages=(fetch configure compile package)

if [[ -n "$CONTRAIL_CONFIG_DIR" && -d "$CONTRAIL_CONFIG_DIR" ]]; then
  sudo cp -rf ${CONTRAIL_CONFIG_DIR}/* /
fi

cd $CONTRAIL_DEV_ENV
if [[ -e common.env ]] ; then
    echo "INFO: source env from common.env"
    set -o allexport
    source common.env
    set +o allexport
fi

STAGES_DIR="${CONTRAIL}/.stages"
mkdir -p $STAGES_DIR

function fetch() {
    # Try to unfreeze previously frozen build if tgz is present and no explicit "run.sh fetch sync" is called
    if [[ $target != "sync" && -e $HOME/contrail.tgz ]] ; then
        echo "INFO: frozen snapshot is present, extracting"
        pushd $HOME
        tar xzf contrail.tgz
        if patches_exist ; then
            if [[ -v $changed_containers_projects || -v $changed_deployers_projects || -v $changed_tests_projects ]] ; then
                rm -f contrail/.stages/package
            fi
            if [[ -v $changed_product_projects ]] ; then
                rm -f contrail/.stages/compile
            fi
        fi
        popd
        sudo chown $(id -u):$(id -g) -R $HOME/contrail
        return $?
    fi
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

    if [[ "$target" == "test" ]]; then
      ./scripts/controller_ut/compile.sh
      exit
    fi
    
    echo "INFO: create rpm repo $(date)"
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
    # Setup and start httpd for RPM repo if not present
    if ! pidof httpd ; then
        setup_httpd
    fi

    # Check if we're packaging only a single target
    if [[ ! -z $target ]] ; then
        echo "INFO: packaging only ${target}"
        make $target
        return $?
    fi

    # Check if we're run by Jenkins and have an automated patchset
    if finished_state "freeze" and patches_exist ; then
        prepare_containers=""
        make_containers=""
        if [[ -v $changed_containers_projects ]] ; then
            prepare_containers="prepare_containers"
            make_containers="containers-only src-containers-only"
        elif [[ -v $changed_deployers_projects ]] ; then
            make_containers="src-containers-only"
        fi
        if [[ -v $changed_tests_projects ]] ; then
            prepare_containers="${prepare_containers} prepare-test-containers"
            make_containers="${make_containers} test-containers-only"
        fi
    else
        prepare_containers="prepare_containers prepeare-test-containers"
        make_containers="containers-only src-containers-only test-containers-only"
    fi

    #Package everything
    echo "INFO: Check variables used by makefile"
    uname -a
    make info
    echo "INFO: make containers  $(date)"
    # prepare rpm repo and repos
    echo "INFO: make $prepare_containers $(date)"
    make -j 3 $prepare_containers
    build_status=$?
    if [[ "$build_status" != "0" ]]; then
        echo "INFO: make prepare containers failed with code $build_status  $(date)"
        exit $build_status
    fi

    # build containers
    echo "INFO: make $make_containers $(date)"
    make -j 8 $make_containers
    build_status=$?
    if [[ "$build_status" != "0" ]]; then
        echo "INFO: make containers failed with code $build_status $(date)"
        exit $build_status
    fi

    echo Build of containers with deployers has finished successfully
}

function freeze() {
    # Prepare this container for pushing
    pushd $HOME
    tar czf contrail.tgz contrail
    popd
    # Check if sources (contrail folder) are mounted from outside and remove if not
    if ! mount | grep "contrail type" ; then
        [[ $(rm -rf $HOME/contrail) ]] || true
    fi
}

function run_stage() {
    $1 $2
    touch $STAGES_DIR/$1
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
