# tf-dev-env: Tungsten Fabric Developer Environment

tf-dev-env is a tool which allows building, unit-testing and linting TF
Everything is done inside a container which is controller by run.sh script with its parameters

## Hardware and software requirements

Minimal:

- instance with 2 virtual CPU, 8 GB of RAM and 64 GB of disk space

Recommended:

- instance with 4+ virtual CPU, 16+ GB of RAM and 64 GB of disk space

- Ubuntu 18.04
- CentOS 7.x
- MacOS (Experimental support, please ensure that you have brew and coreutils installed)

## Quick start

### 1. Preparation part

Enable passwordless sudo for your user
(for centos example: [serverfault page](https://serverfault.com/questions/160581/how-to-setup-passwordless-sudo-on-linux))

Install git:

``` bash
sudo yum install -y git
```

For MacOS only:

The script will install a limitted number of dependencies using `brew`
(python, docker, lsof). The `coreutils` packages is needed by the
script itself.

For Docker, the community edition will be installed if any other
version already present. Please ensure that you have started Docker Desktop
(Docker.app) application.

``` bash
brew install git
brew install coreutils
```

Create a WORKSPACE directory (build artifacts will be put there) and ```export WORKSPACE=myworkspacedir``` if you want to have specific workspace different from your current directory used by default.

### 2. Download tf-dev-env and fetch sources

``` bash
git clone http://github.com/tungstenfabric/tf-dev-env
```

Prepare the build container and fetch TF sources:

``` bash
tf-dev-env/run.sh
```

Note: The sources are fetched into the directory $WORKSPACE/contrail.
The [repo tool](https://storage.googleapis.com/git-repo-downloads/repo) is used for fetching.
The directory structure corresponds to [default.xml](https://github.com/Juniper/contrail-vnc/blob/master/default.xml)

### 3. Make changes (if any needed)

Make required changes in sources fetched to contrail directory. For example, fetch particular review for controller (you can find download link in the gerrit review):

``` bash
cd contrail/controller
git fetch "https://review.opencontrail.org/Juniper/contrail-controller" refs/changes/..... && git checkout FETCH_HEAD
cd ../../
```

### 3. Build

Run the build

``` bash
tf-dev-env/run.sh build
```

### 3. Unit-test

Run the unit-testing

``` bash
tf-dev-env/run.sh test
```

## Targets

Various optional targets can be given as parameters to run.sh command. There are simple or complex ones.

For example, The target 'build' is a sequence of fetch, configure, compile and package targets. Each target is executed once and would be skipped on next runs of the build target.
Any target can be run again explicitely if needed like:

``` bash
./run.sh compile
./run.sh package
```

Supported targets:

- fetch     - sync TF git repos
- configure - fetch third party packages and install dependencies
- compile   - buld TF binaries
- package   - package TF into docker containers
- test      - run unittests

## Advanced usage

It is possible to use  more finegraned build process via running make tool for building artifacts manually.
Note: the described way below uses internal commands and might be changed in future.

### 1. Prepare developer-sandbox container and dont run any targets

```bash
./run.sh none
```

### 2. Attach to developer-sandbox container

```bash
sudo docker exec -it tf-developer-sandbox bash
```

### 3. Prepare developer-sandbox container

``` bash
cd /root/tf-dev-env
make sync           # get latest code
make fetch_packages # pull third_party dependencies
make setup          # set up docker container
make dep            # install build dependencies
```

The descriptions of targets:

- `make sync` - sync code in `./contrail` directory using `repo` tool
- `make fetch_packages` - pull `./third_party` dependencies (after code checkout)
- `make setup` - initial configuration of image (required to run once)
- `make dep` - installs all build dependencies
- `make dep-<pkg_name>` - installs build dependencies for <pkg_name>

### 4. Building artifacts

#### RPM packages

- `make list` - lists all available RPM targets
- `make rpm` - builds all RPMs
- `make rpm-<pkg_name>` - builds single RPM for <pkg_name>

#### Container images

- `make list-containers` - lists all container targets
- `make containers` - builds all containers' images, requires RPM packages in /root/contrail/RPMS
- `make container-<container_name>` - builds single container as a target, with all docker dependencies
- `make containers-only` - build all containers without cloning of external repositories and creating of rmp rpository

#### Deployers

- `make list-deployers` - lists all deployers container targets
- `make deployers` - builds all deployers
- `make deployer-<container_name>` - builds single deployer as a target, with all docker dependencies
- `make deployers-only` - build all deployers without cloning of external repositories and creating of rmp rpository

#### Test containers

- `make test-containers` - build test containers
- `make test-containers-only` - build test containers without cloning of external repositories and creating of rmp repository

#### Clean

- `make clean{-containers,-deployers,-repo,-rpm}` - delete artifacts

#### Alternate build methods

Instead of step 4 above (which runs `scons` inside `make`), you can use `scons` directly. The steps 1-3 are still required.

``` bash
cd /root/contrail
scons # ( or "scons test" etc)
```

NOTE:
Above example build whole TungstenFabric project with default kernel headers and those
are headers for running kernel (`uname -r`). If you want to customize your manual build and
use i.e newer kernel header take a look at below examples.

In case you want to compile TungstenFabric with latest or another custom kernel headers installed
in `tf-developer-sandbox` container, then you have to run scons with extra arguments:

``` bash
RTE_KERNELDIR=/path/to/custom_kernel_headers scons --kernel-dir=/path/to/custom_kernel_headers
```

To alter default behaviour and build TF without support for DPDK just provide the `--without-dpdk` flag:

``` bash
scons --kernel-dir=/path/to/custom_kernel_headers --without-dpdk
```

To build only specific module like i.e `vrouter`:

``` bash
scons --kernel-dir=/path/to/custom_kernel_headers vrouter
```

To build and run unit test against your code:

``` bash
RTE_KERNELDIR=/path/to/custom_kernel_headers scons --kernel-dir=/path/to/custom_kernel_headers test
```

## Customizing dev-env container

There are several options to change standard behaviour of `tf-developer-sandbox` container:

- Attach external sources to container
- Use external docker registry to store TF container images

### External sources

You can attach you host contrail-vnc sources instead of syncing them from github.com.

There are special environment variables to set correct behaviour:

- **CONTRAIL_DIR** stores host's path to initialized contrail-vnc repository.
- **SITE_MIRROR** stores contrail third-party repository url. It used to collect external packages required by *contrail-third-party* tools. There is an example:

``` bash
export CONTRAIL_DIR=$HOME/my-tf-sources
./run.sh configure
./run.sh compile
./run.sh package
```

### External docker registry

Environment variables **REGISTRY_IP** and **REGISTRY_PORT** stores external docker registry connection information where TF's containers would be stored.
There is an example:

``` bash
export CONTRAIL_DEPLOY_REGISTRY=0
export REGISTRY_IP=10.1.1.190
export REGISTRY_PORT=5000
./run.sh build
```

## Full TF dev suite

IMPORTANT: some of the parts and pieces are still under construction

Full TF dev suite consists of:

- [tf-dev-env](https://github.com/tungstenfabric/tf-dev-env) - develop and build TF
- [tf-devstack](https://github.com/tungstenfabric/tf-devstack) - deploy TF
- [tf-test](https://github.com/tungstenfabric/tf-test) - test deployed TF

Each of these tools can be used separately or in conjunction with the other two. They are supposed to be invoked in the sequence they were listed and produce environment (conf files and variables) seamlessly consumable by the next tool.

They provide two main scripts:

- run.sh
- cleanup.sh

Both these scripts accept targets (like ``run.sh build``) for various actions.

Typical scenarios are (examples are given for centos):

## Developer's scenario

Typical developer's scenario could look like this:

### 1. Preparation part

Run a machine, for example AWS instance or a VirtualBox (powerful with lots of memory - 16GB+ recommended- )

Enable passwordless sudo for your user
(for centos example: [serverfault page](https://serverfault.com/questions/160581/how-to-setup-passwordless-sudo-on-linux))

Install git:

``` bash
sudo yum install -y git
```

### 2. tf-dev-env part

Clone tf-dev-env:

``` bash
git clone http://github.com/tungstenfabric/tf-dev-env
```
Switch to a branch other than master (if necessary):

``` bash
export GERRIT_BRANCH="branch_name"
```

Prepare the build container and fetch TF sources:

``` bash
tf-dev-env/run.sh
```

Make required changes in sources fetched to contrail directory. For example, fetch particular review for controller (you can find download link in the gerrit review):

``` bash
cd contrail/controller
git fetch "https://review.opencontrail.org/Juniper/contrail-controller" refs/changes/..... && git checkout FETCH_HEAD
cd ../../
```

Run TF build:

``` bash
tf-dev-env/run.sh build
```

### 3. tf-devstack part

Clone tf-devstack:

``` bash
git clone http://github.com/tungstenfabric/tf-devstack
```

Deploy TF by means of k8s manifests, for example:

``` bash
tf-devstack/k8s_manifests/run.sh
```

#### 3.1 Using targets

If you're on VirtualBox, for example, and want to snapshot k8s deployment prior to TF deployment you can use run.sh targets like:

``` bash
tf-devstack/k8s_manifests/run.sh platform
```

and then:

``` bash
tf-devstack/k8s_manifests/run.sh tf
```

Along with cleanup of particular target you can do tf deployment multiple times:

``` bash
tf-devstack/k8s_manifests/cleanup.sh tf
```

### 4. tf-test part

Clone tf-test:

``` bash
git clone http://github.com/tungstenfabric/tf-test
```

Test the deployment by smoke tests, for example:

``` bash
tf-test/smoke/run.sh
```

## Evaluation scenario

Typical developer's scenario could look like this:

### 1. Preparation part

Run a machine, for example AWS instance or a VirtualBox (powerful with lots of memory - 16GB+ recommended- )

Enable passwordless sudo for your user
(for centos example: [serverfault page](https://serverfault.com/questions/160581/how-to-setup-passwordless-sudo-on-linux))

Install git:

``` bash
sudo yum install -y git
```

### 2. tf-devstack part

Clone tf-devstack:

``` bash
git clone http://github.com/tungstenfabric/tf-devstack
```

Deploy TF by means of k8s manifests, for example:

``` bash
tf-devstack/k8s_manifests/run.sh
```

Or if you want to deploy with the most recent sources from master use:

``` bash
tf-devstack/k8s_manifests/run.sh master
```

[Slack]: https://tungstenfabric.slack.com/messages/C0DQ23SJF/
[Google Group]: https://groups.google.com/forum/#!forum/tungsten-dev
