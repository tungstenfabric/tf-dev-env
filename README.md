# tf-dev-env: Tungsten Fabric Developer Environment

## Problems? Need Help?

This repository is a fork of existing juniper/contrail-dev-env repository which is
actively maintained via [Gerrit]. This repository at the moment is not connected to
gerrit and can be modified via github PRs.
You can ask for help on [Slack] but if no one replies right away, you can also post
to the new [Google Group].

## Documentation for dev-env components

Since dev-env uses generally available TF components, please refer to following documentation pages:

1. for packages generation: [contrail-packages](https://github.com/Juniper/contrail-packages/blob/master/README.md)
2. for building containers: [contrail-container-builder](https://github.com/Juniper/contrail-container-builder/blob/master/README.md) and [contrail-deployers-containers](https://github.com/Juniper/contrail-deployers-containers/blob/master/README.md)
3. for deployments: [contrail-ansible-deployer](https://github.com/Juniper/contrail-ansible-deployer/blob/master/README.md)

## Container-based (standard)

There are 2 official sources of containers for dev-env:

1. Released images on docker hub [opencontrail](https://hub.docker.com/r/opencontrail/developer-sandbox-centos/), tagged with released version.
2. Nightly images on docker hub [opencontrailnightly](https://hub.docker.com/r/opencontrailnightly/developer-sandbox-centos/), tagged with corresponding development branch.
   *Note:* tag `latest` points to `master` branch.

You can also use your own image, built using `container/build.sh` script.

### 1. Install docker
```
For mac:          https://docs.docker.com/docker-for-mac/install/#download-docker-for-mac
```
For CentOS/RHEL/Fedora linux host:
```
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce-18.03.1.ce
```
For Ubuntu linux host:
```
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository -y -u "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get install -y "docker-ce=18.06.3~ce~3-0~ubuntu"
```

NOTE (only if you hit any issues):
Make sure that your docker engine supports images bigger than 10GB. For instructions,
see here: https://stackoverflow.com/questions/37100065/resize-disk-usage-of-a-docker-container
Make sure that there is TCP connectivity allowed between the containers in the default docker bridge network,
(for example disable firewall).

### 2. Make a workspace directory (will be used for contrail sources and build artifacts)
Note, the volume should have at least 64GB of free space for build purposes.
```
mkdir tf
cd tf
```

### 3. Clone dev setup repo
Install git if needed first and then:
```
git clone https://github.com/tungstenfabric/tf-dev-env
```

### 4. Execute startup script to start all required containers
```
./tf-dev-env/run.sh
```

**Note:** This command runs container `opencontrailnightly/developer-sandbox-centos:master` from [opencontrailnightly docker hub](https://hub.docker.com/r/opencontrailnightly/developer-sandbox/) by
default. You can specify different image and/or tag using flags, e.g.

1. to develop on nightly R5.0 container use: `./run.sh -t R5.1`
2. to develop code based on a tagged `r5.1` release, use: `./run.sh -i opencontrail/developer-sandbox -t r5.1`
Also you can export BUILD_DEV_ENV=1 to explicit build of sandbox container locally if sandbox is not run yet.
Please note - if you don't pass '-t' option (or pass it as 'latest') then latest tag for sandbox image and master branch of contrail-vnc repo will be used. If you pass something else then this tag will be used for sandbox image and contrail-vnc will be cloned by the same branch name.

##### docker ps -a should show these 3 containers #####
```
tf-developer-sandbox [For running scons, unit-tests etc]
tf-dev-env-rpm-repo  [Repo server for contrail RPMs after they are build]
tf-dev-env-registry  [Registry for contrail containers after they are built]
```

### 5. Attach to developer-sandbox container

```
sudo docker attach tf-developer-sandbox
```

### 6. Prepare developer-sandbox container

Required first steps in the container:

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

### 7. Make artifacts

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

### 8. Testing the deployment

See https://github.com/Juniper/contrail-ansible-deployer/wiki/Contrail-with-Openstack-Kolla .
Set `CONTRAIL_REGISTRY` to `registry:5000` to use containers built in the previous step.

### Alternate build methods

Instead of step 6 above (which runs `scons` inside `make`), you can use `scons` directly. The steps 1-4 are still required. 

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
  - Build dev-env container instead of pulling it from registry
  - Attach external sources to container
  - Use external docker registry to store contrail-images
  - Build TF's rpms and containers on startup

### Building dev-env docker image

There are several environment variables are used to build dev-env docker image:
  - **BUILD_DEV_ENV** is used to build dev-env docker image and runing `tf-developer-sandbox` container from it. To build new image set **BUILD_DEV_ENV** to 1.
  - **BUILD_DEV_ENV_ON_PULL_FAIL** is used to build dev-env docker image if `docker pull` command has failed.

### External sources

You can attach you host contrail-vnc sources instead of syncing them from github.com.

There are special environment variables to set correct behaviour:
  - **SRC_ROOT** stores host's path to initialized contrail-vnc repository.
  - **EXTERNAL_REPOS** stores path to external repositories like *contrail-containers-builder*, *contrail-deployers-containers* and *contrail-test*. These repositories must be placed there in format `<server_name>/<namespace>/<project_name>` (for example `review.opencontrail.org/Juniper/contrail-containers-builder`)
  - **CANONICAL_HOSTNAME** stores `<server_name>`. It used to find required repositories in **EXTERNAL_REPOS**.
  - **SITE_MIRROR** stores contrail third-party repository url. It used to collect external packages required by *contrail-third-party* tools.

### External docker registry

Environment variables **REGISTRY_IP** and **REGISTRY_PORT** stores external docker registry connection information where TF's containers would be stored.

### Run build of rpms and containers on startup

There is an option to use `tf-developer-sandbox` container just to build TF rpms and containers. **BUILD** environment variable manages this behaviour. `tf-developer-sandbox` container builds and stores all artifacts and then exits if set **BUILD** to **'true'**. So run TF build again just start `tf-developer-sandbox` with the command `docker start -i tf-developer-sandbox`.


[Slack]: https://tungstenfabric.slack.com/messages/C0DQ23SJF/
[Google Group]: https://groups.google.com/forum/#!forum/tungsten-dev
