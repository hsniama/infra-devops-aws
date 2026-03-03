# 🚀 Plataforma Base AWS - Parte 2: Pipeline CI/CD y Outputs

*Continuación de la Parte 1*

---

## 🔄 Pipeline CI/CD

### Workflow: terraform.yml

Este pipeline gestiona despliegues automáticos diferenciando entre TEST y PROD:

![CI/CD Pipeline](https://raw.githubusercontent.com/TU_USUARIO/infra-devops-aws/main/assets/diagrams/AWS%20Diagrams/cicd_pipeline.png)

**Triggers:**

```yaml
on:
  pull_request:
    branches: ["main"]     # PR → plan prod (solo revisión)
  push:
    branches:
      - "main"             # merge → plan + apply prod
      - "dev/**"           # push → plan + apply test
  workflow_dispatch:       # manual
```

**Flujo para TEST:**
1. Push a `dev/**` branches
2. Ejecuta `terraform plan` + `apply` automáticamente
3. Sin aprobación manual
4. Despliega en ambiente TEST

**Flujo para PROD:**
1. Pull Request a `main` → Solo ejecuta `terraform plan` (revisión)
2. Merge a `main` → Ejecuta `plan` + `apply`
3. **Requiere aprobación manual** (GitHub Environment)
4. Despliega en ambiente PROD

### Autenticación OIDC en el Workflow

```yaml
jobs:
  plan:
    runs-on: ubuntu-latest
    environment: ${{ github.ref_name == 'main' && 'prod' || 'test' }}
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.6
      
      # OIDC Authentication - Sin credenciales estáticas
      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
          aws-region: ${{ vars.AWS_REGION }}
      
      - name: Terraform init
        run: terraform init -backend-config=../backends/${{ steps.env.outputs.env }}.hcl
      
      - name: Terraform plan
        run: terraform plan -var-file=../environments/${{ steps.env.outputs.env }}.tfvars -out=tfplan
      
      - name: Upload plan artifact
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-${{ steps.env.outputs.env }}
          path: terraform/tfplan
```

**¿Qué pasa internamente?**

```
1. GitHub Actions inicia workflow
   ↓
2. GitHub genera Token OIDC
   └─ Contiene: repo, rama, commit
   └─ Firmado por GitHub
   └─ Válido: 1 hora
   ↓
3. GitHub envía token a AWS STS
   └─ AssumeRoleWithWebIdentity
   ↓
4. AWS OIDC Provider valida token
   └─ ¿Issuer correcto? ✅
   └─ ¿Repo correcto? ✅
   └─ ¿Rama permitida? ✅
   ↓
5. AWS STS genera credenciales temporales
   └─ AWS_ACCESS_KEY_ID (temporal)
   └─ AWS_SECRET_ACCESS_KEY (temporal)
   └─ AWS_SESSION_TOKEN (temporal)
   └─ Válidas: 1 hora
   ↓
6. Terraform usa credenciales temporales
   └─ terraform init/plan/apply
   ↓
7. Credenciales expiran automáticamente
```

---

## 📊 Módulos Terraform

### Módulo VPC

```hcl
# terraform/modules/vpc/main.tf
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "vpc-${var.name_prefix}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
}

# Subnets públicas (para Load Balancers)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.azs.names[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name                                        = "subnet-public-${var.name_prefix}-${count.index}"
    "kubernetes.io/role/elb"                    = "1"      # ← Para ALB/NLB públicos
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# NAT Gateway para subnets privadas
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.igw]
}

# Subnets privadas (para nodos EKS)
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.azs.names[count.index]
  
  tags = {
    Name                                        = "subnet-private-${var.name_prefix}-${count.index}"
    "kubernetes.io/role/internal-elb"           = "1"      # ← Para NLB internos
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Route table privada → NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}
```

**¿Por qué estas etiquetas?**

```
"kubernetes.io/role/elb" = "1"
    → Le dice a Kubernetes: "Crea Load Balancers PÚBLICOS aquí"
    → Se pone en subnets PÚBLICAS
    → Para servicios accesibles desde Internet

"kubernetes.io/role/internal-elb" = "1"
    → Le dice a Kubernetes: "Crea Load Balancers INTERNOS aquí"
    → Se pone en subnets PRIVADAS
    → Para servicios solo dentro de la VPC
```

### Módulo EKS

```hcl
# terraform/modules/eks/main.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  
  cluster_name    = var.eks_name
  cluster_version = var.cluster_version
  
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids
  
  # Acceso público para kubectl (desarrollo)
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  
  # Autenticación moderna con Access Entries
  authentication_mode = "API_AND_CONFIG_MAP"
  
  access_entries = {
    for k, v in var.eks_access_entries : k => {
      principal_arn = v.principal_arn
      policy_associations = {
        for name, policy in v.policies : name => {
          policy_arn = policy.policy_arn
          access_scope = {
            type = policy.access_scope_type
          }
        }
      }
    }
  }
  
  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.desired_size
      ami_type       = var.ami_type
    }
  }
}
```

**Características clave:**
- ✅ EKS Access Entries (método moderno, no aws-auth ConfigMap)
- ✅ Managed Node Groups (AWS gestiona actualizaciones)
- ✅ Autoscaling (2-5 nodos según carga)
- ✅ Bottlerocket AMI (OS optimizado para contenedores)

### Módulo ECR

```hcl
# terraform/modules/ecr/main.tf
resource "aws_ecr_repository" "this" {
  name                 = var.repo_name
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = {
    Name        = var.repo_name
    Environment = var.name_prefix
  }
}
```

---

## 📤 Outputs y Reutilización

### Outputs de Terraform

```hcl
# terraform/outputs.tf
output "aws_region" {
  description = "AWS region donde se desplegó la infraestructura"
  value       = var.aws_region
}

output "ecr_repository_name" {
  description = "Nombre del repositorio ECR"
  value       = module.ecr.repository_name
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR para docker push"
  value       = module.ecr.repository_url
}

output "eks_cluster_name" {
  description = "Nombre del cluster EKS"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint del API Server de EKS"
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_issuer" {
  description = "OIDC issuer del cluster EKS (para IRSA)"
  value       = module.eks.oidc_provider
}
```

### Cómo Consumir los Outputs

**En el pipeline de GitHub Actions:**

```yaml
# Después de terraform apply
- name: Get Terraform Outputs
  id: tf_outputs
  run: |
    echo "ecr_url=$(terraform output -raw ecr_repository_url)" >> $GITHUB_OUTPUT
    echo "eks_name=$(terraform output -raw eks_cluster_name)" >> $GITHUB_OUTPUT
    echo "eks_endpoint=$(terraform output -raw eks_cluster_endpoint)" >> $GITHUB_OUTPUT
    echo "region=$(terraform output -raw aws_region)" >> $GITHUB_OUTPUT

# Usar en otro job
- name: Build and Push Docker Image
  run: |
    aws ecr get-login-password --region ${{ steps.tf_outputs.outputs.region }} \
      | docker login --username AWS --password-stdin ${{ steps.tf_outputs.outputs.ecr_url }}
    
    docker build -t mi-app .
    docker tag mi-app:latest ${{ steps.tf_outputs.outputs.ecr_url }}/mi-app:latest
    docker push ${{ steps.tf_outputs.outputs.ecr_url }}/mi-app:latest

- name: Deploy to EKS
  run: |
    aws eks update-kubeconfig \
      --region ${{ steps.tf_outputs.outputs.region }} \
      --name ${{ steps.tf_outputs.outputs.eks_name }}
    
    kubectl apply -f k8s/deployment.yaml
```

**En otro repositorio de microservicio:**

```yaml
# .github/workflows/deploy-microservice.yaml
name: Deploy Microservice

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
          aws-region: us-east-1
      
      # Usar outputs de la infraestructura base
      - name: Build and Push to ECR
        env:
          ECR_URL: 035462351040.dkr.ecr.us-east-1.amazonaws.com
          ECR_REPO: ecrdevops1720test
        run: |
          aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_URL
          docker build -t $ECR_REPO .
          docker tag $ECR_REPO:latest $ECR_URL/$ECR_REPO:latest
          docker push $ECR_URL/$ECR_REPO:latest
      
      - name: Deploy to EKS
        env:
          EKS_CLUSTER: eksdevops1720test
        run: |
          aws eks update-kubeconfig --name $EKS_CLUSTER
          kubectl set image deployment/mi-app mi-app=$ECR_URL/$ECR_REPO:latest
```

---

## 🔌 Conectarse al Cluster

Una vez desplegada la infraestructura:

```bash
# Conectar al cluster TEST
aws eks update-kubeconfig --region us-east-1 --name eksdevops1720test

# Verificar nodos
kubectl get nodes
# NAME                          STATUS   ROLES    AGE   VERSION
# ip-10-110-20-45.ec2.internal  Ready    <none>   1h    v1.33.0
# ip-10-110-21-78.ec2.internal  Ready    <none>   1h    v1.33.0

# Ver pods del sistema
kubectl get pods -n kube-system

# Desplegar aplicación de prueba
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --type=LoadBalancer --port=80

# Ver servicio creado
kubectl get svc nginx
# NAME    TYPE           EXTERNAL-IP                              PORT(S)
# nginx   LoadBalancer   a1b2c3-123456.us-east-1.elb.amazonaws.com   80:31234/TCP
```

---

*Continúa en la Parte 3...*

---

**Repositorio:** [github.com/hsniama/infra-devops-aws](https://github.com/hsniama/infra-devops-aws)
