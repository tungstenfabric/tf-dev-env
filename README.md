# tf-dev-env: Tungsten Fabric Developer Environment

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

Typical scenarios is (examples are given for centos):

### 1. Preparation part

Run a machine, for example AWS instance or a VirtualBox (at least 4 cores is recommended - the more CPUs the faster build; memory - 16GB+ recommended, at least 64GB of free disk space)

Enable passwordless sudo for your user
(for centos example: [serverfault page](https://serverfault.com/questions/160581/how-to-setup-passwordless-sudo-on-linux))

Make a workspace directory. This directory be used for storing build artifacts.
``` bash
mkdir ~/tf
cd ~/tf
```
Note: tf-dev-env uses current dir as a workspace byt default, in order to run tf-dev-env scripts from different folders it is needed to export WORKSPACE env variable to point to the workspace, e.g.:
``` bash
export WORKSPACE=~/tf
```
(to make it permanent add this line into the end of your ~/.bashrc)

Install git and make a folder for a workspace:

``` bash
sudo yum install -y git
```
The volume should have at least 64GB of free space for build purposes.

### 2. Download tf-dev-env

``` bash
git clone http://github.com/tungstenfabric/tf-dev-env
```

Prepare the build container and fetch TF sources:

``` bash
tf-dev-env/run.sh
```
Note: The sources are fetched into the directory $WORKSPACE/contrail.
The tool https://storage.googleapis.com/git-repo-downloads/repo is used for fetching.
The directory structure corresponds to the 
https://github.com/Juniper/contrail-vnc/blob/master/default.xml


### 3. Make changes (if any needed)

Make required changes in sources fetched to contrail directory. For example, fetch particular review for controller (you can find download link in the gerrit review):

``` bash
cd contrail/controller
git fetch "https://review.opencontrail.org/Juniper/contrail-controller" refs/changes/..... && git checkout FETCH_HEAD
cd ../../
```

### 3. Build artifact

``` bash
tf-dev-env/run.sh build
```
The target 'build' is a sequence of fetch, configure, compile and package targets. Each target is executed once and would be skipped on next runs of the build target.
Any tartet can be run again explicitely if needed like:
``` bash
./run.sh compile
./run.sh package
```

Supported targets:
  * fetch     - sync TF git repos
  * configure - fetch third party packages and install dependencies
  * compile   - buld TF binaries
  * package   - package TF into docker containers
  * test      - run unittests


## Advanced usage

It is possible to use  more finegraned build process via running make tool for building artifacts manually.
Note: the described way below uses internal commands and might be changed in future.

### 1. Prepare developer-sandbox container and dont run any targets

```bash
./run.sh none
```

### 2. Attach to developer-sandbox container

```bash
sudo docker attach tf-developer-sandbox
```

### 3. Prepare developer-sandbox container

```
cd /root/tf-dev-env
make sync           # get latest code
make fetch_packages # pull third_party dependencies
make setup          # set up docker container
make dep            # install build dependencies
```

The descriptions of targets:

* `make sync` - sync code in `./contrail` directory using `repo` tool
* `make fetch_packages` - pull `./third_party` dependencies (after code checkout)
* `make setup` - initial configuration of image (required to run once)
* `make dep` - installs all build dependencies
* `make dep-<pkg_name>` - installs build dependencies for <pkg_name>

### 4. Building artifacts

#### RPM packages

* `make list` - lists all available RPM targets
* `make rpm` - builds all RPMs
* `make rpm-<pkg_name>` - builds single RPM for <pkg_name>

#### Container images

* `make list-containers` - lists all container targets
* `make containers` - builds all containers' images, requires RPM packages in /root/contrail/RPMS
* `make container-<container_name>` - builds single container as a target, with all docker dependencies
* `make containers-only` - build all containers without cloning of external repositories and creating of rmp rpository

#### Deployers

* `make list-deployers` - lists all deployers container targets
* `make deployers` - builds all deployers
* `make deployer-<container_name>` - builds single deployer as a target, with all docker dependencies
* `make deployers-only` - build all deployers without cloning of external repositories and creating of rmp rpository

#### Test containers

* `make test-containers` - build test containers
* `make test-containers-only` - build test containers without cloning of external repositories and creating of rmp repository

#### Clean

* `make clean{-containers,-deployers,-repo,-rpm}` - delete artifacts


#### Alternate build methods

Instead of step 4 above (which runs `scons` inside `make`), you can use `scons` directly. The steps 1-3 are still required.

```
cd /root/contrail
scons # ( or "scons test" etc)
```

NOTE:
Above example build whole TungstenFabric project with default kernel headers and those
are headers for running kernel (`uname -r`). If you want to customize your manual build and
use i.e newer kernel header take a look at below examples.

In case you want to compile TungstenFabric with latest or another custom kernel headers installed
in `tf-developer-sandbox` container, then you have to run scons with extra arguments:

```
RTE_KERNELDIR=/path/to/custom_kernel_headers scons --kernel-dir=/path/to/custom_kernel_headers
```

To alter default behaviour and build TF without support for DPDK just provide the `--without-dpdk` flag:

```
scons --kernel-dir=/path/to/custom_kernel_headers --without-dpdk
```

To build only specific module like i.e `vrouter`:

```
scons --kernel-dir=/path/to/custom_kernel_headers vrouter
```

To build and run unit test against your code:

```
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
```bash
export CONTRAIL_DIR=$HOME/my-tf-sources
./run.sh configure
./run.sh compile
./run.sh package
```

### External docker registry

Environment variables **REGISTRY_IP** and **REGISTRY_PORT** stores external docker registry connection information where TF's containers would be stored.
There is an example:
```bash
export CONTRAIL_DEPLOY_REGISTRY=0
export REGISTRY_IP=10.1.1.190
export REGISTRY_PORT=5000
./run.sh build
```

[Slack]: https://tungstenfabric.slack.com/messages/C0DQ23SJF/
[Google Group]: https://groups.google.com/forum/#!forum/tungsten-dev
