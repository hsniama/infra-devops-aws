Disponible en [Español](#1-que-seguridad-tiene-este-proyecto)

---

## Security Architecture

This project follows modern cloud security best practices by eliminating static credentials and implementing federated identity with least privilege access.

### 1. OIDC-Based Authentication (No Static AWS Keys)

Instead of storing long-lived AWS access keys, this project uses GitHub OIDC federation:

`GitHub Actions` → `OIDC Token` → `AWS IAM Role` → `STS Temporary Credentials`

Security benefits:

- No AWS secrets stored in GitHub
- No credential rotation required
- Short-lived temporary credentials
- Repository-scoped trust policy
- Organization-level restriction

Only the specific GitHub repository is allowed to assume the IAM role (got it in `scripts/bootstrap_oidc.sh`).

### 2️. Least Privilege IAM Policies

The IAM role assumed by GitHub:

- Is restricted via trust policy to the GitHub OIDC provider
- Is scoped to a specific repository
- Grants only the permissions required for Terraform execution

This reduces the blast radius and prevents unauthorized access from external sources.

### 3. Secure Terraform Remote State

Terraform state is stored securely using:

- Amazon S3 (remote backend)
- DynamoDB (state locking)

Security features:

- Centralized state management
- State locking to prevent concurrent modifications
- Improved integrity and consistency
- Optional S3 versioning for rollback protection

This prevents local state leakage and race conditions during deployments.

### 4. Network Isolation

Each environment (test/prod) provisions:

- Dedicated VPC
- Public and private subnets
- EKS nodes in private subnets
- Controlled internet access

This design ensures:

- Workloads are not directly exposed to the public internet
- Environment-level isolation
- Clear separation between infrastructure layers

### 5. Environment Separation

The project maintains isolated environments:

- Separate VPCs
- Separate Terraform state files
- Independent deployment workflows

This prevents cross-environment impact and enforces deployment discipline.

## Security Design Principles

This project is built around:

- Zero static credentials
- Federated identity (OIDC)
- Least privilege access
- Infrastructure as Code
- State integrity protection
- Network segmentation
- Environment isolation

---

## 1. ¿Que seguridad tiene este proyecto?

El proyecto `infra-devops-aws` tiene seguridad en 4 capas.

### 1. Autenticación segura (OIDC – No static credentials)

En lugar de usar:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Se está usando:

GitHub → OIDC → IAM Role → STS temporary credentials

Esto significa:

- No hay claves almacenadas en GitHub
- No hay secretos en el repo
- No hay rotación manual de credenciales
- Las credenciales son temporales

### 2. Autorización basada en IAM (Least Privilege)

El IAM Role generado en `scripts/bootstrap_oidc.sh`:

- Solo puede ser asumido por un repo específico (este repo)
- Solo desde nuestra organización
- Solo desde GitHub OIDC
- Tiene políticas controladas

Esto evita:

- Que otro repo use este rol
- Que alguien robe una clave estática
- Que alguien asuma el rol desde fuera

### 3. Protección del Terraform State

Estamos usando:

- S3 backend
- DynamoDB locking

Esto da:

- State remoto (no local)
- Prevención de race conditions
- Integridad del estado
- Versionado del bucket (si lo habilitas)

Esto evita:

- Corrupción del state
- Conflictos simultáneos
- Drift accidental

### 4. Seguridad de red

La arquitectura incluye:

- VPC aislada por ambiente
- Subnets públicas y privadas
- EKS nodes en subnets privadas
- Internet Gateway controlado

Esto significa:

- Los nodos no están expuestos directamente a internet
- El acceso público está limitado
- Hay separación por entorno


## 2. ¿Cómo funciona este modelo de seguridad realmente?

El proyecto sigue este principio:

`Zero static credentials` + `Federated identity` + `Least privilege` + `Network isolation`

El flujo real es:

1. GitHub genera un token OIDC firmado
2. AWS valida el token
3. AWS STS genera credenciales temporales
4. Terraform usa esas credenciales
5. Las credenciales expiran automáticamente

---


