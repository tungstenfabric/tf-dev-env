TF_DE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TF_DE_TOP := $(abspath $(TF_DE_DIR)/../)/
SHELL=/bin/bash -o pipefail

# include RPM-building targets
-include $(TF_DE_TOP)contrail/tools/packages/Makefile

REPODIR=$(TF_DE_TOP)contrail
CONTAINER_BUILDER_DIR=$(REPODIR)/contrail-container-builder
CONTRAIL_DEPLOYERS_DIR=$(REPODIR)/contrail-deployers-containers
CONTRAIL_TEST_DIR=$(REPODIR)/third_party/contrail-test
export DEBUG
export REPODIR
export CONTRAIL_DEPLOYERS_DIR
export CONTRAIL_TEST_DIR
export CONTAINER_BUILDER_DIR
# for applying custom patches from review
export GERRIT_CHANGE_ID
export GERRIT_URL
export GERRIT_BRANCH


all: dep rpm containers

fetch_packages:
	@$(TF_DE_DIR)scripts/fetch-packages.sh

setup:
	@yum autoremove -y python-requests python-urllib3
	@pip list | grep urllib3 >/dev/null && pip uninstall -y urllib3 requests chardet || true
	@pip -q uninstall -y setuptools || true
	@yum -q reinstall -y python-setuptools
	@yum -q install -y python-requests python-urllib3

sync:
	@$(TF_DE_DIR)scripts/sync-sources.sh

##############################################################################
# RPM repo targets
create-repo:
	@mkdir -p $(REPODIR)/RPMS
	@createrepo -C $(REPODIR)/RPMS/

update-repo:
	@createrepo --update $(REPODIR)/RPMS/

clean-repo:
	@test -d $(REPODIR)/RPMS/repodata && rm -rf $(REPODIR)/RPMS/repodata || true

##############################################################################
# Contrail third party packaged
build-tpp:
	@$(TF_DE_DIR)scripts/build-tpp.sh

package-tpp:
	@$(TF_DE_DIR)scripts/package-tpp.sh

##############################################################################
# Container builder targets
prepare-containers:
	@$(TF_DE_DIR)scripts/prepare-containers.sh

list-containers: prepare-containers
	@$(CONTAINER_BUILDER_DIR)/containers/build.sh list | grep -v INFO | sed -e 's,/,_,g' -e 's/^/container-/'

container-%: create-repo prepare-containers
	@$(CONTAINER_BUILDER_DIR)/containers/build.sh $(patsubst container-%,%,$(subst _,/,$(@))) | sed "s/^/$(@): /"

containers-only:
	@$(CONTAINER_BUILDER_DIR)/containers/build.sh | sed "s/^/containers: /"

containers: create-repo prepare-containers containers-only build-src-containers

clean-containers:
	@test -d $(CONTAINER_BUILDER_DIR) && rm -rf $(CONTAINER_BUILDER_DIR) || true

build-src-containers:
	@$(TF_DE_DIR)scripts/build-src-containers.sh || true

##############################################################################
# Container deployers targets
prepare-deployers:
	@$(TF_DE_DIR)scripts/prepare-deployers.sh

list-deployers: prepare-deployers
	@$(CONTRAIL_DEPLOYERS_DIR)/containers/build.sh list | grep -v INFO | sed -e 's,/,_,g' -e 's/^/deployer-/'

deployer-%: create-repo prepare-deployers
	@$(CONTRAIL_DEPLOYERS_DIR)/containers/build.sh $(patsubst deployer-%,%,$(subst _,/,$(@))) | sed "s/^/$(@): /"

deployers-only:
	@$(CONTRAIL_DEPLOYERS_DIR)/containers/build.sh | sed "s/^/deployers: /"

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

test:
	@$(TF_DE_DIR)scripts/run-tests.sh $(TEST_PACKAGE)

##############################################################################
# Other clean targets
clean-rpm:
	@test -d $(REPODIR)/RPMS && rm -rf $(REPODIR)/RPMS/* || true

clean: clean-deployers clean-containers clean-repo clean-rpm
	@true

dbg:
	@echo $(TF_DE_TOP)
	@echo $(TF_DE_DIR)

.PHONY: clean-deployers clean-containers clean-repo clean-rpm setup build containers deployers createrepo all
