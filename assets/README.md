# infra-devops-aws

# Configuración de OIDC en AWS para GitHub Actions y Bucket S3 más DynamoDB para estado de Terraform

Este documento describe cómo configurar un **OpenID Connect (OIDC) Provider** en AWS IAM para permitir que un repositorio de GitHub use **GitHub Actions** y despliegue infraestructura con **Terraform** en AWS **sin usar credenciales estáticas**.

---

## Objetivo
- Crear un usuario IAM dedicado (no administrador) para ejecutar el script de bootstrap.
- Asignar las políticas mínimas necesarias para que ese usuario pueda crear:
  - El OIDC Provider de GitHub.
  - El rol IAM federado con permisos para Terraform.
- Ejecutar el script de bootstrap que automatiza la creación del OIDC Provider, rol y policy.
- Configurar el secreto en GitHub Actions para asumir el rol en AWS.

---

## 1. Crear un usuario IAM dedicado
En lugar de usar la cuenta root o un usuario administrador, se recomienda crear un usuario específico para automatización, por ejemplo:

- Nombre: `terraformUser`
- Acceso: **solo programático** (Access Key + Secret Key).
- Sin acceso a la consola.

![Usuario Terraform](./assets/img/1.png)

Este usuario será el que ejecute el script de bootstrap_oidc.sh y bootstrap_backend.sh.

---

## 2. Crear las políticas necesarias

El usuario `terraformUser` necesita permisos específicos para poder crear el OIDC Provider y los roles asociados. Creamos **tres políticas administradas por el cliente**:

### 2.1 Policy: `OpenIDConnectProviderAccess`
Permite crear y administrar el OIDC Provider de GitHub.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateOpenIDConnectProvider",
        "iam:GetOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider"
      ],
      "Resource": "*"
    }
  ]
}
```
### 2.2 Policy: `ManageRolesIAM`
Permite crear y administrar roles y policies IAM necesarias para el pipeline.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
				"iam:CreateRole",
				"iam:GetRole",
				"iam:UpdateAssumeRolePolicy",
				"iam:AttachRolePolicy",
				"iam:CreatePolicy",
				"iam:GetPolicy",
				"iam:CreatePolicyVersion",
				"iam:ListPolicyVersions",
				"iam:DetachRolePolicy",
				"iam:DeletePolicyVersion",
				"iam:DeletePolicy",
        "iam:DeleteRole"
      ],
      "Resource": "*"
    }
  ]
}
```
### 2.3 Policy: `TerraformBackendAccess`
Esta es una Policy que combina los permisos mínimos necesarios para que Terraform pueda usar un bucket S3 como backend y una tabla DynamoDB para locks.

La policy esta divida en 3 bloques:
- **Bloque 1 (Bucket)** → permisos sobre el bucket en sí (listar, versioning, encryption, public access block).
- **Bloque 2 (Objetos)** → permisos sobre los objetos dentro del bucket (leer, escribir, borrar).
- **Bloque 3 (DynamoDB)** → permisos para crear, describir, borrar y usar la tabla de locks.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateS3Bucket",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock"
      ],
      "Resource": "arn:aws:s3:::tfstate-devops-henry-1720"
    },
    {
      "Sid": "TerraformStateS3Objects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::<BUCKET_NAME>/*"
    },
    {
      "Sid": "TerraformLockDynamoDB",
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DescribeTable",
        "dynamodb:DeleteTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:<REGION>:<ACCOUNT_ID>:table/<TABLE_NAME>"
    }
  ]
}

