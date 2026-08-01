.PHONY: help init-state cluster-up cluster-down ansible-bootstrap lint scan dev-up dev-down kind-up kind-down k8s-local-deploy

help:
	@echo "DevSecOps Platform Provisioning Pipeline Commands:"
	@echo "  make dev-up           - Start local docker-compose development stack"
	@echo "  make dev-down         - Stop local docker-compose development stack"
	@echo "  make kind-up          - Spin up local Kind Kubernetes cluster"
	@echo "  make kind-down        - Destroy local Kind Kubernetes cluster"
	@echo "  make k8s-local-deploy - Deploy Django Helm chart to local cluster (using local K8s secret)"
	@echo "  make init-state       - Run bootstrap-state.sh for AWS S3 TF backend"
	@echo "  make cluster-up       - Apply AWS Terraform infrastructure (VPC, EKS, RDS, OIDC)"
	@echo "  make cluster-down     - Destroy AWS Terraform infrastructure"
	@echo "  make ansible-bootstrap- Run Day 0 Ansible cluster bootstrap (ArgoCD, Kyverno, ESO, Prometheus)"
	@echo "  make lint             - Run pre-commit linting (gitleaks, tflint, bandit)"
	@echo "  make scan             - Run local Trivy scan on container image"

init-state:
	./infra/scripts/bootstrap-state.sh

cluster-up:
	cd infra/terraform && terraform init && terraform apply -var-file=environments/dev.tfvars -auto-approve

cluster-down:
	cd infra/terraform && terraform destroy -var-file=environments/dev.tfvars -auto-approve

ansible-bootstrap:
	cd infra/ansible && ansible-playbook -i inventory/localhost.yml playbooks/bootstrap-cluster.yml

lint:
	pre-commit run --all-files

scan:
	trivy image devsecops-django-app:latest

dev-up:
	docker compose up -d --build

dev-down:
	docker compose down

kind-up:
	@echo "==> Creating local Kind Kubernetes cluster..."
	kind create cluster --name devsecops-local || true

kind-down:
	@echo "==> Deleting local Kind Kubernetes cluster..."
	kind delete cluster --name devsecops-local

k8s-local-deploy:
	@echo "==> Deploying Django Helm chart to local cluster with local secret..."
	helm upgrade --install django-app k8s/apps/django-app --set externalSecrets.enabled=false --set sqlHost=postgres-service
