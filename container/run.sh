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
    verify_tag=$(get_current_container_tag)
    while true ; do
        # Sync sources
        echo "INFO: make sync  $(date)"
        make sync
        current_tag=$(get_current_container_tag)
        if [[ $verify_tag == $current_tag ]] ; then
            export FROZEN_TAG=$current_tag
            save_tf_devenv_profile
            break
        fi
        # If tag's changed during our fetch we'll cleanup sources and retry fetching
        [ -d "$CONTRAIL_DIR" ] && mysudo rm -rf "$CONTRAIL_DIR"
    done

    # Invalidate stages after new fetch. For fast build and patchest invalidate only if needed.
    if [[ $BUILD_MODE == "fast" ]] ; then
        echo "Checking patches for fast build mode"
        if patches_exist ; then
            echo "INFO: patches encountered" $changed_projects
            if ! [[ -z $changed_containers_projects && -z $changed_deployers_projects && -z $changed_tests_projects ]] ; then
                echo "Containers or deployers are changed, cleaning package stage"
                cleanup package
            fi
            if [[ -n $changed_product_projects ]] ; then
                echo "Contrail core is changed, cleaning all stages"
                cleanup compile
                cleanup package
                # vrouter dpdk project uses makefile and relies on date of its artifacts to be fresher than sources
                # which after resyncing here isn't true, so we'll refresh it if it's unchanged to skip rebuilding
                if ! [[ ${changed_product_project[@]} =~ "tf-dpdk" ]] ; then
                    find $WORK_DIR/build/production/vrouter/dpdk/x86_64-native-linuxapp-gcc/build -type f -exec touch {} +
                fi
            fi
        else
            echo "No patches encountered"
        fi
    else
        cleanup
    fi
}

function configure() {
    echo "INFO: make setup  $(date)"
    make setup

    echo "INFO: make dep fetch_packages  $(date)"
    # targets can use yum and will block each other. don't run them in parallel
    make dep 
    make fetch_packages

    # disable byte compiling
    if [[ ! -f /usr/lib/rpm/brp-python-bytecompile.org  ]] ; then
        echo "INFO: disable byte compiling for python"
        mv /usr/lib/rpm/brp-python-bytecompile /usr/lib/rpm/brp-python-bytecompile.org
        cat <<EOF | tee /usr/lib/rpm/brp-python-bytecompile
#!/bin/bash
# disabled byte compiling
exit 0
EOF
        chmod +x /usr/lib/rpm/brp-python-bytecompile
    fi
}

function compile() {
    echo "INFO: Check variables used by makefile"
    uname -a
    make info

    # Remove information about FROZEN_TAG so that package stage doesn't try to use ready containers.
    export FROZEN_TAG=""
    save_tf_devenv_profile

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

    # Check if we're run by Jenkins and have an automated patchset
    if [[ $BUILD_MODE == "fast" ]] && patches_exist ; then
        make_containers=""
        if [[ ! -z $changed_containers_projects ]] ; then
            make_containers="containers src-containers"
        elif [[ ! -z $changed_deployers_projects ]] ; then
            make_containers="src-containers"
        fi
        if [[ ! -z $changed_tests_projects ]] ; then
            make_containers="${make_containers} test-containers"
        fi
    else
        make_containers="containers src-containers test-containers"
    fi
    # TODO: We'll have to build all containers until frozen images are available for using
    make_containers="containers src-containers test-containers"

    # build containers
    echo "INFO: make $make_containers $(date)"
    make -j 8 $make_containers
    build_status=$?
    if [[ "$build_status" != "0" ]]; then
        echo "INFO: make containers failed with code $build_status $(date)"
        exit $build_status
    fi

    # To be removed. Left here for r1912 only
    if [[ $BUILD_MODE == "full" ]] ; then
        # build containers
        echo "INFO: make deployers $(date)"
        make deployers
        build_status=$?
        if [[ "$build_status" != "0" ]]; then
            echo "ERROR: make deployers failed with code $build_status $(date)"
            exit $build_status
        fi
    fi

    # Pull containers which build skipped
    for container in ${unchanged_containers[@]}; do
        echo "INFO: fetching unchanged $container and pushing it as $CONTAINER_REGISTRY/$container:$CONTRAIL_CONTAINER_TAG"
        sudo docker pull "$frozen_registry/$container:frozen"
        sudo docker tag "$CONTAINER_REGISTRY/$container:frozen" "$container:$CONTRAIL_CONTAINER_TAG"
        sudo docker push "$CONTAINER_REGISTRY/$container:$CONTRAIL_CONTAINER_TAG"
    done

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
    # run selected stage unless we're in fast build mode and the stage is finished. TODO: remove skipping package when frozen containers are available.
    if ! finished_stage "$stage" || [[ $BUILD_MODE == "full" ]] || [[ $stage == "fetch" ]] || [[ $stage == "configure" ]] || [[ $stage == "package" ]] ; then
        echo "INFO: Running stage $stage in $BUILD_MODE mode"
        run_stage $stage $target
    else
        echo "INFO: Skipping stage $stage in $BUILD_MODE mode"
    fi
fi

echo "INFO: make successful  $(date)"
