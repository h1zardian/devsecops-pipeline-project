# DevSecOps Pipeline Resumption Guide

This guide details the exact state of the project, native Terraform IRSA role management, automated pre-destroy cloud resource cleanup, and simplified `make` commands to bring the platform up or down with a single command.

---

## 1. Executive Summary & Achieved Progress

- **Repository**: `h1zardian/devsecops-pipeline-project`
- **AWS Target Region**: `ap-south-1` (Asia Pacific - Mumbai)
- **AWS Account ID**: `072329308666`
- **Remote State Backend**: S3 Bucket `devsecops-tf-state-backend-072329308666` (Native S3 locking via `use_lockfile = true`, no DynamoDB required).

### Fully Verified & Streamlined Features:
1. **Native Terraform IRSA Management**:
   - `devsecops-eso-irsa-role-dev` is now managed **natively by Terraform** in `infra/terraform/modules/oidc/main.tf`. No manual AWS CLI commands or external scripts are needed when creating or destroying infrastructure.
2. **Automated K8s Cloud Resource Teardown**:
   - Pre-destroy script `infra/scripts/cleanup-k8s-cloud-resources.sh` safely revokes and deletes out-of-band Classic ELBs, ELBv2s, and Security Groups created by Kubernetes Ingress before `terraform destroy` runs.
3. **Single-Command Pipeline Workflows (`make up` / `make down`)**:
   - Everything can be brought up with `make up` and brought down cleanly to 0 cost with `make down`.

---

## 2. Simplified Pipeline Commands

### Bring Up Complete Stack (`make up`)
Runs `terraform apply` (VPC, EKS 1.34, RDS PostgreSQL 15, OIDC IAM, ESO IRSA role), updates kubeconfig, runs Day 0 Ansible platform bootstrap, and prints live cluster status:

```bash
make up
```

### Check Live Health & Application Status (`make status`)
Displays status of EKS worker nodes, ArgoCD applications, SecretStore validation, pods, and live Ingress URL:

```bash
make status
```

### Cleanly Tear Down All AWS Infrastructure (`make down`)
Safely cleans up out-of-band Kubernetes ELBs/Security Groups and executes `terraform destroy` with zero manual intervention:

```bash
make down
```

---

## 3. Recommended Prompt for AI Agent Resumption

Copy and paste the following prompt when initiating future agent sessions:

```text
Resume deployment of h1zardian/devsecops-pipeline-project in AWS region ap-south-1 using RESUMPTION_GUIDE.md. Run 'make up' to provision infra and bootstrap cluster, and 'make status' to verify live endpoints.
```
