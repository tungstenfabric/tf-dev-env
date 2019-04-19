# contrail-dev-env: Contrail Developer Environment

## Problems? Need Help?

This repository is actively maintained via [Gerrit] so please let us know about
any problems you find. You can ask for help on [Slack] but if no one replies
right away, go ahead and open a bug on [JIRA] and label the bug with the
label "dev-env" and it will get looked at soon. You can also post to the new
[Google Group] if you're having trouble but don't know if the problem is a bug
or a mistake on your part.

## Documentation for dev-env components

Since dev-env uses generally available contrail components, please refer to following documentation pages:

1. for packages generation: [contrail-packages](https://github.com/Juniper/contrail-packages/blob/master/README.md)
2. for building containers: [contrail-container-builder](https://github.com/Juniper/contrail-container-builder/blob/master/README.md) and [contrail-deployers-containers](https://github.com/Juniper/contrail-deployers-containers/blob/master/README.md)
3. for deployments: [contrail-ansible-deployer](https://github.com/Juniper/contrail-ansible-deployer/blob/master/README.md)

## Container-based (standard)

There are 2 official sources of containers for dev-env:

1. Released images on docker hub [opencontrail](https://hub.docker.com/r/opencontrail/developer-sandbox/), tagged with released version.
2. Nightly images on docker hub [opencontrailnightly](https://hub.docker.com/r/opencontrailnightly/developer-sandbox/), tagged with corresponding development branch.
   *Note:* tag `latest` points to `master` branch.

You can also use your own image, built using `container/build.sh` script.

### 1. Install docker
```
For mac:          https://docs.docker.com/docker-for-mac/install/#download-docker-for-mac
```
For CentOS/RHEL/Fedora linux host:
```
yum install docker
```
For Ubuntu linux host:
```
apt install docker.io
```

NOTE (only if you hit any issues):
Make sure that your docker engine supports images bigger than 10GB. For instructions,
see here: https://stackoverflow.com/questions/37100065/resize-disk-usage-of-a-docker-container
Make sure that there is TCP connectivity allowed between the containers in the default docker bridge network,
(for example disable firewall).

### 2. Clone dev setup repo
```
git clone https://github.com/Juniper/contrail-dev-env
cd contrail-dev-env
```

### 3. Execute script to start 3 containers
```
sudo ./startup.sh
```

**Note:** This command runs container `opencontrailnightly/developer-sandbox:master` from [opencontrailnightly docker hub](https://hub.docker.com/r/opencontrailnightly/developer-sandbox/) by
default. You can specify different image and/or tag using flags, e.g.

1. to develop on nightly R5.0 container use: `sudo ./startup.sh -t R5.0`
2. to develop code based on a tagged `r5.0` release, use: `sudo ./startup.sh -i opencontrail/developer-sandbox -t r5.0`

##### docker ps -a should show these 3 containers #####
```
contrail-developer-sandbox [For running scons, unit-tests etc]
contrail-dev-env-rpm-repo  [Repo server for contrail RPMs after they are build]
contrail-dev-env-registry  [Registry for contrail containers after they are built]
```

### 4. Attach to developer-sandbox container

```
docker attach contrail-developer-sandbox
```

### 5. Prepare developer-sandbox container

Required first steps in the container:

```
cd /root/contrail-dev-env
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

### 6. Make artifacts

#### RPM packages

* `make list` - lists all available RPM targets
* `make rpm` - builds all RPMs
* `make rpm-<pkg_name>` - builds single RPM for <pkg_name>

#### Container images

* `make list-containers` - lists all container targets
* `make containers` - builds all containers' images, requires RPM packages in /root/contrail/RPMS
* `make container-<container_name>` - builds single container as a target, with all docker dependencies

#### Deployers

* `make list-deployers` - lists all deployers container targets
* `make deployers` - builds all deployers
* `make deployer-<container_name>` - builds single deployer as a target, with all docker dependencies

#### Test containers

* `make test-containers` - build test containers

#### Clean

* `make clean{-containers,-deployers,-repo,-rpm}` - delete artifacts

### 7. Testing the deployment

See https://github.com/Juniper/contrail-ansible-deployer/wiki/Contrail-with-Openstack-Kolla .
Set `CONTRAIL_REGISTRY` to `registry:5000` to use containers built in the previous step.

### Alternate build methods

Instead of step 5 above (which runs `scons` inside `make`), you can use `scons` directly. The steps 1-4 are still required. 

```
cd /root/contrail
scons # ( or "scons test" etc)
```

NOTE:
Above example build whole TungstenFabric project with default kernel headers and those
are headers for running kernel (`uname -r`). If you want to customize your manual build and
use i.e newer kernel header take a look at below examples.

In case you want to compile TungstenFabric with latest or another custom kernel headers installed
in `contrail-developer-sanbox` container, then you have to run scons with extra arguments:

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


## Bring-your-own-VM (experimental)

*Note:* only RedHat 7 and CentOS 7 are supported at this time!

1. Clone this repository to a directory on a VM.
2. Run `vm-dev-env/init.sh` (you might be asked for your password as some steps require the use of sudo).
  a. You can also run `vm-dev-env/init.sh -n` if you don't want to clone work directory on a VM. Then you have to mount sandbox to directory named `contrail` next to `contrail-dev-env`.
3. Run `make fetch_packages` to pull dependencies to `contrail/third_party`
4. Run `sudo ./startup.sh -b` to start required containers.
4. You can use the Makefile targets described above to build contrail.

[Gerrit]: https://review.opencontrail.org/#/admin/projects/Juniper/contrail-dev-env
[Slack]: https://tungstenfabric.slack.com/messages/C0DQ23SJF/
[JIRA]: https://jira.tungsten.io/secure/Dashboard.jspa
[Google Group]: https://groups.google.com/forum/#!forum/tungsten-dev
