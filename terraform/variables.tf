variable "do_token" {
  description = "DigitalOcean Personal Access Token"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Prefix for resources"
  type        = string
  default     = "saas-demo"
}

variable "region" {
  description = "DigitalOcean region (e.g., fra1, nyc3)"
  type        = string
  default     = "fra1"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
  default     = "10.30.0.0/16"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "saas-doks"
}

variable "node_size" {
  description = "Droplet size for worker nodes"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "min_nodes" {
  description = "Minimum nodes in autoscaling pool"
  type        = number
  default     = 2
}

variable "max_nodes" {
  description = "Maximum nodes in autoscaling pool"
  type        = number
  default     = 4
}

variable "app_image" {
  description = "Container image for the web app"
  type        = string
  default     = "ghcr.io/example/saas-hitapp:latest" # replace after building/pushing
}

variable "app_replicas" {
  description = "Initial Deployment replicas"
  type        = number
  default     = 2
}

variable "app_cpu_target" {
  description = "HPA target average CPU utilization percentage"
  type        = number
  default     = 60
}

variable "tags" {
  description = "Common resource tags"
  type        = list(string)
  default     = ["terraform", "saas", "demo"]
}
