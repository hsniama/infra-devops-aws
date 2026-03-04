## El Descubrimiento

Hace unos meses, mientras conversaba con un amigo DevOps Engineer, me contaba una de sus frustraciones:

*"En algunas de las empresas y proyectos en los que he trabajado, me ha tocado construir toda la infraestructura: VPCs, subnets, EKS… además de armar el pipeline de despliegue, tanto de la plataforma como del microservicio. Pero como DevOps, lo que realmente quiero es enfocarme en desplegar el microservicio. Mi sueño sería simplemente hacer kubectl apply… y que todo funcione.*"

Ahí lo vi claro: el DevOps Engineer termina peleando con VPCs y subnets cuando en realidad debería enfocarse en automatizar despliegues de aplicaciones.

**Esa reflexión cambió todo.**

---

## La Separación de Responsabilidades que Falta

Este proyecto nace justamente para resolver ese choque de responsabilidades.

Nosotros asumimos el rol de **Cloud/Platform Engineer** y construimos el cascarón-base de infraestructura para que luego el equipo de DevOps/App Delivery despliegue aplicaciones sobre una plataforma ya preparada.

En nuestro enfoque:
- **Cloud/Platform Engineering (este repositorio)** construye la base: red, infraestructura, identidad, estado remoto, clúster, registro y pipeline de infraestructura.
- **DevOps/App Delivery (repositorio de aplicaciones, después)** consume outputs de esta base para desplegar microservicios con velocidad y menos riesgo.

No es burocracia. Es diseño organizacional y técnico para escalar. Como **Cloud/Platform Engineer**, mi trabajo no es que cada DevOps recree infraestructura. Mi trabajo es **construir la plataforma una vez** y que ellos la consuman.


![Roles diff](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/juydh55nx19my656q0g8.png)

---

## Lo Que Construí

Decidí materializar esta visión en un proyecto real:

**Una plataforma AWS completa, reutilizable y open source.**

