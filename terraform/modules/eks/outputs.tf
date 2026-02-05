output "eks_name" {
  value = module.eks.cluster_name
}
output "cluster_endpoint" {           // Expone el endpoint del clúster EKS (la URL de la API de Kubernetes).
  value = module.eks.cluster_endpoint // Este valor es necesario para configurar tu kubeconfig y poder ejecutar kubectl contra el clúster.
}
output "oidc_issuer_url" { // Expone la URL del proveedor OIDC asociado al clúster.
  value = module.eks.oidc_provider
}
//Se usa para integrar IAM Roles for Service Accounts (IRSA) en Kubernetes.
// Básicamente, permite que los pods en EKS asuman roles de IAM de manera segura, sin tener que usar credenciales estáticas.