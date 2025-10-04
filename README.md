# SaaS Demo on DigitalOcean Kubernetes (DOKS)

This repository contains Terraform code to provision a DOKS cluster and deploy a scalable, autoscaled web app
(Flask + Redis) fronted by a DigitalOcean Load Balancer (via Kubernetes Service type `LoadBalancer`).

## Features

- DigitalOcean VPC + DOKS cluster with autoscaling node pool
- Metrics Server (via Helm) to support HPA
- Redis (ClusterIP) for shared hit counter
- Web app Deployment with readiness/liveness probes
- Service type LoadBalancer for public exposure
- HPA v2 scaling based on CPU utilization
- Outputs with kubeconfig and LB hostname

## Prerequisites

- Terraform >= 1.5
- Docker & a container registry (Docker Hub or GHCR)
- kubectl & helm (optional locally)
- DigitalOcean Personal Access Token (PAT)

## Quick Start

1. **Build & push the app image**

```bash
cd app
docker build -t ghcr.io/<your-user>/saas-hitapp:1.0.0 .
# docker login ghcr.io
docker push ghcr.io/<your-user>/saas-hitapp:1.0.0
```

2. **Provision infra + deploy app**

```bash
cd terraform
terraform init
terraform plan -var="do_token=$DIGITALOCEAN_TOKEN" -var-file="terraform.tfvars.example"
terraform apply -var="do_token=$DIGITALOCEAN_TOKEN" -var-file="terraform.tfvars.example" -auto-approve
```

3. **Retrieve kubeconfig and test**

```bash
terraform output -raw kubeconfig > kubeconfig_doks
export KUBECONFIG=$PWD/kubeconfig_doks
kubectl get nodes -o wide
kubectl get svc -n hitapp
```

4. **Access the app**

Wait for the Service external hostname to appear:

```bash
terraform output load_balancer_hostname
# or:
kubectl get svc hitapp -n hitapp -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Open `http://<hostname>/` in your browser.

## Autoscaling Test

Run a basic CPU load test (example with `hey`):

```bash
hey -z 60s -c 50 http://<hostname>/
kubectl get hpa -n hitapp -w
```

## Cost & Performance Notes (Model)

- Choose the smallest node size that meets your SLOs; start with `s-2vcpu-4gb` and scale out with HPA.
- Use autoscaling node pools to match capacity to demand.
- Use `requests/limits` to prevent noisy-neighbor and enable HPA to make informed decisions.
- For exact pricing, refer to DigitalOcean's pricing page and calculator.

## Cleanup

```bash
cd terraform
terraform destroy -var="do_token=$DIGITALOCEAN_TOKEN" -var-file="terraform.tfvars.example" -auto-approve
```
