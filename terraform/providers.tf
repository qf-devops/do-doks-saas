terraform {
  required_version = ">= 1.5.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# The Kubernetes and Helm providers are configured *after* cluster creation via data source.
# See providers in main.tf using dynamic kubeconfig from the new DOKS cluster.
