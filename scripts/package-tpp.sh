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
files=$(cat $patchsets_info_file | jq -r '.[] | select(.project | contains("contrail-third-party-packages")) | select(has("files")) | .files[]')
if [[ -z "$files" ]] ; then 
    echo "INFO: skip tpp: there is no changes in the files for contrail-third-party-packages"
    exit
fi

working_dir=${REPODIR}/tpp-container-build
mkdir -p ${working_dir}
rm -rf ${working_dir}/*
mkdir ${working_dir}/rpms

pushd ${working_dir}

find $REPODIR/RPMS/ -name "*.rpm" -exec cp "{}" ./rpms/ ";"
if ! ls ./rpms/*.rpm >/dev/null 2>&1 ; then
  echo "ERROR: no tpp rpms found for packaging"
  exit 1
fi

cat <<EOF > ./Dockerfile
FROM scratch
LABEL vendor="$VENDOR_NAME" \
      version="$CONTRAIL_CONTAINER_TAG" \
      release="5.1.0"
COPY  rpms /contrail/tpp/rpms
EOF

build_tag=${}/contrail-third-party-packages:${CONTRAIL_CONTAINER_TAG}
build_opts="--build-arg LC_ALL=en_US.UTF-8 --build-arg LANG=en_US.UTF-8 --build-arg LANGUAGE=en_US.UTF-8"
build_opts+=" --no-cache --tag $build_tag -f Dockerfile ."

docker build $build_opts
docker push $build_tag

popd
