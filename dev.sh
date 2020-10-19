#!/bin/bash -e

# Perform developer build locally, outside of a container
# to enable debugging without remote debugging via
# containers.  Only works on a supported version of CentOS.

scriptdir=$(realpath $(dirname "$0"))

export DEV_ENV_ROOT="$scriptdir"
export ROOT_CONTRAIL="$scriptdir/contrail"
export WORK_DIR="$scriptdir/work"
export CONTRAIL_CONFIG_DIR="$scriptdir/config"
export CONTRAIL_INPUT_DIR="$scriptdir/input"
export CONTRAIL_OUTPUT_DIR="$scriptdir/output"

source ${scriptdir}/common/common.sh
source ${scriptdir}/common/functions.sh
source ${scriptdir}/common/tf_functions.sh

stage="$1"
target="$2"

cd "$scriptdir"

# Build options

echo tf-dev-env startup
echo
echo '[ensure build requirements are present]'
install_prerequisites_dev_$DISTRO || die "developer setup failed"

# prepare env
$scriptdir/common/setup_docker.sh
$scriptdir/common/setup_docker_registry.sh
load_tf_devenv_profile

echo
echo "INFO: make common.env"
eval "cat <<< \"$(<$scriptdir/common.env.tmpl)\"" > $scriptdir/common.env
echo "INFO: common.env content:"
cat $scriptdir/common.env

# make env profile to run
# input dir can be already created and had files like patchsets-info.json, unittest_targets.lst
input_dir="${scriptdir}/input"
mkdir -p "$input_dir"
tf_container_env_file="${input_dir}/tf-developer-sandbox.env"
create_env_file "$tf_container_env_file"

# mount this dir always - some stage can put files there even if it was empty when container was created
mkdir -p ${scriptdir}/config
# and put tpc.repo there cause stable image doesn't have it
mkdir -p ${scriptdir}/config/etc/yum.repos.d /etc/yum.repos.d 
cp -f ${scriptdir}/tpc.repo ${scriptdir}/config/etc/yum.repos.d/
cp -f ${scriptdir}/tpc.repo /etc/yum.repos.d/

echo
echo '[environment setup]'

# set paths used to build on the (developer) host
. "$tf_container_env_file"

# requirements for development (debugging) on host
if [[ ! -r "$STAGES_DIR/fetch" ]]; then
  "$scriptdir/container/setup_centos.sh" || exit 1
fi

if [[ "$stage" == 'none' ]] ; then
  echo "INFO: don't run any stages"
  exit 0
fi

mkdir -p "$CONTRAIL_INPUT_DIR" "$CONTRAIL_OUTPUT_DIR" "$CONTRAIL_SOURCE" "$ROOT_CONTRAIL"
cd "$ROOT_CONTRAIL"

echo "run stage(s) ${stage:-${default_stages[@]}} with target ${target:-all}"
mysudo "${DEV_ENV_ROOT}/container/run.sh" $stage $target
result=$?

if [[ $result == 0 ]] ; then
  help
else
  echo
  echo 'ERROR: There were failures. See logs for details.'
fi

exit $result
