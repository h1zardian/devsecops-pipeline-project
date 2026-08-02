.PHONY: help init-state cluster-up cluster-down ansible-bootstrap lint scan dev-up dev-down kind-up kind-down k8s-local-deploy up down destroy status

help:
	@echo "DevSecOps Platform Pipeline Commands:"
	@echo "  make up (or cluster-up)   - Bring up complete AWS infra (VPC, EKS, RDS, OIDC/IRSA) + Day 0 platform bootstrap"
	@echo "  make down (or destroy)    - Tear down runtime AWS infra & Kubernetes cloud resources"
	@echo "  make status               - Display status of cluster pods, IRSA role, and live app endpoint"
	@echo "  make dev-up               - Start local docker-compose development stack"
	@echo "  make dev-down             - Stop local docker-compose development stack"
	@echo "  make kind-up              - Spin up local Kind Kubernetes cluster"
	@echo "  make kind-down            - Destroy local Kind Kubernetes cluster"
	@echo "  make init-state           - Initialize S3 Terraform remote state backend"
	@echo "  make ansible-bootstrap    - Run Day 0 bootstrap and register the ArgoCD GitOps applications"
	@echo "  make lint                 - Run pre-commit linting (gitleaks, tflint, bandit)"
	@echo "  make scan                 - Run local Trivy scan on container image"

# Convenience Aliases
up: cluster-up
down: cluster-down
destroy: cluster-down

init-state:
	./infra/scripts/bootstrap-state.sh

cluster-up:
	@echo "==> [1/4] Provisioning AWS Infrastructure via Terraform..."
	cd infra/terraform && terraform init && terraform apply -var-file=environments/dev.tfvars -auto-approve
	@echo "==> [2/4] Updating local kubeconfig..."
	aws eks update-kubeconfig --name devsecops-eks-cluster-dev --region ap-south-1
	@echo "==> [3/4] Executing Day 0 Ansible Platform Bootstrap..."
	cd infra/ansible && ESO_IRSA_ROLE_ARN="$$(cd ../terraform && terraform output -raw eso_irsa_role_arn)" ansible-playbook -i inventory/localhost.yml playbooks/bootstrap-cluster.yml
	@echo "==> [4/4] Verifying cluster & application health..."
	@$(MAKE) status

cluster-down:
	@echo "==> [1/2] Cleaning up out-of-band Kubernetes cloud resources (ELBs/SGs)..."
	./infra/scripts/cleanup-k8s-cloud-resources.sh || true
	@echo "==> [2/2] Destroying AWS Infrastructure via Terraform..."
	cd infra/terraform && terraform destroy -var-file=environments/dev.tfvars -auto-approve

status:
	@echo "=================== EKS WORKER NODES ==================="
	@kubectl get nodes -o wide || true
	@echo ""
	@echo "=================== ARGOCD APPLICATIONS ==================="
	@kubectl get application -n argocd || true
	@echo ""
	@echo "=================== SECRETSTORE & PODS ==================="
	@kubectl describe clustersecretstore aws-secrets-manager 2>/dev/null | grep -E "Status:|Reason:|Message:" || true
	@kubectl get pods -n django || true
	@echo ""
	@echo "=================== PUBLIC AWS LOAD BALANCERS ==================="
	@kubectl get service -A | awk 'NR == 1 || $$3 == "LoadBalancer"' || true

ansible-bootstrap:
	cd infra/ansible && ESO_IRSA_ROLE_ARN="$$(cd ../terraform && terraform output -raw eso_irsa_role_arn)" ansible-playbook -i inventory/localhost.yml playbooks/bootstrap-cluster.yml

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
