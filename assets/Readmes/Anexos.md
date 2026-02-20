
## Anexos

#### 0. ¿Qué hace el script `bootstrap_oidc.sh`?
- Crea/valida el OIDC Provider de GitHub (token.actions.githubusercontent.com).
- Crea un rol IAM con trust policy que permite solo a tu repo (en mi caso: hsniama/infra-devops-aws) asumirlo desde GitHub Actions.

    ![Rol Creado](./assets/img/3.png)

- Crea una policy de permisos (ej. gh-oidc-terraform-infra-devops-aws-policy) con acceso a:
    - S3 (backend de Terraform).
    - DynamoDB (lock de Terraform).
    - ECR, VPC, EC2, ELB, EKS, IAM, Autoscaling, Logs, KMS (infraestructura).

    ![Policy Creada](./assets/img/4.png)

- Adjunta/Enlaza la policy al rol.

    ![Policy attached](./assets/img/5.png)

### 1. Explicación rol `gh-oidc-terraform-infra-devops-aws`

El rol `gh-oidc-terraform-infra-devops-aws`
Es un IAM Role en nuestra cuenta AWS.
Tiene dos cosas importantes:
- Trust policy → define quién puede asumirlo. En nuestro caso:
    - Solo el OIDC provider de GitHub (token.actions.githubusercontent.com).
    - Solo nuestro repo (hsniama/infra-devops-aws) y ramas específicas (main, test/*, pull_request).
- Permissions policy (`gh-oidc-terraform-infra-devops-aws-policy`) → define qué puede hacer una vez asumido.
    - Crear VPCs, EC2, EKS, S3, DynamoDB, etc. (todo lo que Terraform necesita).

**¿Quién usa este rol?**
NO lo usamos nostros directamente con el usuario `terraformUser` (en mi caso, este es mi usuario IAM). Lo usa GitHub Actions cuando corre el  pipeline.

**¿Cómo lo usa GitHub Actions?**
1. En nuestro workflow `terraform.yml` de GitHub Actions, se configura el secreto:

```json
AWS_ROLE_TO_ASSUME: arn:aws:iam::035462351040:role/gh-oidc-terraform-infra-devops-aws
```
  ![Rol en terraform.yml](./assets/img/18).

2. GitHub genera un token OIDC cuando se ejecuta el pipeline.
3. AWS valida ese token contra el OIDC provider que creaste.
4. Si el token corresponde a tu repo y rama permitida → AWS deja que GitHub asuma el rol.
5. Al asumir el rol, GitHub obtiene credenciales temporales (STS) con los permisos de la policy.
6. Terraform, dentro del pipeline, usa esas credenciales para desplegar infraestructura en AWS.

**Ventajas de este modelo**
**Seguridad**: no se necesita guardar AWS_ACCESS_KEY_ID y AWS_SECRET_ACCESS_KEY en GitHub.
**Temporalidad**: las credenciales duran minutos, no son llaves permanentes.
**Control fino**: solo tu repo y ramas específicas pueden asumir el rol.

### 3. Explicación del workflow `terraform.yml` 

Este pipeline diferencia entre ambientes de prueba y producción. Los PR contra main generan un plan de cambios en prod, los merges a main aplican en prod, los pushes a ramas dev/** aplican en test, y también se puede ejecutar manualmente seleccionando el ambiente.

**Flujo de jobs**
El pipeline tiene dos jobs principales:

- Job plan
  - Se ejecuta siempre (PR, push, manual).
  - Determina el ambiente (prod o test) según la rama/evento.
  - Corre terraform fmt, init, validate, y plan.
  - Genera un archivo tfplan y logs que se suben como artifacts.

- Job apply
  - Solo corre en push o workflow_dispatch (no en PR).
  - Descarga el plan generado por el job anterior.
  - Ejecuta terraform apply con ese plan exacto.
  - Muestra outputs clave (ECR, EKS, etc.).
  - Sube logs como artifacts.

**Seguridad y autenticación**
- Usa OIDC con GitHub Actions para asumir un rol en AWS (AWS_ROLE_TO_ASSUME).
- No requiere guardar Access Keys en GitHub.
- Las credenciales son temporales y seguras.

**Resumen de ejecución**
- PR → main → plan en prod (revisión).
- Push → main → plan + apply en prod (despliegue real).
- Push → dev/ → plan + apply en test (entorno de pruebas).
- Manual dispatch → plan + apply en test o prod según input.

### 4. Seguridad

Actualmente:
- Endpoint público habilitado (solo para pruebas)
- Acceso controlado vía IAM
- OIDC para GitHub Actions (sin secrets estáticos)

En producción se recomienda:

- Restringir cluster_endpoint_public_access_cidrs
- Deshabilitar endpoint público
- Usar AWS Load Balancer Controller + ACM para HTTPS

### 5. Diferencias respecto a una Infraestructura Azure

La siguiente tabla muestra cómo se mapean los componentes principales:

| Azure             | AWS              |
|-------------------|------------------|
| AKS               | EKS              |
| ACR               | ECR              |
| VNet              | VPC              |
| Azure AD OIDC     | IAM OIDC         |
| Storage Account   | S3               |
| Blob Container    | S3 Key           |
| Azure Lock        | DynamoDB Lock    |

Explicación:

- **AKS ↔ EKS**: Kubernetes administrado en Azure vs. AWS.  
- **ACR ↔ ECR**: Registro de contenedores para imágenes Docker.  
- **VNet ↔ VPC**: Redes virtuales para aislar y controlar tráfico.  
- **Azure AD OIDC ↔ IAM OIDC**: Proveedores de identidad federada para autenticación.  
- **Storage Account ↔ S3**: Almacenamiento de objetos.  
- **Blob Container ↔ S3 Key**: Contenedores de blobs vs. objetos dentro de un bucket.  
- **Azure Lock ↔ DynamoDB Lock**: Mecanismos de bloqueo para evitar conflictos en el estado de Terraform.  
