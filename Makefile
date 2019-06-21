DE_DIR 	:= $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
DE_TOP  := $(abspath $(DE_DIR)/../)/

# include RPM-building targets
-include $(DE_TOP)contrail/tools/packages/Makefile

repos_dir=$(DE_TOP)src/${CANONICAL_HOSTNAME}/Juniper/
container_builder_dir=$(repos_dir)contrail-container-builder/
deployers_builder_dir=$(repos_dir)contrail-deployers-containers/
test_containers_builder_dir=$(repos_dir)contrail-test/
ansible_playbook=ansible-playbook -i inventory --extra-vars @vars.yaml --extra-vars @dev_config.yaml

all: dep rpm containers

list-containers: prepare-containers
	@$(container_builder_dir)containers/build.sh list | grep -v INFO | sed -e 's,/,_,g' -e 's/^/container-/'

list-deployers: prepare-deployers
	@$(deployers_builder_dir)containers/build.sh list | grep -v INFO | sed -e 's,/,_,g' -e 's/^/container-/'

fetch_packages:
	@$(DE_DIR)scripts/fetch-packages.sh

setup:
	@yum -y install epel-release
	@pip list | grep urllib3 >/dev/null && pip uninstall -y urllib3 || true
	@pip -q uninstall -y setuptools || true
	@yum -q reinstall -y python-setuptools

container-%: prepare-containers create-repo
	@$(container_builder_dir)containers/build.sh $(patsubst container-%,%,$(subst _,/,$(@)))

deployer-%: prepare-deployers create-repo
	@$(deployers_builder_dir)containers/build.sh $(patsubst container-%,%,$(subst _,/,$(@)))

containers-only:
	@$(container_builder_dir)containers/build.sh

containers: create-repo prepare-containers containers-only

deployers-only:
	@$(deployers_builder_dir)containers/build.sh

deployers: create-repo prepare-deployers deployers-only

test-containers-only:
	@$(DE_DIR)scripts/build-test-containers.sh

test-containers: create-repo prepare-test-containers test-containers-only

# TODO: switch next job to using deployers
deploy_contrail_kolla: containers
	@$(ansible_playbook) $(repos_dir)contrail-project-config/playbooks/kolla/centos74-provision-kolla.yaml

# TODO: think about switch next job to deployers
deploy_contrail_k8s: containers
	@$(ansible_playbook) $(repos_dir)contrail-project-config/playbooks/docker/centos74-systest-kubernetes.yaml

unittests ut: build
	@echo "$@: not implemented"

sanity: deploy
	@echo "$@: not implemented"

build deploy:
	@echo "$@: not implemented"

# utility targets
sync:
	@cd $(DE_TOP)contrail && repo sync -q --no-clone-bundle -j $(shell nproc)

prepare-containers:
	@$(DE_DIR)scripts/prepare-containers.sh

prepare-deployers:
	@$(DE_DIR)scripts/prepare-deployers.sh

prepare-test-containers:
	@$(DE_DIR)scripts/prepare-test-containers.sh

create-repo:
	@mkdir -p $(DE_TOP)contrail/RPMS
	@createrepo -C $(DE_TOP)contrail/RPMS/

# Clean targets
clean-containers:
	@test -d $(container_builder_dir) && rm -rf $(container_builder_dir) || true

clean-deployers:
	@test -d $(deployers_builder_dir) && rm -rf $(deployers_builder_dir) || true

clean-repo:
	@test -d $(DE_TOP)contrail/RPMS/repodata && rm -rf $(DE_TOP)contrail/RPMS/repodata || true

clean-rpm:
	@test -d $(DE_TOP)contrail/RPMS && rm -rf $(DE_TOP)contrail/RPMS/* || true

clean: clean-deployers clean-containers clean-repo clean-rpm
	@true

dbg:
	@echo $(DE_TOP)
	@echo $(DE_DIR)
	@echo $(SB_TOP)

.PHONY: clean-deployers clean-containers clean-repo clean-rpm setup build containers deployers createrepo unittests ut sanity all
