# set the shell to bash always
SHELL         := /bin/bash

# set make and shell flags to exit on errors
#MAKEFLAGS     += --warn-undefined-variables
.SHELLFLAGS   := -euo pipefail -c

export $(PROJECT_ID)
export CLUSTER_PROJECT_ID=$(PROJECT_ID)
export CLUSTER_NAME=kf-cluster
export COMPUTE_ZONE=us-central1-a
export COMPUTE_REGION=us-central1
export CLUSTER_LOCATION=${COMPUTE_ZONE}
export KF_VERSION=v2.2.0
export TEKTON_VERSION=v0.19.0

export WI_ANNOTATION=iam.gke.io/gcp-service-account=${CLUSTER_NAME}-sa@${CLUSTER_PROJECT_ID}.iam.gserviceaccount.com

export CONTAINER_REGISTRY=${COMPUTE_REGION}-docker.pkg.dev/${CLUSTER_PROJECT_ID}/${CLUSTER_NAME}
export DOMAIN='$(SPACE_NAME).$(CLUSTER_INGRESS_IP).nip.io'

UNAME := $(shell uname)

ifeq ($(UNAME), Linux)
	export OS_VERSION=linux
endif
ifeq ($(UNAME), Darwin)
	export OS_VERSION=darwin
endif

cluster_get_cred:
	gcloud container clusters get-credentials ${CLUSTER_NAME} \
			--project=$(PROJECT_ID) \
			--zone=${CLUSTER_LOCATION}

gcloud_auth:
	gcloud auth configure-docker ${COMPUTE_REGION}-docker.pkg.dev

gcloud_login:
	gcloud auth login
	gcloud components update

auth: cluster_get_cred gcloud_auth gcloud_login

download_asm:
	mkdir asm
	curl https://storage.googleapis.com/csm-artifacts/asm/install_asm_1.7 > asm/install_asm
	curl https://storage.googleapis.com/csm-artifacts/asm/install_asm_1.7.sha256 > asm/install_asm.sha256
	#sha256sum -c --ignore-missing install_asm.sha256
	chmod +x asm/install_asm

validate_cluster:
	mkdir "validate_asm"
	./asm/install_asm \
      --project_id $(PROJECT_ID)\
      --cluster_name ${CLUSTER_NAME} \
      --cluster_location ${CLUSTER_LOCATION} \
      --mode install \
      --output_dir ./validate_asm \
      --only_validate

install_asm:
	./asm/install_asm \
      --project_id $(PROJECT_ID) \
      --cluster_name ${CLUSTER_NAME} \
      --cluster_location ${CLUSTER_LOCATION} \
      --mode install \
      --enable_all

setup_asm: download_asm validate_cluster install_asm

install_tekton:
	kubectl apply -f "https://github.com/tektoncd/pipeline/releases/download/${TEKTON_VERSION}/release.yaml"

install_kf_cli:
ifeq ($(OS_VERSION), darwin)
	gsutil cp gs://kf-releases/${KF_VERSION}/kf-${OS_VERSION} /tmp/kf; \
	chmod a+x /tmp/kf; \
	sudo mv /tmp/kf /usr/local/bin/kf;
endif
ifeq ($(OS_VERSION), linux)
	gsutil cp gs://kf-releases/${KF_VERSION}/kf-${OS_VERSION} /tmp/kf; \
	chmod a+x /tmp/kf; \
	sudo mv /tmp/kf /usr/local/bin/kf;
else
	gsutil cp gs://kf-releases/${KF_VERSION}/kf-windows.exe kf.exe; \
endif
endif

install_kf_server_comp:
	gsutil cp gs://kf-releases/${KF_VERSION}/kf.yaml /tmp/kf.yaml; \
    kubectl apply -f /tmp/kf.yaml

setup_secret:
	kubectl annotate serviceaccount controller ${WI_ANNOTATION} \
    --namespace kf \
    --overwrite; \
    echo "{\"apiVersion\":\"v1\",\"kind\":\"ConfigMap\",\"metadata\":{\"name\":\"config-secrets\", \"namespace\":\"kf\"},\"data\":{\"wi.googleServiceAccount\":\"${CLUSTER_NAME}-sa@${CLUSTER_PROJECT_ID}.iam.gserviceaccount.com\"}}" | kubectl apply -f -

setup_kf_default:
	kubectl patch configmaps config-defaults \
	-n=kf \
	-p="{\"data\":{\"spaceContainerRegistry\":\"${CONTAINER_REGISTRY}\",\"spaceClusterDomains\":\"- domain: ${DOMAIN}\"}}"

validate_installation:
	kf doctor --retries 10

setup_kf: install_kf_cli install_kf_server_comp setup_secret setup_kf_default validate_installation

all: auth setup_asm install_tekton setup_kf