![AWS Architecture](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/dn6ee9clbnomjdjqavac.png)
_Ver diagrama completo en_ [GitHub](https://github.com/hsniama/infra-devops-aws/blob/dev/henry/assets/diagrams/aws/aws_infrastructure_diagram.png)

Como se observa, tomamos la responsabilidad de preparar el cascarón completo de infraestructura para que luego un equipo DevOps/App pueda enfocarse en desplegar producto, no en pelear con infraestructura base.

En concreto, dejamos listo:
- Redes en AWS separadas por ambiente (`test` y `prod`).
- Clústeres EKS por ambiente.
- Repositorios ECR por ambiente para imágenes.
- Autenticación segura por OIDC en GitHub Actions.
- Estado remoto de Terraform con bloqueo.
- CI/CD de infraestructura con reglas claras por ambiente.

No buscamos “hacer todo en un repo”. Buscamos colaborar mejor: plataforma por un lado, aplicaciones por otro, con un contrato claro entre ambos.

## Tecnologías que usamos para construir esta base

- **AWS**: VPC, EKS, ECR, IAM, S3, DynamoDB
- **Terraform**: para construir recursos de AWS con módulos reutilizables
- **GitHub Actions**: para ejecutar el pipeline de infraestructura por ambiente
- **OIDC**: Autenticación federada sin Access Keys estáticas
- **EKS Access Entries**: para controlar quién entra al clúster sin depender solo de configuraciones manuales

---

## Los 4 Pilares que Hacen la Diferencia

### 1. Separación de Ambientes (De Verdad)

La mayoría dice "tenemos TEST y PROD separados" pero comparten VPC.

**Yo fui más allá:**

- **TEST** → VPC `10.110.0.0/16` 
- **PROD** → VPC `10.111.0.0/16` 


![VPCs](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/cshg89c8v5blfz74jwjd.png)

- Estados de Terraform **totalmente independientes** por ambiente y variables separadas por tfvars.

![Terraform States](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/agd9j7mprx2fd9ypdcl3.png)

- El pipeline selecciona dinámicamente backend y variables según la rama, evitando colisiones entre entornos y **cero recursos compartidos**.


![Pipeline](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/1jq48r0jx0lbigbtiv73.png)

**¿Por qué?**

Porque un viernes a las 6 PM, alguien va a hacer un cambio en TEST. Y si comparten recursos, PROD se cae.

**Con esta separación, puedo destruir/modificar TEST sin miedo.** Esa tranquilidad no tiene precio.

---

### 2. OIDC: La Innovación de seguridad que cambia todo

Aquí está la joya del proyecto. 
**El problema que todos tienen:** 
- Credenciales AWS guardadas en **GitHub Secrets** 
- Ejemplo: 
   - `AWS_ACCESS_KEY_ID: AKIAXXXXX` 
   - `AWS_SECRET_ACCESS_KEY: xxxxx` 

Si alguien hace commit de esas keys; es un **desastre**

**Mi solución: OIDC**

![OIDC-Flow](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/ir0agcmskthbjb3ux49k.png)

Sin llaves estáticas en GitHub.

Esto mejora de forma directa:
- Seguridad operativa.
- Caducidad de credenciales.
- Control por trust policy.
- Reducción de superficie de ataque.
- Cero credenciales permanentes: **Cero riesgo**.

Y lo mejor: el Trust Policy asegura que **solo mi repositorio** puede asumir el rol.

---

### 3. Outputs: El Puente Entre Plataforma y Aplicaciones

Aquí es donde la separación de roles cobra vida.
La plataforma no entrega “infraestructura cruda”, sino outputs listos para usar:

| Output        | Ejemplo                                         |
|---------------|-------------------------------------------------|
| **ECR_URL**   | 123456.dkr.ecr.us-east-1.amazonaws.com/app      |
| **EKS_CLUSTER** | eksdevops1720testXX                           |
| **EKS_ENDPOINT** | https://XXXXX.eks.amazonaws.com              |
| **REGION**    | us-east-1                                       |

![Outputs](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/8k7ubu95tcnbokxpyf2b.png)
_Ver Outputs en_ [GitHub](https://github.com/hsniama/infra-devops-aws/actions/runs/22232310474/job/64315042012)

Cómo los consume el DevOps Engineer en su repo (pipeline):

```yaml
# Pipeline que aprovecha los outputs de la plataforma
docker push $ECR_URL/mi-app:latest
aws eks update-kubeconfig --name $EKS_CLUSTER
kubectl apply -f k8s/
```
Ejemplo directo en consola:
```bash
aws eks update-kubeconfig --name eksdevops1720testXX
kubectl apply -f deployment.yaml
# y funciona... Sin configuración adicional.
```

**Eso es todo.**

El DevOps Engineer,
- No necesita saber profundamente cómo está configurada la VPC.  
- No necesita entender por completo route tables.  
- No necesita ser experto en el levantamiento del cluster EKS.

**Solo necesita desplegar su aplicación** en la plataforma previamente desplegada.

---

### 4. Pipeline Inteligente: Rápido en TEST, Seguro en PROD

![Ci-Cd](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/u8nsnhlyf2chgp0hdec0.png)

Diseñé el pipeline pensando en **velocidad vs control**: 
**TEST (Velocidad)** 
- `git push origin dev/**`. 
- Terraform despliega automáticamente. 
- Sin aprobaciones. 
- Feedback en ~15 minutos. 

**PROD (Control)** 
- Pull Request a `main`.
- Terraform plan (revisión del equipo). 
- Aprobación manual obligatoria - Merge → despliegue

**Lo innovador:**
- Autenticación OIDC (sin keys).
- Estado remoto con locking (sin conflictos).
- Artifacts guardados (rollback fácil).
- Aprobaciones solo donde importan.

Esto permite tener despliegues limpios con artifacts de valor:

![Pipeline](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/hppaul3q6dw8dozfni52.png)

---

## Acceso al Cluster: EKS Access Entries

AWS lanzó algo revolucionario: **Access Entries**. En lugar de editar ConfigMaps manualmente, ahora se puede definir el acceso al Cluster directamente en Terraform:

```hcl
eks_access_entries = {
  platform_engineer = {
    principal_arn = "arn:aws:iam::123456:user/henry"
    policies = {
      admin = {
        policy_arn = "AmazonEKSClusterAdminPolicy"
      }
    }
  }
  
  devops_team = {
    principal_arn = "arn:aws:iam::123456:role/gh-oidc-role"
    policies = {
      deploy = {
        policy_arn = "AmazonEKSClusterAdminPolicy"
      }
    }
  }
}
```

**¿Qué cambia con Access Entries?**

1. **Gestionado por AWS** - No más ConfigMaps manuales.
2. **Integración nativa con IAM** - Roles y usuarios directamente en AWS.
3. **Validación automática** - Terraform valida antes de aplicar.
4. **Auditoría completa** - CloudTrail registra cada acción.

**Lo que significa en la práctica**

Cuando un DevOps Engineer necesita acceso al cluster, yo simplemente:
- Agrego su rol IAM en Terraform (en nuestro caso, en el módulo).
- Ejecuto `terraform apply`
- Listo: Tiene acceso inmediato al cluster.

EKS Clusters:

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/2tx2yvotentiyuvmpxaj.png)

Acceso al Cluster (como DevOps Engineer):
![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/i1rmcb57grncl7n4ed6a.png)

Lista de EKS Access Entries configurados (ejemplo):
![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/dw3bkz3o6zfv8pwvahli.png)

Esto es lo que implementamos en el proyecto. En donde la separación de responsabilidades entra en acción:
- Yo como Cloud/Platform Engineer gestiono QUIÉN tiene acceso.
- Ellos usan ese acceso para desplegar.
- Nadie toca ConfigMaps sin riesgo de romper nada.
- Todo versionado en Git.

---

## Alcance real de este proyecto

Este repositorio no despliega microservicios directamente. Su propósito es **construir la base sólida** para que eso ocurra bien después.

Tampoco incluye todavía:
- observabilidad completa de workloads,
- ingress/controller de apps,
- autoscaling de capa aplicación.

Lo que sí hace:
- Define redes, clústeres, repositorios (ECR) y pipelin de infraestructura.
- Publica outputs listos para que otros repos desplieguen aplicaciones.
- Establece seguridad moderna (OIDC, IAM roles temporales).

Lo que no incluye (por diseño):
- Observabilidad completa de workloads
- Ingress/controller de aplicaciones
- Autoscaling de la capa aplicación

Esto no es una carencia accidental.
Es una decisión consciente de alcance:

- La plataforma base asegura seguridad y gobernanza.
- La entrega de aplicaciones se gestiona en repos separados.
- La separación de responsabilidades evita fricción y escalamiento caótico.

## Consideraciones antes de usarlo en producción

Esta base es sólida, pero para producción real conviene reforzar:

- **Observabilidad**: logs de control plane EKS, métricas y alertas.
- **Hardening de endpoint EKS**: restringir `public_access_cidrs` o endpoint privado-only en prod.
- **IAM más granular**: reducir permisos amplios y cerrar a recursos concretos.
- **Seguridad en CI**: checks de IaC/policies/images.
- **Autoscaling de workloads**: HPA + Cluster Autoscaler/Karpenter.
- **Arquitectura HA/costos**: evaluar NAT por AZ según RTO/RPO y presupuesto.

---

## Para Quién Es Esta Plataforma

### Si Eres Cloud/Platform Engineer:
- Úsala como base para tu organización o proyectos.
- Adapta los módulos a tus necesidades.
- Contribuye mejoras al proyecto.

### Si Eres DevOps Engineer:
- Úsalo como referencia de lo que necesitas.
- Enfócate en desplegar aplicaciones, no en infraestructura.

---

## Lo Que Viene

Esta plataforma es el **punto de partida**, no el destino final.

**Próximas evoluciones:**
- Multi-región (disaster recovery)
- Service Mesh (observabilidad avanzada)
- GitOps (ArgoCD/FluxCD)
- Políticas de seguridad (OPA)

**Pero lo fundamental ya está:**
- Separación de responsabilidades
- Seguridad por diseño
- Automatización real
- Reutilización

**Y está listo para usar hoy.**

---

## Repositorio

Todo está documentado, probado y con los pasos para armar y desplegar:

📦 **Repositorio:** [github.com/hsniama/infra-devops-aws](https://github.com/hsniama/infra-devops-aws)


**Clona. Adapta. Despliega. Contribuye. **

---

## Open source y colaboración

Si te interesa esta línea de trabajo, puedes colaborar con ideas o PRs:

- Hardening IAM por recurso.
- Observabilidad end-to-end.
- Policy-as-code en pipeline.
- Blueprint del repo de aplicaciones que consuma outputs.

Recordemos que **La mejor plataforma se construye entre todos.**

---

## Reflexión Final

La mejor automatización no es la que hace más cosas. Es la que define mejor responsabilidades y reduce riesgo sistémico.

Este proyecto va de eso: como equipo de plataforma, diseñar primero el cascarón correcto para que luego desplegar aplicaciones sea más simple, seguro y repetible.

---

- ⭐ Dale estrella en GitHub  
- 🔄 Comparte con tu equipo  
- 💬 Déjame tus comentarios  
- 🤝 Contribuye al proyecto  

**Construyamos mejores plataformas, juntos.**

---

Tags: AWS, Terraform, PlatformEngineering, DevOps, CloudArchitecture, OpenSource, OIDC, Kubernetes, AWS, Cloud

---

- **Autor:** Henry Niama  
- **Rol:** Systems Engineer  
- **GitHub:** [@hsniama](https://github.com/hsniama/infra-devops-aws)  
- **LinkedIn:** [Henry Niama](https://linkedin.com/in/hsniama)
