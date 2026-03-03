---
title: Cómo construir una plataforma base en AWS con Terraform + GitHub Actions + OIDC (lista para desplegar microservicios)
published: false
description: Este proyecto construye el cascarón de infraestructura en AWS - VPC, EKS, ECR, backend remoto y CI/CD con OIDC, separando test/prod y entregando outputs reutilizables para despliegues de aplicaciones
tags: aws, terraform, devops, kubernetes
cover_image: https://raw.githubusercontent.com/TU_USUARIO/infra-devops-aws/main/generated-diagrams/cover_aws_devto.png
canonical_url: null
series: AWS Infrastructure Platform
---

# 🚀 Cómo construir una plataforma base en AWS con Terraform + GitHub Actions + OIDC

## 📋 Tabla de Contenidos

- [El Problema](#-el-problema)
- [La Solución](#-la-solución)
- [Arquitectura General](#-arquitectura-general)
- [Componentes Principales](#-componentes-principales)
- [Seguridad: OIDC en lugar de Access Keys](#-seguridad-oidc-en-lugar-de-access-keys)
- [Setup del Proyecto](#-setup-del-proyecto)
- [Pipeline CI/CD](#-pipeline-cicd)
- [Outputs y Reutilización](#-outputs-y-reutilización)
- [Lecciones Aprendidas](#-lecciones-aprendidas)
- [Conclusión](#-conclusión)

---

## 🔥 El Problema

La mayoría de proyectos de microservicios en AWS enfrentan estos desafíos:

❌ **Infraestructura manual** - Crear VPCs, subnets, EKS clusters manualmente es propenso a errores  
❌ **Credenciales estáticas** - Access Keys almacenadas en GitHub Secrets (riesgo de seguridad)  
❌ **Sin separación de ambientes** - Test y producción comparten recursos  
❌ **Estado de Terraform local** - Conflictos cuando trabajan múltiples personas  
❌ **Despliegues manuales** - Cada cambio requiere intervención humana  
❌ **Configuración repetitiva** - Cada microservicio debe configurar su propia infraestructura

**¿El resultado?** Infraestructura frágil, insegura, difícil de mantener y escalar.

---

## ✅ La Solución

Este proyecto construye una **plataforma base reutilizable** que resuelve todos estos problemas:

✅ **Infraestructura como Código** - Todo definido en Terraform, versionado en Git  
✅ **Autenticación OIDC** - Cero credenciales estáticas en GitHub  
✅ **Separación completa** de ambientes TEST y PROD  
✅ **Estado remoto** en S3 con bloqueo en DynamoDB  
✅ **CI/CD automatizado** con aprobaciones manuales para producción  
✅ **Outputs reutilizables** - Otros repos consumen ECR URL, EKS endpoint, etc.  
✅ **Arquitectura de red segura** - Subnets públicas/privadas, NAT Gateway  
✅ **EKS v1.33** con managed node groups y autoscaling

**Stack Tecnológico:**
- AWS (EKS, ECR, VPC, S3, DynamoDB, IAM)
- Terraform 1.6.6
- GitHub Actions
- Kubernetes 1.33
- Docker

---

## 🏗️ Arquitectura General

![Arquitectura AWS](https://raw.githubusercontent.com/TU_USUARIO/infra-devops-aws/main/assets/diagrams/AWS%20Diagrams/aws_infrastructure_diagram.png)

### Componentes por Ambiente

**TEST Environment:**
- VPC: `10.110.0.0/16`
- EKS Cluster: `eksdevops1720test`
- ECR Repository: `ecrdevops1720test`
- Subnets públicas: `10.110.10.0/24`, `10.110.11.0/24`
- Subnets privadas: `10.110.20.0/24`, `10.110.21.0/24`

**PROD Environment:**
- VPC: `10.111.0.0/16`
- EKS Cluster: `eksdevops1720prod`
- ECR Repository: `ecrdevops1720prod`
- Subnets públicas: `10.111.10.0/24`, `10.111.11.0/24`
- Subnets privadas: `10.111.20.0/24`, `10.111.21.0/24`

**Infraestructura Compartida:**
- S3 Backend: `tfstate-devops-henry-1720`
- DynamoDB Lock: `tfstate-locks-devops`
- IAM OIDC Role: `gh-oidc-terraform-infra-devops-aws`

---

## 🔐 Seguridad: OIDC en lugar de Access Keys

### El Problema con Access Keys

**Método tradicional (❌ INSEGURO):**

```yaml
# GitHub Secrets
AWS_ACCESS_KEY_ID: AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

**Problemas:**
- Credenciales de larga duración
- Riesgo de filtración
- Rotación manual
- Difícil auditoría

### La Solución: OIDC

**Método moderno con OIDC (✅ SEGURO):**

```
GitHub Actions → Token OIDC → AWS IAM Role → Credenciales Temporales (STS)
```

**Beneficios:**
- ✅ Cero credenciales estáticas
- ✅ Tokens de corta duración (15-60 minutos)
- ✅ Scope limitado al repositorio específico
- ✅ Auditoría completa en CloudTrail
- ✅ Rotación automática

### Implementación del OIDC

El script `bootstrap_oidc.sh` automatiza la creación:

```bash
#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="${1:?Usage: $0 <account_id> <repo_full_name> <role_name> <region>}"
REPO_FULL="${2}"
ROLE_NAME="${3:-gh-oidc-terraform-infra-devops-aws}"
REGION="${4:-us-east-1}"

OIDC_URL="token.actions.githubusercontent.com"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_URL}"

# 1) Crear OIDC provider si no existe
echo "==> Ensuring GitHub OIDC provider exists..."
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}" >/dev/null 2>&1; then
  THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"
  
  aws iam create-open-id-connect-provider \
    --url "https://${OIDC_URL}" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "${THUMBPRINT}"
  
  echo "OIDC provider created: ${OIDC_ARN}"
fi

# 2) Crear trust policy (solo este repo puede asumir el rol)
TMP_TRUST="$(mktemp)"
cat > "${TMP_TRUST}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Federated": "${OIDC_ARN}" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_URL}:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "${OIDC_URL}:sub": [
            "repo:${REPO_FULL}:ref:refs/heads/main",
            "repo:${REPO_FULL}:ref:refs/heads/dev/*",
            "repo:${REPO_FULL}:pull_request"
          ]
        }
      }
    }
  ]
}
EOF

# 3) Crear/actualizar rol
if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
  aws iam update-assume-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-document "file://${TMP_TRUST}"
else
  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "file://${TMP_TRUST}"
fi

rm -f "${TMP_TRUST}"

echo "DONE. Set this GitHub secret:"
echo "AWS_ROLE_TO_ASSUME = arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
```

**Ejecución:**

```bash
./scripts/bootstrap_oidc.sh 035462351040 hsniama/infra-devops-aws gh-oidc-terraform-infra-devops-aws us-east-1
```

### Trust Policy Explicada

```json
{
  "StringLike": {
    "token.actions.githubusercontent.com:sub": [
      "repo:hsniama/infra-devops-aws:ref:refs/heads/main",
      "repo:hsniama/infra-devops-aws:ref:refs/heads/dev/*"
    ]
  }
}
```

**Esto significa:**
- ✅ Solo el repo `hsniama/infra-devops-aws` puede asumir el rol
- ✅ Solo desde ramas `main` o `dev/*`
- ❌ Ningún otro repo o usuario puede usarlo
- ❌ Ninguna otra rama puede asumir el rol

---

## 🛠️ Setup del Proyecto

### Estructura del Proyecto

```
infra-devops-aws/
├── .github/workflows/
│   ├── terraform.yml              # Pipeline principal
│   ├── destroy-infra-test.yml     # Destruir TEST
│   └── destroy-infra-prod.yml     # Destruir PROD
├── terraform/
│   ├── modules/
│   │   ├── vpc/                   # Módulo VPC reutilizable
│   │   ├── eks/                   # Módulo EKS reutilizable
│   │   └── ecr/                   # Módulo ECR reutilizable
│   ├── main.tf                    # Orquestación de módulos
│   ├── variables.tf               # Variables de entrada
│   ├── outputs.tf                 # Outputs para otros repos
│   └── backend.tf                 # Configuración backend remoto
├── environments/
│   ├── test.tfvars                # Variables TEST
│   └── prod.tfvars                # Variables PROD
├── backends/
│   ├── test.hcl                   # Backend config TEST
│   └── prod.hcl                   # Backend config PROD
└── scripts/
    ├── bootstrap_backend.sh       # Crear S3 + DynamoDB
    ├── bootstrap_oidc.sh          # Crear OIDC + Role
    ├── destroy_backend.sh         # Limpiar backend
    └── destroy_oidc.sh            # Limpiar OIDC
```

### Paso 1: Configurar AWS CLI

```bash
aws configure
# AWS Access Key ID: <tu key>
# AWS Secret Access Key: <tu secret>
# Default region name: us-east-1
# Default output format: json

# Verificar identidad
aws sts get-caller-identity
```

### Paso 2: Crear Backend Remoto (S3 + DynamoDB)

```bash
chmod +x scripts/bootstrap_backend.sh
./scripts/bootstrap_backend.sh us-east-1 tfstate-devops-henry-1720 tfstate-locks-devops
```

**Esto crea:**
- S3 bucket: `tfstate-devops-henry-1720`
- DynamoDB table: `tfstate-locks-devops`
- Keys separadas: `test/infra.tfstate` y `prod/infra.tfstate`

### Paso 3: Crear OIDC Provider + Role

```bash
chmod +x scripts/bootstrap_oidc.sh
./scripts/bootstrap_oidc.sh 035462351040 hsniama/infra-devops-aws gh-oidc-terraform-infra-devops-aws us-east-1
```

**Guarda el ARN generado:**

```
AWS_ROLE_TO_ASSUME = arn:aws:iam::035462351040:role/gh-oidc-terraform-infra-devops-aws
```

### Paso 4: Configurar GitHub

**Crear Environments:**
- `test` - Sin aprobación manual
- `prod` - Con aprobación manual requerida

**Crear Secrets:**
- `AWS_ROLE_TO_ASSUME` → ARN del rol OIDC

**Crear Variables:**
- `AWS_REGION` → `us-east-1`

### Paso 5: Configurar Variables de Terraform

**`environments/test.tfvars`:**

```hcl
aws_region  = "us-east-1"
environment = "test"

vpc_cidr             = "10.110.0.0/16"
public_subnet_cidrs  = ["10.110.10.0/24", "10.110.11.0/24"]
private_subnet_cidrs = ["10.110.20.0/24", "10.110.21.0/24"]

eks_name        = "eksdevops1720test"
cluster_version = "1.33"
ecr_repo_name   = "ecrdevops1720test"

eks_access_entries = {
  terraform_user = {
    principal_arn = "arn:aws:iam::035462351040:user/terraformUser"
    policies = {
      admin = {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope_type = "cluster"
      }
    }
  }
  github_oidc = {
    principal_arn = "arn:aws:iam::035462351040:role/gh-oidc-terraform-infra-devops-aws"
    policies = {
      admin = {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope_type = "cluster"
      }
    }
  }
}

node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 5
node_ami_type       = "BOTTLEROCKET_x86_64"
```

**`environments/prod.tfvars`:**

Similar pero con:
- `vpc_cidr = "10.111.0.0/16"`
- `eks_name = "eksdevops1720prod"`
- `ecr_repo_name = "ecrdevops1720prod"`

---

*Continúa en la Parte 2...*

---

**Repositorio:** [github.com/hsniama/infra-devops-aws](https://github.com/hsniama/infra-devops-aws)

**Tags:** #AWS #Terraform #DevOps #Kubernetes #EKS #OIDC #GitHubActions #InfrastructureAsCode
