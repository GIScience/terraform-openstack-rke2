output "floating_ip" {
  value       = module.server.floating_ip
  description = "Nodes floating IP"
}

output "floating_ip_associate" {
  value       = module.server.floating_ip_associate
  description = "Nodes floating IP association"
}

output "internal_ip" {
  value       = module.server.internal_ip
  description = "Nodes internal IP"
}

output "router_ip" {
  value       = local.router_ip
  description = "Router external_ip"
}

output "node_config" {
  value       = local.node_config
  sensitive   = true
  description = "Nodes config"
}

output "subnet_id" {
  value       = local.nodes_subnet_id
  description = "Nodes Subnet ID"
}

output "kubernetes_config" {
  value = var.output_kubernetes_config ? {
    host                   = module.host[0].stdout
    client_certificate     = module.client_certificate[0].stdout
    client_key             = module.client_key[0].stdout
    cluster_ca_certificate = module.cluster_ca_certificate[0].stdout
  } : {}
  sensitive   = true
  description = "Kubernetes config to feed Kubernetes or Helm provider"
}
