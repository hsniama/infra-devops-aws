# 🚀 Plataforma Base AWS - Parte 3: Arquitectura de Red y Lecciones Aprendidas

*Continuación de la Parte 2*

---

## 🌐 Arquitectura de Red Detallada

### Flujos de Tráfico

![Flujos de Tráfico](https://raw.githubusercontent.com/TU_USUARIO/infra-devops-aws/main/generated-diagrams/diagram_56548df5.png)

#### Flujo 1: Usuario → Aplicación Pública

```
Usuario (Internet)
    ↓
Internet Gateway
    ↓
Application Load Balancer (subnet pública 10.110.10.0/24)
    ↓
Pod A (subnet privada 10.110.20.45)
Pod B (subnet privada 10.110.20.67)
```

**Detalles:**
- ALB se crea automáticamente cuando despliegas un Service `type: LoadBalancer`
- ALB está físicamente en subnets públicas
- ALB enruta tráfico DIRECTAMENTE a IPs de pods (no a nodos)
- Kubernetes usa la etiqueta `kubernetes.io/role/elb` para saber dónde crear el ALB

#### Flujo 2: Pod → Internet (Descargar imagen ECR)

```
Pod (10.110.20.45)
    ↓
NAT Gateway (subnet pública 10.110.10.5)
    ↓
Internet Gateway
    ↓
ECR (035462351040.dkr.ecr.us-east-1.amazonaws.com)
```

**Detalles:**
- Pods en subnets privadas NO tienen IP pública
- NAT Gateway traduce IP privada → IP pública (Elastic IP)
- Todo el tráfico saliente pasa por NAT
- NAT Gateway está en subnet pública

#### Flujo 3: Pod → Pod (Comunicación Interna)

```
Pod A (10.110.20.45)
    ↓
Internal NLB (subnet privada 10.110.20.100)
    ↓
Pod C (10.110.21.89)
```

**Detalles:**
- Internal NLB se crea con anotación `service.beta.kubernetes.io/aws-load-balancer-internal: "true"`
- NLB interno está en subnets privadas
- Solo accesible desde dentro de la VPC
- Kubernetes usa la etiqueta `kubernetes.io/role/internal-elb`

#### Flujo 4: kubectl (Usuario) → EKS

```
Tu Laptop
    ↓
AWS CLI (terraformUser credentials)
    ↓
AWS STS (valida identidad)
    ↓
EKS Access Entry (verifica permisos)
    ↓
EKS API Server
    ↓
Respuesta
```

**Detalles:**
- kubectl se conecta al endpoint público del API Server
- Autenticación vía IAM (no certificados)
- Access Entry define permisos en el cluster
- Token temporal (15 min), no credenciales estáticas

---

## 🎓 Lecciones Aprendidas

### 1. OIDC es el Futuro

**Antes:**
```yaml
# Credenciales estáticas en GitHub Secrets
AWS_ACCESS_KEY_ID: AKIAXXXXX
AWS_SECRET_ACCESS_KEY: xxxxx
```

**Ahora:**
```yaml
# Solo el ARN del rol
AWS_ROLE_TO_ASSUME: arn:aws:iam::123456:role/gh-oidc-role
```

**Beneficios reales:**
- ✅ Eliminé 100% de credenciales estáticas
- ✅ Auditoría completa en CloudTrail
- ✅ Rotación automática (cada ejecución)
- ✅ Scope limitado por repositorio y rama

### 2. Separación de Ambientes es Crítica

**Problema inicial:**
- Test y prod compartían VPC
- Cambios en test afectaban prod
- Difícil rollback

**Solución:**
- VPCs completamente separadas
- Estados de Terraform separados
- Pipelines independientes

**Resultado:**
- ✅ Puedo destruir TEST sin afectar PROD
- ✅ Cambios de red no impactan entre ambientes
- ✅ Costos separados por ambiente

### 3. Etiquetas de Kubernetes en Subnets

**Error común:**
```hcl
# Sin etiquetas
resource "aws_subnet" "public" {
  tags = {
    Name = "public-subnet"
  }
}
```

**Resultado:**
```bash
kubectl expose deployment app --type=LoadBalancer
# Service queda en "Pending" indefinidamente
# Error: No suitable subnets found for ELB
```

**Solución:**
```hcl
resource "aws_subnet" "public" {
  tags = {
    Name                         = "public-subnet"
    "kubernetes.io/role/elb"     = "1"  # ← CRÍTICO
    "kubernetes.io/cluster/NAME" = "shared"
  }
}
```

**Resultado:**
- ✅ Load Balancers se crean automáticamente
- ✅ En las subnets correctas
- ✅ Sin intervención manual

### 4. Managed Node Groups vs Self-Managed

**Probé ambos:**

| Aspecto | Self-Managed | Managed Node Group |
|---------|--------------|-------------------|
| Setup | Complejo | Simple |
| Actualizaciones | Manual | Automático |
| Autoscaling | Configurar ASG | Built-in |
| Costo | Igual | Igual |
| Mantenimiento | Alto | Bajo |

**Decisión:** Managed Node Groups

**Razón:**
- ✅ AWS gestiona actualizaciones de AMI
- ✅ Autoscaling integrado
- ✅ Menos código Terraform
- ✅ Menos mantenimiento

### 5. Bottlerocket vs Amazon Linux 2

**Probé ambos AMIs:**

```hcl
# Amazon Linux 2
node_ami_type = "AL2_x86_64"

# Bottlerocket
node_ami_type = "BOTTLEROCKET_x86_64"
```

**Bottlerocket ganó:**
- ✅ OS minimalista (solo lo necesario para contenedores)
- ✅ Actualizaciones atómicas (rollback fácil)
- ✅ Menor superficie de ataque
- ✅ Mejor rendimiento

**Desventaja:**
- ❌ No puedes hacer SSH tradicional
- ❌ Debugging más complejo

### 6. Estado Remoto es Obligatorio

**Sin estado remoto:**
```bash
# Persona A
terraform apply
# Crea recursos

# Persona B (en paralelo)
terraform apply
# Conflicto! Corrupción del estado
```

**Con estado remoto + locking:**
```bash
# Persona A
terraform apply
# DynamoDB lock adquirido

# Persona B (en paralelo)
terraform apply
# Error: State locked by Persona A
# Espera hasta que termine
```

**Resultado:**
- ✅ Cero conflictos
- ✅ Trabajo en equipo sin problemas
- ✅ Estado versionado en S3

### 7. Access Entries vs aws-auth ConfigMap

**Método antiguo (aws-auth ConfigMap):**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapUsers: |
    - userarn: arn:aws:iam::123456:user/admin
      username: admin
      groups:
        - system:masters
```

**Problemas:**
- ❌ Fácil de romper (YAML mal formateado)
- ❌ Difícil de gestionar con Terraform
- ❌ No se integra bien con IAM

**Método moderno (Access Entries):**
```hcl
access_entries = {
  admin_user = {
    principal_arn = "arn:aws:iam::123456:user/admin"
    policies = {
      admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      }
    }
  }
}
```

**Ventajas:**
- ✅ Gestionado por AWS (no ConfigMap manual)
- ✅ Integración nativa con IAM
- ✅ Fácil de gestionar con Terraform
- ✅ Menos propenso a errores

---

## 💰 Costos Estimados

**Por ambiente (TEST o PROD):**

| Recurso | Costo Mensual (aprox) |
|---------|----------------------|
| EKS Control Plane | ~$73 ($0.10/hora) |
| EC2 Nodes (2x t3.medium) | ~$60 |
| NAT Gateway | ~$32 |
| Elastic IP | ~$3.60 |
| ECR (storage) | ~$1-5 (según uso) |
| S3 + DynamoDB | <$1 |
| **Total por ambiente** | **~$170-180/mes** |

**Ambos ambientes (TEST + PROD):**
- **~$340-360/mes**

**Optimizaciones posibles:**
- ✅ Apagar TEST fuera de horario laboral (ahorro ~50%)
- ✅ Usar Spot Instances para TEST (ahorro ~70% en EC2)
- ✅ Reducir a 1 NAT Gateway compartido (ahorro $32/mes)

---

## 🚀 Próximos Pasos

Esta plataforma base está lista para:

### 1. Desplegar Microservicios

```bash
# En el repo del microservicio
docker build -t mi-servicio .
docker tag mi-servicio:latest 035462351040.dkr.ecr.us-east-1.amazonaws.com/ecrdevops1720test:latest
docker push 035462351040.dkr.ecr.us-east-1.amazonaws.com/ecrdevops1720test:latest

