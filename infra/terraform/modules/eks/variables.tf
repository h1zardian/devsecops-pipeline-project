variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "environment" {
  type = string
}

variable "region" {
  description = "AWS region, used by the pre-destroy cleanup provisioner"
  type        = string
}

variable "cluster_endpoint_public_access_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks that can access the EKS public API server endpoint"
  default     = ["0.0.0.0/0"] # Restrict to trusted IPs in production
}
