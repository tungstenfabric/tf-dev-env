#!/bin/bash
set -u

SRC_DIR=/root/src/${CANONICAL_HOSTNAME}/Juniper/
c_p_c_rev=c9524c72199
c_z_j_rev=22aea96d23

mkdir -p ${SRC_DIR}

function checkout() {
  local repo=$1
  local rev=${2:-master}
  local repopath=${SRC_DIR}/${repo}

  test -d ${repopath} || git clone https://github.com/Juniper/${repo} ${repopath} >/dev/null 2>&1
  pushd ${repopath} >/dev/null
  git fetch origin >/dev/null
  echo -n "${repo}: "
  git checkout -B dev-env ${rev} >/dev/null
  git reset --hard >/dev/null
  popd >/dev/null 

}

checkout contrail-project-config $c_p_c_rev
checkout contrail-zuul-jobs $c_z_j_rev

