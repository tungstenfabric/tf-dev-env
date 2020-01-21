#!/bin/bash -e

echo "INFO: compile tpp if needed $(date)"

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

working_dir=${REPODIR}/tpp-container-build
mkdir -p ${working_dir}
rm -rf ${working_dir}/*
mkdir ${working_dir}/rpms

pushd ${working_dir}

find $REPODIR/RPMS/ -name "*.rpm" -exec cp "{}" ./rpms/ ";"

cat <<EOF > ./Dockerfile
FROM scratch
LABEL vendor="$VENDOR_NAME" \
      version="$CONTRAIL_CONTAINER_TAG" \
      release="5.1.0"
COPY  rpms /contrail/tpp/rpms
EOF

build_tag=${CONTRAIL_REGISTRY}/contrail-third-party-packages:${CONTRAIL_CONTAINER_TAG}
build_opts="--build-arg LC_ALL=en_US.UTF-8 --build-arg LANG=en_US.UTF-8 --build-arg LANGUAGE=en_US.UTF-8"
build_opts+=" --no-cache --tag $build_tag -f Dockerfile ."

docker build $build_opts
docker push $build_tag

popd
