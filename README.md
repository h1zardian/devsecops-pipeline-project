# DevSecOps Well-Architected Platform & Provisioning Pipeline

[![CI Build](https://github.com/h1zardian/devsecops-pipeline-project/actions/workflows/ci-app.yml/badge.svg)](https://github.com/h1zardian/devsecops-pipeline-project/actions)
[![SLSA Level 3](https://slsa.dev/images/gh-badge-level3.svg)](https://slsa.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-grade, well-architected DevSecOps platform demonstrating end-to-end supply-chain security (SLSA Level 3), automated Infrastructure-as-Code (IaC) security scanning, Day 0 Ansible platform bootstrapping, Day 1+ GitOps continuous delivery via ArgoCD, Kyverno runtime admission controls, zero-trust secrets management with External Secrets Operator (ESO), and Prometheus/Grafana observability.

---

## Architecture Overview

```mermaid
graph TD
    subgraph "GitHub Actions — CI/CD Orchestration"
        A1["ci-app.yml: Scan → Build → Sign → Attest → Push GHCR"]
        A2["ci-terraform.yml: Lint → Checkov → Plan → Approve → Apply"]
        A3["ci-k8s-manifests.yml: kubeconform + kyverno validate"]
    end

    subgraph "Terraform — Cloud Infrastructure"
        T1["VPC + Subnets + NAT"]
        T2["EKS Cluster (v20+, K8s 1.31) + Hardened Nodes"]
        T3["RDS PostgreSQL (Encrypted)"]
        T4["GitHub OIDC Provider + IAM Roles"]
        T5["S3 + DynamoDB (TF state backend)"]
    end

    subgraph "Ansible — Day 0 Bootstrap (run once)"
        B1["ArgoCD"]
        B2["Kyverno"]
        B3["External Secrets Operator"]
        B4["kube-prometheus-stack"]
        B5["Ingress NGINX + cert-manager"]
    end

    subgraph "ArgoCD — Day 1+ GitOps (continuous)"
        G1["Django App (Helm)"]
        G2["App of Apps Self-Management"]
        G3["Drift Detection & Auto-Healing"]
    end

    A2 --> T1 --> T2
    T2 --> B1
    B1 --> G1

    style A1 fill:#1a1a2e,stroke:#e94560,color:#fff
    style A2 fill:#1a1a2e,stroke:#e94560,color:#fff
    style A3 fill:#1a1a2e,stroke:#e94560,color:#fff
    style T1 fill:#0f3460,stroke:#53d8fb,color:#fff
    style T2 fill:#0f3460,stroke:#53d8fb,color:#fff
    style T3 fill:#0f3460,stroke:#53d8fb,color:#fff
    style T4 fill:#0f3460,stroke:#53d8fb,color:#fff
    style T5 fill:#0f3460,stroke:#53d8fb,color:#fff
    style B1 fill:#533483,stroke:#e94560,color:#fff
    style B2 fill:#533483,stroke:#e94560,color:#fff
    style B3 fill:#533483,stroke:#e94560,color:#fff
    style B4 fill:#533483,stroke:#e94560,color:#fff
    style B5 fill:#533483,stroke:#e94560,color:#fff
    style G1 fill:#1a5c2e,stroke:#53d8fb,color:#fff
    style G2 fill:#1a5c2e,stroke:#53d8fb,color:#fff
    style G3 fill:#1a5c2e,stroke:#53d8fb,color:#fff
```

---

## Key Security Features

* **Supply Chain Security (SLSA Level 3)**:
  * Secret scanning (`gitleaks`), Python SAST (`bandit`), container vulnerability scanning (`trivy`).
  * Software Bill of Materials (`syft` CycloneDX) attached to image manifests.
  * Keyless image and SBOM signatures (`cosign`) verified against GitHub Actions OIDC identity.
  * Signed build attestations via `slsa-github-generator`.
* **Zero-Trust Infrastructure & Secret Management**:
  * AWS authentication via GitHub Actions OIDC Federation (zero static AWS keys).
  * AWS Secrets Manager integrated with Kubernetes via External Secrets Operator (ESO).
  * Enforced IMDSv2 (`http_tokens = required`), EBS volume encryption, and EKS secrets KMS envelope encryption.
* **GitOps & Admission Control**:
  * Continuous delivery powered by ArgoCD with automated drift detection and self-healing.
  * Kyverno policy enforcement at admission: disallows `:latest` tags, enforces non-root containers, mandates resource limits, and validates Cosign keyless signatures.
  * Safe database migrations using Helm `pre-install,pre-upgrade` hook `Job`.
* **Observability & SRE Controls**:
  * Application metric exposition via `django-prometheus` at `/metrics`.
  * Prometheus `ServiceMonitor` and `PrometheusRule` alerting on error rates (>5%) and pod crashloops.
  * Pre-configured Grafana dashboard for app latencies, request rates, and resource utilization.

---

## Quick Start & Deployment Guide

### Prerequisites
* AWS CLI configured, Terraform >= 1.5, Ansible >= 2.15, Helm >= 3.12, kubectl, Docker.

### 1. Initialize State Backend
```bash
make init-state
```

### 2. Provision Infrastructure
```bash
make cluster-up
```

### 3. Bootstrap Day 0 Platform Controllers
```bash
aws eks update-kubeconfig --name devsecops-eks-cluster --region ap-south-1
make ansible-bootstrap
```

### 4. Continuous GitOps Delivery
ArgoCD automatically detects changes in `k8s/apps/django-app/values.yaml` and deploys the application.

---

## Cost Optimization
* **On-Demand AWS Spend**: Use `make cluster-down` to destroy infrastructure when not demonstrating or testing (~$150/month active vs <$10/month on-demand).
* **Zero-Cost Local Iteration**: Run `make dev-up` to launch local Docker Compose stack for offline development.
