Disponible en [Español](#glosario-y-conceptos-técnicos)

---

## Technical Concepts & Glossary

This section explains the core concepts and technologies used in this project, providing architectural and security context.

### 🔐 Identity & Security Concepts
- **IAM (Identity and Access Management)**  
  AWS service that manages identities (users, roles) and permissions for resources.
- **IAM User**  
  Permanent identity associated with a person or system, with static credentials (access keys).
- **IAM Role**  
  Entity that defines a set of permissions and can be temporarily assumed by users or services.
- **AssumeRole (STS)**  
  Process by which an identity requests temporary credentials to use an IAM Role.
- **STS (Security Token Service)**  
  AWS service that issues temporary credentials for secure resource access.
- **STS Temporary Credentials**  
  Short-lived credentials generated dynamically (Access Key, Secret Access Key, Session Token).
- **OIDC (OpenID Connect)**  
  Authentication protocol based on OAuth 2.0 that enables identity federation.
- **OIDC Federated Role**  
  IAM Role configured to trust an external provider (e.g., GitHub) via OIDC tokens.
- **GitHub OIDC Provider**  
  Identity provider configured in AWS that allows GitHub Actions to authenticate without static keys.
- **Least Privilege Principle**  
  Security principle where each entity receives only the permissions strictly necessary.
- **Trust Policy**  
  IAM policy that defines who can assume a role.
- **Permission Policy**  
  IAM policy that defines what actions a role or user can perform.

### 🚀 CI/CD & Automation Concepts
- **GitHub Actions** → CI/CD automation platform integrated into GitHub.  
- **Workflow** → YAML file that defines automation steps.  
- **Runner** → Environment where workflows are executed.  
- **Terraform Plan** → Command that shows the changes to be applied.  
- **Terraform Apply** → Command that executes the changes defined in the plan.  
- **Artifact** → File generated during a workflow and stored for later use.  
- **Environment Protection Rules** → Manual approval rules before running critical jobs (e.g., production).

### 🏗 Infrastructure as Code (IaC)
- **Terraform** → IaC tool used to provision AWS resources.  
- **Provider** → Plugin that allows Terraform to interact with a service (e.g., AWS provider).  
- **Module** → Reusable unit of Terraform configuration.  
- **Backend** → Configuration that defines where Terraform state is stored.  
- **Remote State** → State stored remotely (e.g., S3).  
- **State Locking** → Mechanism that prevents concurrent Terraform executions (DynamoDB).

### ☁️ AWS Infrastructure Components
- **VPC (Virtual Private Cloud)** → Isolated virtual network within AWS.  
- **Public Subnet** → Subnet with direct Internet access.  
- **Private Subnet** → Subnet without direct Internet access.  
- **Internet Gateway (IGW)** → Enables communication between the VPC and the Internet.  
- **NAT Gateway** → Allows private subnets to access the Internet without being directly reachable.  
- **Route Table** → Defines how traffic is routed within the VPC.

### ☸️ Kubernetes & EKS
- **EKS (Elastic Kubernetes Service)** → Managed Kubernetes service in AWS.  
- **Control Plane** → AWS-managed component that controls the Kubernetes cluster.  
- **Managed Node Group** → EC2 nodes automatically managed by AWS.  
- **Worker Nodes** → EC2 instances running containers.  
- **EKS Access Entry** → New mechanism for IAM-based cluster access without manual aws-auth configmap.  
- **Kubernetes Pod** → Smallest deployable unit in Kubernetes.

### 📦 Containerization
- **Docker** → Platform for building and running containers.  
- **Container Image** → Immutable template containing application and dependencies.  
- **ECR (Elastic Container Registry)** → Private Docker image repository in AWS.

### 💾 State & Storage
- **S3 (Simple Storage Service)** → Storage service used to hold Terraform remote state.  
- **DynamoDB** → NoSQL database used for Terraform state locking.  
- **tfstate** → File representing the current state of managed infrastructure.

### 🌎 Multi-Environment Architecture
- **Environment Isolation** → Separation of resources by environment (test, prod).  
- **Workspace Separation** → Logical separation of Terraform configurations per environment.  
- **Bootstrap Infrastructure** → Initial infrastructure created to support remote Terraform (S3 + DynamoDB).

---

## Glosario y Conceptos Técnicos

La siguiente sección explica los conceptos y tecnologías clave utilizados en este proyecto, proporcionando contexto arquitectónico y de seguridad.

### 🔐 Identity & Security Concepts
- **IAM (Identity and Access Management)**  
  Servicio de AWS que permite gestionar identidades (usuarios, roles) y permisos sobre recursos.
- **IAM User**  
  Identidad permanente asociada a una persona o sistema, con credenciales estáticas (access keys).
- **IAM Role**  
  Entidad que define un conjunto de permisos y que puede ser asumida temporalmente por usuarios o servicios.
- **AssumeRole (STS)**  
  Proceso mediante el cual una identidad solicita credenciales temporales para usar un IAM Role.
- **STS (Security Token Service)**  
  Servicio de AWS que emite credenciales temporales para acceso seguro a recursos.
- **STS Temporary Credentials**  
  Credenciales de corta duración generadas dinámicamente (Access Key, Secret Access Key, Session Token).
- **OIDC (OpenID Connect)**  
  Protocolo de autenticación basado en OAuth 2.0 que permite federación de identidades.
- **OIDC Federated Role**  
  Rol IAM configurado para confiar en un proveedor externo (ej. GitHub) mediante tokens OIDC.
- **GitHub OIDC Provider**  
  Proveedor de identidad configurado en AWS que permite a GitHub Actions autenticarse sin claves estáticas.
- **Least Privilege Principle**  
  Principio de seguridad donde cada entidad recibe únicamente los permisos estrictamente necesarios.
- **Trust Policy**  
  Política IAM que define quién puede asumir un rol.
- **Permission Policy**  
  Política IAM que define qué acciones puede realizar un rol o usuario.

### 🚀 CI/CD & Automation Concepts
- **GitHub Actions** → Plataforma de automatización CI/CD integrada en GitHub.  
- **Workflow** → Archivo YAML que define los pasos de automatización.  
- **Runner** → Entorno donde se ejecutan los workflows.  
- **Terraform Plan** → Comando que muestra los cambios que serán aplicados.  
- **Terraform Apply** → Comando que ejecuta los cambios definidos en el plan.  
- **Artifact** → Archivo generado durante un workflow y almacenado para uso posterior.  
- **Environment Protection Rules** → Reglas de aprobación manual antes de jobs críticos (ej. producción).

### 🏗 Infrastructure as Code (IaC)
- **Terraform** → Herramienta IaC utilizada para provisionar recursos en AWS.  
- **Provider** → Plugin que permite a Terraform interactuar con un servicio (ej. AWS provider).  
- **Module** → Unidad reutilizable de configuración Terraform.  
- **Backend** → Configuración que define dónde se almacena el estado.  
- **Remote State** → Estado almacenado remotamente (S3).  
- **State Locking** → Mecanismo que evita ejecuciones concurrentes (DynamoDB).

### ☁️ AWS Infrastructure Components
- **VPC (Virtual Private Cloud)** → Red virtual aislada dentro de AWS.  
- **Public Subnet** → Subnet con acceso directo a Internet.  
- **Private Subnet** → Subnet sin acceso directo a Internet.  
- **Internet Gateway (IGW)** → Comunicación entre VPC e Internet.  
- **NAT Gateway** → Permite a subnets privadas acceder a Internet.  
- **Route Table** → Define cómo se enruta el tráfico dentro de la VPC.

### ☸️ Kubernetes & EKS
- **EKS (Elastic Kubernetes Service)** → Servicio administrado de Kubernetes en AWS.  
- **Control Plane** → Componente administrado por AWS que gestiona el cluster.  
- **Managed Node Group** → Nodos EC2 administrados automáticamente.  
- **Worker Nodes** → Instancias EC2 donde corren los contenedores.  
- **EKS Access Entry** → Nuevo mecanismo para gestionar acceso IAM al cluster.  
- **Kubernetes Pod** → Unidad mínima desplegable en Kubernetes.

### 📦 Containerization
- **Docker** → Plataforma para crear y ejecutar contenedores.  
- **Container Image** → Plantilla inmutable con aplicación y dependencias.  
- **ECR (Elastic Container Registry)** → Repositorio privado de imágenes Docker.

### 💾 State & Storage
- **S3 (Simple Storage Service)** → Almacenamiento del estado remoto de Terraform.  
- **DynamoDB** → Base de datos NoSQL usada para state locking.  
- **tfstate** → Archivo que representa el estado actual de la infraestructura.

### 🌎 Multi-Environment Architecture
- **Environment Isolation** → Separación de recursos por ambiente (test, prod).  
- **Workspace Separation** → Separación lógica de configuraciones Terraform.  
- **Bootstrap Infrastructure** → Infra inicial creada para soportar Terraform remoto (S3 + DynamoDB).
