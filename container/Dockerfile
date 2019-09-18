FROM registry.access.redhat.com/ubi8/ubi:latest

ENV USER root
ENV HOME /root
ENV CONTRAIL $HOME/contrail
ARG BRANCH=master
ARG LC_ALL=en_US.UTF-8
ARG LANG=en_US.UTF-8
ARG LANGUAGE=en_US.UTF-8

ENV LC_ALL=$LC_ALL
ENV LANG=$LANG
ENV LANGUAGE=$LANGUAGE

RUN mkdir -p $CONTRAIL
WORKDIR $CONTRAIL

# Install android repo
RUN curl -s https://storage.googleapis.com/git-repo-downloads/repo > /usr/bin/repo \
&&  chmod a+x /usr/bin/repo \
&&  cp -R /etc/yum.repos.d /etc/yum.repos.d.save

# Inject repositories that we might need
COPY *.repo /etc/yum.repos.d/
COPY locale.conf /etc/locale.conf
COPY locale.conf /etc/environment

# Add EPEL
# RUN dnf install epel-release
# Install basic packages
RUN yum -y update \
&&  yum -y install \
    autoconf \
    automake \
    bison \
    boost-devel \
    cmake \
    createrepo \
    cyrus-sasl-devel \
    docker \
#   docker-python \
    elfutils-libelf-devel \
    flex \
    gcc \
    gcc-c++ \
    gdb \
    git \
    glibc-langpack-en \
    grok-devel \
    iproute \
    kernel \
    kernel-devel \
    libnl3-devel \
    libpcap-devel \
    libtool \
    libxml2-devel \
    libzookeeper-devel \
    lz4-devel \
    libcurl-devel \
    librdkafka-devel \
    libcmocka-devel \
    libuv \
    make \
    maven \
    nodejs \
    numactl-devel \
    openssl-devel \
    protobuf \
    protobuf-devel \
    protobuf-compiler \
    python2-devel \
    python2-lxml \
# cassandra-cpp-driver  cassandra-cpp-driver-devel grok
    python2-requests \
    python2-pip \
    python2 \
    python3 \
    python3-pip \
    rpm-build \
    tbb-devel \
    tokyocabinet-devel \
    userspace-rcu-devel \
    vim \
    wget \
    yum-utils \
    zlib-devel \
&&  yum clean all \
&&  rm -rf /var/cache/yum

# Due to the absence of OS pacjages we do pip install as following:
RUN pip2 install scons fixtures sphinx grok

# Set python2 to default
RUN alternatives --set python /usr/bin/python2
RUN alternatives --set pip /usr/bin/pip2

# Initialize sandbox, get code, install build dependencies
# and fetch third parties
RUN echo "Initializing repo from $BRANCH" \
&&  repo init --no-clone-bundle -q -u https://github.com/Juniper/contrail-vnc -b $BRANCH \
&&  yum clean all \
&&  rm -rf /var/cache/yum

# DEVELOPMENT ENVIRONMENT TWEAKS
# contrail-kubernetes and contrail-config
RUN pip2 install --upgrade tox geventhttpclient

RUN echo export CONTRAIL=$CONTRAIL >> $HOME/.bashrc \
&&  echo export LD_LIBRARY_PATH=$CONTRAIL/build/lib >> $HOME/.bashrc

ADD Dockerfile entrypoint.sh $HOME/

ENTRYPOINT ["/root/entrypoint.sh"]