kubectl apply -f k8s/deployment.yaml
```

### 2. Configurar Ingress Controller

```bash
# Instalar AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eksdevops1720test
```

### 3. Implementar Observabilidad

```bash
# Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack

# CloudWatch Container Insights
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml
```

### 4. Configurar Autoscaling

```yaml
# Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: mi-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: mi-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

```bash
# Cluster Autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

---

## 🎯 Conclusión

Este proyecto demuestra cómo construir una **plataforma base moderna y segura** en AWS que:

✅ **Elimina credenciales estáticas** con OIDC  
✅ **Separa ambientes** completamente (TEST/PROD)  
✅ **Automatiza despliegues** con GitHub Actions  
✅ **Gestiona estado** de forma segura (S3 + DynamoDB)  
✅ **Proporciona outputs reutilizables** para microservicios  
✅ **Implementa mejores prácticas** de seguridad y red  
✅ **Escala automáticamente** según demanda  

### Lo Más Importante

**Este NO es un proyecto de microservicios.**  
**Es la PLATAFORMA donde desplegarás microservicios.**

Piensa en esto como:
- **Terraform** = Constructor de edificios
- **Este proyecto** = El edificio (estructura, electricidad, agua)
- **Microservicios** = Los inquilinos que vivirán en el edificio

### Beneficios para Tu Equipo

1. **Desarrolladores** solo necesitan:
   - Escribir código
   - Crear Dockerfile
   - Definir manifiestos de Kubernetes
   - Push a Git

2. **DevOps** gestiona:
   - Infraestructura base (este proyecto)
   - Actualizaciones de EKS
   - Escalado de nodos
   - Monitoreo y alertas

3. **Seguridad** obtiene:
   - Cero credenciales estáticas
   - Auditoría completa
   - Separación de ambientes
   - Least privilege por defecto

---

## 📚 Recursos Adicionales

**Repositorio completo:**  
[github.com/hsniama/infra-devops-aws](https://github.com/hsniama/infra-devops-aws)

**Documentación:**
- [README completo](https://github.com/hsniama/infra-devops-aws/blob/main/README.md)
- [Guía de seguridad](https://github.com/hsniama/infra-devops-aws/blob/main/assets/Readmes/Security.md)
- [Glosario técnico](https://github.com/hsniama/infra-devops-aws/blob/main/assets/Readmes/Glossary.md)
- [Flujos de tráfico](https://github.com/hsniama/infra-devops-aws/blob/main/FLUJOS_TRAFICO_EKS.md)

**Diagramas:**
- [Arquitectura AWS](https://github.com/hsniama/infra-devops-aws/tree/main/assets/diagrams/AWS%20Diagrams)
- [Pipeline CI/CD](https://github.com/hsniama/infra-devops-aws/tree/main/assets/diagrams)

---

## 🤝 Contribuciones

¿Encontraste algo que mejorar? ¡Pull requests son bienvenidos!

**Ideas para contribuir:**
- Agregar soporte para más regiones
- Implementar VPC peering entre ambientes
- Agregar módulo de RDS
- Configurar Service Mesh (Istio/Linkerd)
- Implementar GitOps con ArgoCD

---

## 💬 Preguntas Frecuentes

**P: ¿Puedo usar esto en producción?**  
R: Sí, pero considera:
- Deshabilitar endpoint público de EKS
- Implementar VPN o bastion host
- Configurar WAF en Load Balancers
- Habilitar encryption at rest
- Implementar backup strategy

**P: ¿Funciona con otros proveedores de CI/CD?**  
R: Sí, el concepto OIDC funciona con:
- GitLab CI/CD
- CircleCI
- Azure DevOps
- Bitbucket Pipelines

**P: ¿Cuánto tiempo toma el despliegue inicial?**  
R: Aproximadamente:
- Setup (scripts): 5-10 minutos
- Primer despliegue TEST: 15-20 minutos
- Primer despliegue PROD: 15-20 minutos

**P: ¿Puedo agregar más ambientes (staging, qa)?**  
R: Sí, solo necesitas:
- Crear `environments/staging.tfvars`
- Crear `backends/staging.hcl`
- Actualizar workflow para detectar rama `staging/**`

---

**¿Te gustó este proyecto? Dale ⭐ en GitHub y comparte!**

**Tags:** #AWS #Terraform #DevOps #Kubernetes #EKS #OIDC #GitHubActions #InfrastructureAsCode #CloudNative #Platform Engineering

---

**Autor:** Henry Niama  
**GitHub:** [@hsniama](https://github.com/hsniama)  
**LinkedIn:** [Henry Niama](https://linkedin.com/in/tu-perfil)

---

*¿Preguntas? Déjalas en los comentarios 👇*
