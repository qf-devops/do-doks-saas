############################
# DIGITALOCEAN INFRA LAYER #
############################

data "digitalocean_kubernetes_versions" "stable" {
  version_prefix = "latest"
}

resource "digitalocean_vpc" "this" {
  name     = "${var.project_name}-vpc"
  region   = var.region
  ip_range = var.vpc_cidr
}

resource "digitalocean_kubernetes_cluster" "this" {
  name          = var.cluster_name
  region        = var.region
  version       = data.digitalocean_kubernetes_versions.stable.latest_version
  vpc_uuid      = digitalocean_vpc.this.id
  surge_upgrade = true
  tags          = var.tags

  maintenance_policy {
    day        = "saturday"
    start_time = "04:00"
  }

  node_pool {
    name       = "default-pool"
    size       = var.node_size
    auto_scale = true
    min_nodes  = var.min_nodes
    max_nodes  = var.max_nodes
  }
}

############################
# KUBERNETES/HELM PROVIDER #
############################

# Extract kubeconfig from the created cluster to configure providers
data "digitalocean_kubernetes_cluster" "conn" {
  name = digitalocean_kubernetes_cluster.this.name
}

locals {
  kubeconfig = digitalocean_kubernetes_cluster.this.kube_configs[0].raw_config
}

provider "kubernetes" {
  host                   = yamldecode(local.kubeconfig)["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(yamldecode(local.kubeconfig)["clusters"][0]["cluster"]["certificate-authority-data"])
  token                  = yamldecode(local.kubeconfig)["users"][0]["user"]["token"]
}

provider "helm" {
  kubernetes {
    host                   = yamldecode(local.kubeconfig)["clusters"][0]["cluster"]["server"]
    cluster_ca_certificate = base64decode(yamldecode(local.kubeconfig)["clusters"][0]["cluster"]["certificate-authority-data"])
    token                  = yamldecode(local.kubeconfig)["users"][0]["user"]["token"]
  }
}

############################
# CLUSTER ADD-ONS          #
############################

# Metrics Server (for HPA). DOKS often includes it, but we ensure presence via Helm.
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  set {
    name  = "args"
    value = ["--kubelet-insecure-tls"]
  }
}

############################
# NAMESPACE & APP STACK    #
############################

resource "kubernetes_namespace" "app" {
  metadata {
    name = "hitapp"
    labels = {
      "app.kubernetes.io/name" = "hitapp"
      "app.kubernetes.io/part-of" = "saas-demo"
    }
  }
}

# Redis for counting hits (backend store)
resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "redis"
    }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "redis" } }
    template {
      metadata { labels = { app = "redis" } }
      spec {
        container {
          name  = "redis"
          image = "redis:7-alpine"
          port { container_port = 6379 }
          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "500m", memory = "256Mi" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = { app = "redis" }
  }
  spec {
    selector = { app = "redis" }
    port {
      name        = "redis"
      port        = 6379
      target_port = 6379
    }
    type = "ClusterIP"
  }
}

# Web app Deployment
resource "kubernetes_deployment" "hitapp" {
  metadata {
    name      = "hitapp"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "hitapp"
    }
  }
  spec {
    replicas = var.app_replicas
    selector { match_labels = { app = "hitapp" } }
    template {
      metadata { labels = { app = "hitapp" } }
      spec {
        container {
          name  = "hitapp"
          image = var.app_image
          port { container_port = 5000 }
          env {
            name  = "REDIS_HOST"
            value = kubernetes_service.redis.metadata[0].name
          }
          env {
            name  = "REDIS_PORT"
            value = "6379"
          }
          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "500m", memory = "256Mi" }
          }
          readiness_probe {
            http_get { path = "/healthz" port = 5000 }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 2
          }
          liveness_probe {
            http_get { path = "/healthz" port = 5000 }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 2
          }
        }
      }
    }
  }
}

# Service of type LoadBalancer -> provisions a DigitalOcean Load Balancer
resource "kubernetes_service" "hitapp_lb" {
  metadata {
    name      = "hitapp"
    namespace = kubernetes_namespace.app.metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol" = "true"
    }
    labels = {
      app = "hitapp"
    }
  }
  spec {
    selector = { app = "hitapp" }
    port {
      name        = "http"
      port        = 80
      target_port = 5000
    }
    type = "LoadBalancer"
  }
}

# Horizontal Pod Autoscaler (v2) on CPU utilization
resource "kubernetes_horizontal_pod_autoscaler_v2" "hitapp_hpa" {
  metadata {
    name      = "hitapp-hpa"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  spec {
    min_replicas = 2
    max_replicas = 10
    scale_target_ref {
      kind = "Deployment"
      name = kubernetes_deployment.hitapp.metadata[0].name
      api_version = "apps/v1"
    }
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type               = "Utilization"
          average_utilization = var.app_cpu_target
        }
      }
    }
  }

  depends_on = [helm_release.metrics_server]
}
