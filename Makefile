TF_DE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TF_DE_TOP := $(abspath $(TF_DE_DIR)/../)/
SHELL=/bin/bash -o pipefail

# include RPM-building targets
-include $(TF_DE_TOP)contrail/tools/packages/Makefile

repos_dir=$(TF_DE_TOP)src/${CANONICAL_HOSTNAME}/Juniper/
container_builder_dir=$(repos_dir)contrail-container-builder/
test_containers_builder_dir=$(repos_dir)contrail-test/
ansible_playbook=ansible-playbook -i inventory --extra-vars @vars.yaml --extra-vars @dev_config.yaml

all: dep rpm containers

fetch_packages:
	@$(TF_DE_DIR)scripts/fetch-packages.sh

setup:
	@pip list | grep urllib3 >/dev/null && pip uninstall -y urllib3 || true
	@pip -q uninstall -y setuptools || true
	@yum -q reinstall -y python2-setuptools

sync:
	@cd $(TF_DE_TOP)contrail && repo sync -q --no-clone-bundle -j $(shell nproc)

##############################################################################
# RPM repo targets
create-repo:
	@mkdir -p $(TF_DE_TOP)contrail/RPMS
	@createrepo -C $(TF_DE_TOP)contrail/RPMS/

clean-repo:
	@test -d $(TF_DE_TOP)contrail/RPMS/repodata && rm -rf $(TF_DE_TOP)contrail/RPMS/repodata || true

##############################################################################
# Container builder targets
prepare-containers:
	@$(TF_DE_DIR)scripts/prepare-containers.sh

list-containers: prepare-containers
	@$(container_builder_dir)containers/build.sh list | grep -v INFO | sed -e 's,/,_,g' -e 's/^/container-/'

container-%: create-repo prepare-containers
	@$(container_builder_dir)containers/build.sh $(patsubst container-%,%,$(subst _,/,$(@))) | sed "s/^/$(@): /"

containers-only:
	@$(container_builder_dir)containers/build.sh | sed "s/^/containers: /"

containers: create-repo prepare-containers containers-only

clean-containers:
	@test -d $(container_builder_dir) && rm -rf $(container_builder_dir) || true


##############################################################################
# Container deployers targets
deployers_builder_dir=$(repos_dir)contrail-deployers-containers/

prepare-deployers:
	@$(TF_DE_DIR)scripts/prepare-deployers.sh

list-deployers: prepare-deployers
	@$(deployers_builder_dir)containers/build.sh list | grep -v INFO | sed -e 's,/,_,g' -e 's/^/deployer-/'

deployer-%: create-repo prepare-deployers
	@$(deployers_builder_dir)containers/build.sh $(patsubst deployer-%,%,$(subst _,/,$(@))) | sed "s/^/$(@): /"

deployers-only:
	@$(deployers_builder_dir)containers/build.sh | sed "s/^/deployers: /"

deployers: create-repo prepare-deployers
	@$(MAKE) -C $(TF_DE_DIR) deployers-only

clean-deployers:
	@test -d $(deployers_builder_dir) && rm -rf $(deployers_builder_dir) || true

##############################################################################
# Test container targets
prepare-test-containers:
	@$(TF_DE_DIR)scripts/prepare-test-containers.sh

test-containers-only:
	@$(TF_DE_DIR)scripts/build-test-containers.sh | sed "s/^/test-containers: /"

test-containers: create-repo prepare-test-containers test-containers-only


##############################################################################
# TODO: switch next job to using deployers
deploy_contrail_kolla: containers
	@$(ansible_playbook) $(repos_dir)contrail-project-config/playbooks/kolla/centos74-provision-kolla.yaml

# TODO: think about switch next job to deployers
deploy_contrail_k8s: containers
	@$(ansible_playbook) $(repos_dir)contrail-project-config/playbooks/docker/centos74-systest-kubernetes.yaml


##############################################################################
unittests ut: build
	@echo "$@: not implemented"

sanity: deploy
	@echo "$@: not implemented"

build deploy:
	@echo "$@: not implemented"


##############################################################################
# Other clean targets
clean-rpm:
	@test -d $(TF_DE_TOP)contrail/RPMS && rm -rf $(TF_DE_TOP)contrail/RPMS/* || true

clean: clean-deployers clean-containers clean-repo clean-rpm
	@true

dbg:
	@echo $(TF_DE_TOP)
	@echo $(TF_DE_DIR)

.PHONY: clean-deployers clean-containers clean-repo clean-rpm setup build containers deployers createrepo unittests ut sanity all
