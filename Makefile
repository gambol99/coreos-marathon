#
#   Author: Rohith
#   Date: 2015-06-15 16:37:47 +0100 (Mon, 15 Jun 2015)
#
#  vim:ts=2:sw=2:et
#

SBX_DOMAIN=sbx.example.com
BASTION=10.250.1.201
CORE_BOXES=core101 core102 core103
MANIFESTS=$(shell ls manifests)
FLEETCTL=$(shell which fleetctl)
ETCDCTL=$(shell which etcdctl)
HOSTIP=$(shell hostname -i)

.PHONY: build clean registry units all sbx sbx-play marathon-play mesos-play mirror mirror-clean mirror-stop

default: sbx

mirror:
	@if sudo docker ps -a | grep -q docker-mirror; then sudo docker start docker-mirror; else make registry; fi
	echo "place the following into you environment"
	echo "export DOCKER_MIRROR=10.250.1.1"

mirror-clean:
	# Cleaning up the docker mirror container
	@if sudo docker ps | grep -q docker-mirror; then sudo docker kill docker-mirror; fi
	@if sudo docker ps -a | grep -q docker-mirror; then sudo docker rm docker-mirror; fi

mirror-stop:
	# Stopping the mirror
	@if sudo docker ps | grep -q docker-mirror; then sudo docker stop docker-mirror; fi

registry:
	sudo docker run -d -p 5000:5000 --net=host \
    --name docker-mirror \
    -e STANDALONE=false \
    -e MIRROR_SOURCE=https://registry-1.docker.io \
    -e MIRROR_SOURCE_INDEX=https://index.docker.io \
    -v ${PWD}/registry:/tmp/registry \
    registry

clean:
	vagrant destroy -f
	rm -f ${HOME}/.fleetctl/known_hosts
	rm -rf ./extra_disks

halt:
	vagrant halt
	make mirror-stop

units:
	fleetctl --strict-host-key-checking=false --tunnel ${BASTION} list-units

all: sbx

marathon:
	# waiting for the boxes to come up
	while ! bash -c "echo > /dev/tcp/${BASTION}/22"; do sleep 0.5; done
	make sbx-play

coreos:
	$(foreach I, $(CORE_BOXES), \
		vagrant up /$(I)/ ; \
	)

sbx: coreos
	make mesos-play
	make marathon-play

mesos-play:
	# You can nw login into the box ssh -u core <FDQN>
	# Or show the units: make units
	# Note: if you dont have fleetctl on your machine, you'll need to download it from github or
	# ssh into the box, clone this repo and perform the below manually (which is crap!!)
	# alias fleetctl="fleetctl --strict-host-key-checking=false --endpoint=http://10.250.1.201:4001"
	@if [ -n "${FLEETCTL}" ]; then fleetctl --endpoint=http://${BASTION}:4001 start units/mesos/*.service 2>/dev/null || true; fi

marathon-play:
	@if [ -n "${FLEETCTL}" ]; then fleetctl --endpoint=http://${BASTION}:4001 start units/marathon/*.service 2>/dev/null || true; fi
