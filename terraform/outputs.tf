output "cluster_name" {
  value = digitalocean_kubernetes_cluster.this.name
}

output "kubeconfig" {
  value     = digitalocean_kubernetes_cluster.this.kube_configs[0].raw_config
  sensitive = true
}

output "load_balancer_hostname" {
  description = "Public hostname of the app LoadBalancer (once created)"
  value       = kubernetes_service.hitapp_lb.status[0].load_balancer[0].ingress[0].hostname
}
