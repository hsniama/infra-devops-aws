# infra-devops-aws

# Configuración de políticas personalizadas para usuario de Terraform

---

## Objetivos
- Crear un usuario IAM dedicado (no administrador) para que pueda ejecutar los scripts de bootstrap.
- Asignar las políticas mínimas necesarias para que el usuario pueda crear:
  - El OIDC Provider de GitHub.
  - El rol IAM federado con permisos para Terraform.
  - Adminsitrar el EKS Cluster.

---

## 1. Crear un usuario IAM dedicado
En lugar de usar la cuenta root o un usuario administrador, se recomienda crear un usuario específico para automatización, por ejemplo:

- Nombre: `terraformUser`
- Acceso: **solo programático** (Access Key + Secret Key).
- Sin acceso a la consola.

![Usuario Terraform](./assets/img/1.png)

Este usuario podrá ejecutar los scripts de `bootstrap_oidc.sh` y `bootstrap_backend.sh` para la creación automatizada del backend remoto y el OIDC Provider en AWS.

---

## 2. Políticas necesarias

El usuario `terraformUser` necesita permisos específicos para poder crear el backend remoto, OIDC Provider y los roles y policies asociados. A continuación, se detallan las **cuatro políticas de tipo customer managed** a ser creadas y enlazadas:

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
Sustituye en el archivo .json:

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

## 2.1 Ejecución, creación y enlace de políticas
Ingresa al archivo assets/json/ donde yacen los 4 archivos (políticas):

```bash
cd assets/json
```
Ejecuta los siguientes comandos paraa crear cada una de las políticas:

Política **OpenIDConnectProviderAccess**:
```bash
aws iam create-policy \
  --policy-name OpenIDConnectProviderAccess \
  --policy-document file://OpenIDConnectProviderAccess.json
```

Política **ManageRolesIAM**:
```bash
aws iam create-policy \
  --policy-name ManageRolesIAM \
  --policy-document file://ManageRolesIAM.json
```

Política **TerraformBackendAccess**:
```bash
aws iam create-policy \
  --policy-name TerraformBackendAccess \
  --policy-document file://TerraformBackendAccess.json
```
Política **TerraformEKSAccess**:
```bash
aws iam create-policy \
  --policy-name TerraformEKSAccess \
  --policy-document file://TerraformEKSAccess.json
```

Ahora, ejecuta el siguiente comando para adjuntar cada una de las policies al usuario:

```bash
aws iam attach-user-policy \
  --user-name terraformUser \
  --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/<POLICY_NAME>
```
Recuerda que debes reemplazar los siguientes parámetros:

- <ACCOUNT_ID> → 03546235XXXX (Este es el ID de tu usuario creado en IAM)
- <POLICY_NAME> → TerraformEKSAccess (es el nombre de cada una de las políticas)

Ejemplo:

```bash
aws iam attach-user-policy \
  --user-name terraformUser \
  --policy-arn arn:aws:iam::03546235XXXX:policy/OpenIDConnectProviderAccess
```
Este comando debes ejecutarlo cuatro veces ya que son cuatro políticas.

Finalmente, verifica que las políticas están adjuntas. Ejecuta el siguiente comandos para listas las policies asociadas a tu usuario:

```bash
aws iam list-attached-user-policies --user-name <USER_NAME> 
```
Ejemplo:
```bash
aws iam list-attached-user-policies --user-name terraformUser
```

Resultado:
![Usuario Terraform con 4 Policies](./assets/img/2.png)