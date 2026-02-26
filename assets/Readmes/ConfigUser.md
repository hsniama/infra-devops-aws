Disponible en [Español](#objetivos)

---

# Custom Policy Configuration for Terraform User

## Objectives
- Create a dedicated (non-administrator) IAM user to execute bootstrap scripts.
- Assign the minimum necessary permissions for the user to create:
  - The GitHub OIDC Provider.
  - The federated IAM role with Terraform permissions.
  - Administer the EKS Cluster.

## 1. Create a Dedicated IAM User
Instead of using the root account or an administrator user, it is recommended to create a specific user for automation, for example:

- **Name**: `terraformUser`
- **Access**: **Programmatic access only** (Access Key + Secret Key).
- **Console Access**: Disabled.

![Terraform User](./img/1.png)

This user will be responsible for running the `bootstrap_oidc.sh` and `bootstrap_backend.sh` scripts for the automated creation of the remote backend and the OIDC Provider in AWS.

## 2. Required Policies

The `terraformUser` requires specific permissions to create the remote backend, the OIDC Provider, and associated roles/policies. Below are the **four Customer Managed Policies** to be created and attached:

### 2.1 Policy: `OpenIDConnectProviderAccess`
Allows the creation and management of the GitHub OIDC Provider.

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
Allows the creation and management of IAM roles and policies required for the automation pipeline.

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
This policy combines the minimum permissions required for Terraform to utilize an S3 bucket as a remote backend and a DynamoDB table for state locking.

The policy is structured into 3 blocks:
- **Block 1 (Bucket)** → Permissions for the bucket itself (listing, versioning, encryption, and public access block).
- **Block 2 (Objects)** → Permissions for the objects stored within the bucket (read, write, and delete).
- **Block 3 (DynamoDB)** → Permissions to create, describe, delete, and use the lock table.

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

#### How to use this Policy?
Replace the placeholders in your `.json` file:
- `<BUCKET_NAME>` → The name of your S3 bucket used for the state.
- `<REGION>` → The AWS region where the DynamoDB table is located.
- `<ACCOUNT_ID>` → Your AWS account ID.
- `<TABLE_NAME>` → The name of the DynamoDB table used for state locking.

In my specific case, the policy is configured as follows:

```bash
"Resource": "arn:aws:s3:::tfstate-devops-henry-1720/*"
"Resource": "arn:aws:dynamodb:us-east-1:035462351040:table/tfstate-locks-devops"
```

### 2.4 Policy: `TerraformEKSAccess`
This policy provides the following capabilities:
- **eks:ListClusters** → The user can list all EKS clusters within the account.
- **eks:DescribeCluster** → The user can retrieve specific cluster details (endpoint, OIDC issuer, configuration, etc.).

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EKSClusterAccess",
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters",
                "eks:ListAccessEntries"
            ],
            "Resource": "*"
        }
    ]
}
```

**Note:** This policy does NOT grant permissions to manage Kubernetes resources such as pods, deployments, or services. That level of access is handled by **Kubernetes RBAC** (e.g., `system:masters`); for more details, refer to the `main.tf` file in the EKS module.

## 3. Execution: Policy Creation and Attachment

Navigate to the `assets/json/` directory where the four policy files are located:

```bash
cd assets/json
```
Run the following commands to create each of the policies:

**OpenIDConnectProviderAccess** Policy:
```bash
aws iam create-policy \
  --policy-name OpenIDConnectProviderAccess \
  --policy-document file://OpenIDConnectProviderAccess.json
```

**ManageRolesIAM** Policy:
```bash
aws iam create-policy \
  --policy-name ManageRolesIAM \
  --policy-document file://ManageRolesIAM.json
```

**TerraformBackendAccess** Policy:
```bash
aws iam create-policy \
  --policy-name TerraformBackendAccess \
  --policy-document file://TerraformBackendAccess.json
```
**TerraformEKSAccess** Policy:
```bash
aws iam create-policy \
  --policy-name TerraformEKSAccess \
  --policy-document file://TerraformEKSAccess.json
```

Now, execute the following command to attach each of the policies to the user:

```bash
aws iam attach-user-policy \
  --user-name terraformUser \
  --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/<POLICY_NAME>
```
Remember that you must replace the following parameters:

- `<ACCOUNT_ID>` → Your 12-digit AWS account ID (e.g., 03546235XXXX)
- `<POLICY_NAME>` → The name of each created policy (e.g. TerraformEKSAccess)

Example:

```bash
aws iam attach-user-policy \
  --user-name terraformUser \
  --policy-arn arn:aws:iam::03546235XXXX:policy/OpenIDConnectProviderAccess
```
You must execute this command four times, as there are four distinct policies.

Finally, verify that the policies are properly attached. Run the following command to list the policies associated with your user:

```bash
aws iam list-attached-user-policies --user-name <USER_NAME> 
```
Example:
```bash
aws iam list-attached-user-policies --user-name terraformUser
```

Result:
![Terraform User with 4 Policies](./img/2.png)

---

# Configuración de políticas personalizadas para usuario de Terraform

## Objetivos
- Crear un usuario IAM dedicado (no administrador) para que pueda ejecutar los scripts de bootstrap.
- Asignar las políticas mínimas necesarias para que el usuario pueda crear:
  - El OIDC Provider de GitHub.
  - El rol IAM federado con permisos para Terraform.
  - Adminsitrar el EKS Cluster.


## 1. Crear un usuario IAM dedicado
En lugar de usar la cuenta root o un usuario administrador, se recomienda crear un usuario específico para automatización, por ejemplo:

- Nombre: `terraformUser`
- Acceso: **solo programático** (Access Key + Secret Key).
- Sin acceso a la consola.

![Usuario Terraform](./img/1.png)

Este usuario podrá ejecutar los scripts de `bootstrap_oidc.sh` y `bootstrap_backend.sh` para la creación automatizada del backend remoto y el OIDC Provider en AWS.

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
                "eks:ListClusters",
                "eks:ListAccessEntries"
            ],
            "Resource": "*"
        }
    ]
}
```
Ojo: No da permisos para crear pods, deployments, services, etc. → eso lo maneja Kubernetes RBAC (ej. system:masters), ver el modulo eks el archivo main.tf.

## 3 Ejecución, creación y enlace de políticas
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

- `<ACCOUNT_ID>` → 03546235XXXX (Este es el ID de tu usuario creado en IAM)
- `<POLICY_NAME>` → TerraformEKSAccess (es el nombre de cada una de las políticas)

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
![Usuario Terraform con 4 Policies](./img/2.png)