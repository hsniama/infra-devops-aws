# Repo: infra-devops-aws (Terraform + GitHub Actions + AWS + OIDC)

Infraestructura en AWS provisionada con Terraform, separada por ambientes (test / prod), usando GitHub Actions + OIDC (sin credenciales estáticas) y preparada para desplegar aplicaciones sobre EKS en un repositorio futuro (app-devops-aws) o cualquiera.

---

## Arquitectura general

La infraestructura crea:
- VPC dedicada por ambiente
  - Subnets públicas (Load Balancers)
  - Subnets privadas (EKS Nodes)
- EKS (Amazon Kubernetes Service)
  - Managed Node Groups
  - Endpoint público y privado
  - Acceso controlado vía IAM (Access Entries)
- ECR
  - Repositorio por ambiente para imágenes Docker
- Backend remoto de Terraform
  - S3 para state
  - DynamoDB para locking
- CI/CD con GitHub Actions
  - Terraform Plan / Apply
  - Autenticación vía AWS OIDC (sin access keys)