```
#### ¿Cómo usar esta Policy?
Sustituye:

- `<BUCKET_NAME>` → el nombre de tu bucket S3 para el estado.
- `<REGION>` → la región donde creas la tabla DynamoDB.
- `<ACCOUNT_ID>` → tu AWS account ID.
- `<TABLE_NAME>` → el nombre de la tabla DynamoDB para locks.

En mi caso, la policy se configura de esta manera:

```bash
"Resource": "arn:aws:s3:::tfstate-devops-henry-1720/*"
"Resource": "arn:aws:dynamodb:us-east-1:035462351040:table/tfstate-locks-devops"
```

### 2.4 Policy: `TerraformEKSAccess`
Esta policy hace lo siguiente:

- **eks:ListClusters** → el usuario puede listar todos los clusters EKS en la cuenta.
- **eks:DescribeCluster** → el usuario puede obtener los detalles de un cluster específico (endpoint, OIDC issuer, configuración, etc.).

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EKSClusterAccess",
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters"
            ],
            "Resource": "*"
        }
    ]
}
```
Ojo: No da permisos para crear pods, deployments, services, etc. → eso lo maneja Kubernetes RBAC (ej. system:masters), ver el modulo eks el archivo main.tf.

FInalmente, despues de crear estas 4 Policy en IAM, las enlazamos a nuestro usuario, en mi caso es el usuario `terraformUser` y ya se puede ejecutar los scripts del siguiente apartado. 

![Usuario Terraform con 4 Policies](./assets/img/2.png)

### 3. Ejecutar el script de bootstrap_backend.sh

Este script es un Bootstrap de Backend para Terraform. Su función es preparar automáticamente "la casa" donde Terraform guardará su archivo de estado (.tfstate) antes de lanzar cualquier infraestructura.

```bash
chmod +x scripts/bootstrap_backend.sh
scripts/bootstrap_backend.sh <region> <bucket_name> <dynamodb_table>
```
Ejemplo:

```bash
./scripts/bootstrap_backend.sh us-east-1 tfstate-devops-henry-1720 tfstate-locks-devops
```
En donde <region> es la región de AWS en la cual estamos trabajando, <bucket_name> es el nombre completo del bucket a crear, y <dynamodb_table> es el nombre de la tabla de dynamodb.

Como resultado, en AWS tendremos la creación de un bucket, vacío, y cuando despleguemos posteriormente la infraestructura, se crearán las carpetas de test y prod como se observa a continuación:

  ![Bucket Creado](./assets/img/7.png)

### 4. Ejecutar el script de bootstrap_oidc.sh
Con las credenciales del usuario `terraformUser` configuradas en nuestro entorno local o de desarrollo (~/.aws/credentials o variables de entorno), ejecuta en tu terminal:

```bash
chmod +x scripts/bootstrap_oidc.sh
./scripts/bootstrap_oidc.sh <account_id> <repo_full_name> <role_name> <region>
```
Ejemplo:

```bash
./scripts/bootstrap_oidc.sh 035462351040 hsniama/infra-devops-aws gh-oidc-terraform-infra-devops-aws us-east-1
```
En donde <account_id> es el ID de tu cuenta, <repo_full_name> es el nombre completo de tu repositorio de GitHub, <role_name> es el nombre del rol que asignamos, puede ser el mismo y <region> es la región de AWS en la cual estamos trabajando.

Al ejecutar el script correctamente verás algo como:

```json
==> Ensuring GitHub OIDC provider exists...
OIDC provider already exists: arn:aws:iam::035462351040:oidc-provider/token.actions.githubusercontent.com
==> Creating/updating role: gh-oidc-terraform-infra-devops-aws
Role created.
==> Ensuring policy exists: gh-oidc-terraform-infra-devops-aws-policy
Policy created.
==> Attaching policy to role...

DONE.
Set this GitHub secret in infra-devops-aws repo:
AWS_ROLE_TO_ASSUME = arn:aws:iam::035462351040:role/gh-oidc-terraform-infra-devops-aws
```
Como resultado, se tendrá el rol `gh-oidc-terraform-infra-devops-aws` y el policy `gh-oidc-terraform-infra-devops-aws-policy` enlazado.

  ![Rol Creado](./assets/img/8.png)

#### ¿Qué hace el script?
- Crea/valida el OIDC Provider de GitHub (token.actions.githubusercontent.com).
- Crea un rol IAM con trust policy que permite solo a tu repo (en mi caso: hsniama/infra-devops-aws) asumirlo desde GitHub Actions.

    ![Rol Creado](./assets/img/3.png)

