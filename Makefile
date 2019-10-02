TF_DE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TF_DE_TOP := $(abspath $(TF_DE_DIR)/../)/
SHELL=/bin/bash -o pipefail

# include RPM-building targets
-include $(TF_DE_TOP)contrail/tools/packages/Makefile

REPODIR=$(TF_DE_TOP)contrail
CONTAINER_BUILDER_DIR=$(REPODIR)/contrail-container-builder
CONTRAIL_DEPLOYERS_DIR=$(REPODIR)/contrail-deployers-containers
CONTRAIL_TEST_DIR=$(REPODIR)/third_party/contrail-test

repos_dir=$(TF_DE_TOP)src/${CANONICAL_HOSTNAME}/Juniper/
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
	@$(CONTAINER_BUILDER_DIR)containers/build.sh list | grep -v INFO | sed -e 's,/,_,g' -e 's/^/container-/'

container-%: create-repo prepare-containers
	@$(CONTAINER_BUILDER_DIR)containers/build.sh $(patsubst container-%,%,$(subst _,/,$(@))) | sed "s/^/$(@): /"

containers-only:
	@$(CONTAINER_BUILDER_DIR)containers/build.sh | sed "s/^/containers: /"

containers: create-repo prepare-containers containers-only

clean-containers:
	@test -d $(CONTAINER_BUILDER_DIR) && rm -rf $(CONTAINER_BUILDER_DIR) || true


##############################################################################
# Container deployers targets

prepare-deployers:
	@$(TF_DE_DIR)scripts/prepare-deployers.sh

list-deployers: prepare-deployers
	@$(CONTRAIL_DEPLOYERS_DIR)containers/build.sh list | grep -v INFO | sed -e 's,/,_,g' -e 's/^/deployer-/'

deployer-%: create-repo prepare-deployers
	@$(CONTRAIL_DEPLOYERS_DIR)containers/build.sh $(patsubst deployer-%,%,$(subst _,/,$(@))) | sed "s/^/$(@): /"

deployers-only:
		@$(CONTRAIL_DEPLOYERS_DIR)containers/build.sh | sed "s/^/deployers: /"

deployers: create-repo prepare-deployers
	@$(MAKE) -C $(TF_DE_DIR) deployers-only

clean-deployers:
	@test -d $(CONTRAIL_DEPLOYERS_DIR) && rm -rf $(CONTRAIL_DEPLOYERS_DIR) || true

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
