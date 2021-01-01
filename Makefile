
SHELL=sh
WGET=wget --no-verbose --show-progress

DOCKER=docker
DOCKER_SOCK=/var/run/docker.sock

KIND_VERSION=0.9.0
DOCKER_VERSION=19.03.14

K8S_VERSION=1.19.6
KUBE_CONFIG=/etc/kubernetes/admin.conf

KIND_IMAGE=kind:$(KIND_VERSION)
KUBECTL_IMAGE=kubectl:$(K8S_VERSION)

.PHONY: kind
kind: kind-linux-amd64 docker-linux-amd64
	$(DOCKER) build -t $(KIND_IMAGE) .

kind-linux-amd64:
	$(WGET) https://github.com/kubernetes-sigs/kind/releases/download/v$(KIND_VERSION)/kind-linux-amd64
	chmod +x $@

docker-linux-amd64:
	$(WGET) https://download.docker.com/linux/static/stable/x86_64/docker-$(DOCKER_VERSION).tgz
	tar xzf docker-$(DOCKER_VERSION).tgz docker/docker && mv docker/docker $@ && rmdir docker

.PHONY: kubectl
kubectl: kubectl-linux-amd64
	$(DOCKER) build -t $(KUBECTL_IMAGE) -f Dockerfile.kubectl .

kubectl-linux-amd64:
	$(WGET) https://storage.googleapis.com/kubernetes-release/release/v$(K8S_VERSION)/bin/linux/amd64/kubectl
	mv kubectl $@ && chmod +x $@

.PHONY: version
version:
	$(DOCKER) run $(KIND_IMAGE) kind version
	$(DOCKER) run -v $(DOCKER_SOCK):$(DOCKER_SOCK) $(KIND_IMAGE) docker --host=unix://$(DOCKER_SOCK) version --format '{{.Client}}'
	@touch .kubeconfig
	$(DOCKER) run --network=host -v $(PWD)/.kubeconfig:$(KUBE_CONFIG) $(KUBECTL_IMAGE) kubectl --kubeconfig=$(KUBE_CONFIG) version --client

test: kubectl-linux-amd64
	$(DOCKER) run -v $(DOCKER_SOCK):$(DOCKER_SOCK) $(KIND_IMAGE) kind create cluster --name=test
	$(DOCKER) run -v $(DOCKER_SOCK):$(DOCKER_SOCK) $(KIND_IMAGE) docker ps --filter=name=test-control-plane
	@> .kubeconfig
	$(DOCKER) run -v $(DOCKER_SOCK):$(DOCKER_SOCK) -v $(PWD)/.kubeconfig:$(KUBE_CONFIG) $(KIND_IMAGE) kind export kubeconfig --name=test --kubeconfig=$(KUBE_CONFIG)
	$(DOCKER) run --network=host -v $(PWD)/.kubeconfig:$(KUBE_CONFIG) $(KUBECTL_IMAGE) kubectl --kubeconfig=$(KUBE_CONFIG) cluster-info
	sleep 30
	$(DOCKER) run --network=host -v $(PWD)/.kubeconfig:$(KUBE_CONFIG) $(KUBECTL_IMAGE) kubectl --kubeconfig=$(KUBE_CONFIG) get nodes
	$(DOCKER) run --network=host -v $(PWD)/.kubeconfig:$(KUBE_CONFIG) $(KUBECTL_IMAGE) kubectl --kubeconfig=$(KUBE_CONFIG) get pods -A
	$(DOCKER) run -v $(DOCKER_SOCK):$(DOCKER_SOCK) $(KIND_IMAGE) kind delete cluster --name=test
	@rm .kubeconfig