- Crea una policy de permisos (ej. gh-oidc-terraform-infra-devops-aws-policy) con acceso a:
    - S3 (backend de Terraform).
    - DynamoDB (lock de Terraform).
    - ECR, VPC, EC2, ELB, EKS, IAM, Autoscaling, Logs, KMS (infraestructura).

    ![Policy Creada](./assets/img/4.png)

- Adjunta la policy al rol.

    ![Policy attached](./assets/img/5.png)

En resumen:

- GitHub genera un token OIDC → incluye sub.
- AWS recibe el token → busca el rol → revisa la trust policy.
- Si el sub del token coincide con alguno de los patrones permitidos, AWS deja asumir el rol.

### 4. Configurar GitHub Actions

En tu repositorio de GitHub (hsniama/infra-devops-aws):
1. Ve a Settings → Secrets and variables → Actions → New repository secret.
2. Crea un secreto llamado:

```json
AWS_ROLE_TO_ASSUME = arn:aws:iam::035462351040:role/gh-oidc-terraform-infra-devops-aws
```
En donde el valor de `AWS_ROLE_TO_ASSUME` es el resultado que te da la ejecución del script, debes copiarlo.
    ![Secret configurado](./assets/img/6.png)

3. El workflow `terraform.yml` de GitHub Actions, usa este rol (AWS_ROLE_TO_ASSUME) con OIDC para obtener credenciales temporales en AWS.

## Conclusión
Con este setup:

- No necesitas Access Keys en GitHub.
- GitHub Actions obtiene credenciales temporales vía OIDC y permite que se autentique en AWS sin usar llaves estáticas.
- Terraform puede desplegar infraestructura en AWS de forma segura y automatizada.
- El usuario terraformUser (en mi caso) tiene permisos mínimos para crear el OIDC, sin ser administrador, gracias a las policy previamente añadidas.

## Anexos

### 1. Explicación rol `gh-oidc-terraform-infra-devops-aws`

El rol `gh-oidc-terraform-infra-devops-aws`
Es un IAM Role en tu cuenta AWS.
Tiene dos cosas importantes:
- Trust policy → define quién puede asumirlo. En tu caso:
    - Solo el OIDC provider de GitHub (token.actions.githubusercontent.com).
    - Solo tu repo (hsniama/infra-devops-aws) y ramas específicas (main, test/*, pull_request).
- Permissions policy (`gh-oidc-terraform-infra-devops-aws-policy`) → define qué puede hacer una vez asumido.
    - Crear VPCs, EC2, EKS, S3, DynamoDB, etc. (todo lo que Terraform necesita).

**¿Quién usa este rol?**
- No lo usamos nostros directamente con el usuario `terraformUser`.
- Lo usa GitHub Actions cuando corre el  pipeline.

**¿Cómo lo usa GitHub Actions?**
1. En tu workflow de GitHub Actions, configuras el secreto:
```json
AWS_ROLE_TO_ASSUME: arn:aws:iam::035462351040:role/gh-oidc-terraform-infra-devops-aws
```
2. GitHub genera un token OIDC cuando se ejecuta el pipeline.
3. AWS valida ese token contra el OIDC provider que creaste.
4. Si el token corresponde a tu repo y rama permitida → AWS deja que GitHub asuma el rol.
5. Al asumir el rol, GitHub obtiene credenciales temporales (STS) con los permisos de la policy.
6. Terraform, dentro del pipeline, usa esas credenciales para desplegar infraestructura en AWS.

**Ventajas de este modelo**
**Seguridad**: no se necesita guardar AWS_ACCESS_KEY_ID y AWS_SECRET_ACCESS_KEY en GitHub.
**Temporalidad**: las credenciales duran minutos, no son llaves permanentes.
**Control fino**: solo tu repo y ramas específicas pueden asumir el rol.