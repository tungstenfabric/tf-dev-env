FROM centos:7.5.1804

ENV USER root
ENV HOME /root
ENV CONTRAIL $HOME/contrail
ARG BRANCH=master

RUN mkdir -p $CONTRAIL
WORKDIR $CONTRAIL

# Install android repo
RUN curl -s https://storage.googleapis.com/git-repo-downloads/repo > /usr/bin/repo \
&&  chmod a+x /usr/bin/repo \
&&  cp -R /etc/yum.repos.d /etc/yum.repos.d.save

# Inject repositories that we might need
COPY *.repo /etc/yum.repos.d/

# Install basic packages
RUN yum -y install epel-release \
&&  yum -y update \
&&  yum -y install \
    autoconf \
    automake \
    createrepo \
    docker \
    docker-python \
    gcc \
    gdb \
    git \
    kernel \
    libtool \
    make \
    python-devel \
    python-pip \
    python36 \
    rpm-build \
    vim \
    wget \
    yum-utils \
&&  yum clean all \
&&  rm -rf /var/cache/yum

# Initialize sandbox, get code, install build dependencies
# and fetch third parties
RUN echo "Initializing repo from $BRANCH" \
&&  repo init --no-clone-bundle -q -u https://github.com/Juniper/contrail-vnc -b $BRANCH \
&&  rm -rf /etc/yum.repos.d \
&&  mv /etc/yum.repos.d.save /etc/yum.repos.d \
&&  yum clean all \
&&  rm -rf /var/cache/yum

# DEVELOPMENT ENVIRONMENT TWEAKS
# contrail-kubernetes and contrail-config
RUN pip install --upgrade tox geventhttpclient

RUN echo export CONTRAIL=$CONTRAIL >> $HOME/.bashrc \
&&  echo export LD_LIBRARY_PATH=$CONTRAIL/build/lib >> $HOME/.bashrc

ADD Dockerfile entrypoint.sh $HOME/

ENTRYPOINT ["/root/entrypoint.sh"]
