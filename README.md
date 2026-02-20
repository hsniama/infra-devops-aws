# Repo: infra-devops-aws (Terraform + GitHub Actions + AWS + OIDC)

## Repositorio - `infra-devops-aws` 

Este repositorio aprovisiona la infraestructura requerida para cualquier aplicación o microservicio y contiene lo siguiente:

- Usuario IAM con Policies para deplesgar Infraestructura
- VPCs personalizadas con Subnets públicas (Load Balancers) y privadas (EKS Nodes)
- Nat Gateway con EIP y Route tables.
- Amazon ECR (Elastic Container Registry)
- Amazon EKS (Elastic Kubernetes Service) con Managed Node Group
- IAM Role para GitHub Actions (OIDC)
- Acceso al cluster vía EKS Access Entries habilitado con authentication_mode = "API_AND_CONFIG_MAP"
- Estado remoto de Terraform en S3
- Locking del estado con DynamoDB
- CI/CD: GitHub Actions + OIDC

## Infraestructura en AWS

- **Región**: `us-east-1` 
- **Backend remoto de Terraform**
  - S3 para state: `tfstate-devops-henry-1720` 
    ![S3 Bucket para state](./assets/img/7.png)
    - keys (states separados por ambiente dentro del mismo backend)
      - `dev/infra.tfstate`
      - `prod/infra.tfstate`
  - DynamoDB para locking: `tfstate-locks-devops`
    ![S3 Bucket para state](./assets/img/7.1.png)

- **Infraestructura dev**:
  - vpc_name: `devops-aws-test-vpc`
    ![VPC subnets test](./assets/img/10.png)
    - Elastic Kubernetes Service (EKS): `eksdevops1720test`
      ![EKS Test](./assets/img/17.png)
    - Elastic Container Registry (ECR): `devops-microservice-test`

- **Infraestructura prod**:
  - vpc_name: `devops-aws-test-vpc`
    ![VPC subnets prod](./assets/img/11.png)
    - Elastic Kubernetes Service (EKS): `eksdevops1720test`
      ![EKS Prod](./assets/img/16.png)
    - Elastic Container Registry (ECR): `devops-microservice-test`

En resumen:

- VPC dedicada por ambiente
  ![VPCs](./assets/img/9.png) 
  - Subnets
  - Route Tables
  - Internet Gateways
- EKS Cluster por ambiente v1.32
  ![EKS por ambiente](./assets/img/13.png)
- ECR repositorios por ambiente para imagenes Docker
  ![Private Repositories](./assets/img/12.png)

## Costos estimados 
- **EKS Control Plane**: ~$0.10 por hora
- **EC2 Nodes**: mínimo 2 nodos y dependen del tipo de instancia: `BOTTLEROCKET_x86_64` *(no tan económico)* 
- **ECR**: bajo costo (almacenamiento por GB)
- **S3 + DynamoDB**: mínimo costo

![Análisis de Costos](./assets/img/13.png)

## Entornos

Se tiene 2 entornos para este proyecto:

- **DEV**: cualquier push a ramas `dev/**`: despliega en DEV, es decir, deploy automático sin aprobación manual.
- **PROD**: merge a `main` despliega en PROD y requiere aprobación manual en GitHub Environment.

El estado remoto de Terraform usa llaves separadas pero mismo S3 Bucket:

- `dev/infra.tfstate`

    Actualizar imagen
   ![Llave en DEV definida en el archivo backends/dev.hcl](./assets/img/7.png)
    Ir al archivo [backends/dev.hcl](./backends/dev.hcl)

- `prod/infra.tfstate`

    Actualizar imagen
   ![Llave en PROD definida en el archivo backends/prod.hcl](./assets/img/8.png)
    Ir al archivo [backends/prod.hcl](./backends/prod.hcl)

## Setup del proyecto

**0. Clonar el repo:**
```bash
git clone https://github.com/hsniama/infra-devops-aws
cd infra-devops-aws
```
**1. Configurar AWS CLI**
```bash
aws configure
```
Se te pedirá ingresar los siguientes valores:
- `AWS Access Key ID` → <tu clave>
- `AWS Secret Access Key` → <tu clave secreta>
- `Default region name` → us-east-1
- `Default output son` → json


Verificar identidad:
```bash
aws sts get-caller-identity
```
Nota Importante:

1. Antes de configurar tu cuenta con `aws configure` y después validarla con `aws sts get-caller-identity`, primero debes/debías crear una nueva cuenta por el IAM de AWS y obtener el AccessKeyID y el SecretAccessKey.
2. Una ves hallas creado tu cuenta/usuario en IAM y hayas terminado de configurararlo y validar su identidad, hay dos opciones muy importantes a considerar:
  a. **Usuario IAM con AdministratorAccess** *(Recomendado)*: Adjunta/Enlaza manualmente la política `AdministratorAccess` del tipo "AWS managed" al usuario recién creado en IAM para tener acceso total a servicios y recursos en AWS sin límite. 
  b. **Usuario IAM con Managed Policies**: Se adjunta políticas del tipo "customer managed" con permisos exactos para lo que se necesita en este proyecto reduciendo así el riesgo de dar permisos de más. Esta configuración personalizada se lo realiza en el siguiente archivo de [Configuración del Usuario](./assets/Readmes/ConfigUser.md).

**2. Crear Backend remoto (S3 + DynamoDB)**
Ejecutar el script `bootstrap_backend.sh`:
```bash
chmod +x scripts/bootstrap_backend.sh
scripts/bootstrap_backend.sh <region> <bucket_name> <dynamodb_table>
```
Ejemplo:
```bash
./scripts/bootstrap_backend.sh us-east-1 tfstate-devops-henry-1720 tfstate-locks-devops
```
En donde <region> es la región de AWS en la cual estamos trabajando, <bucket_name> es el nombre completo del bucket a crear, y <dynamodb_table> es el nombre de la tabla de dynamodb.

Este script crea:
- S3 bucket para state
- DynamoDB table para locking
- Keys para ambientes test y prod

  ![Bucket Creado](./assets/img/7.png)

Guardar los valores generados de *bucket*, *key*, *region*, y *dynamodb_table* y colocarlos en los archivos:
- `backends/dev.hcl`
- `backends/dev.hcl`

**3. Crear IAM Role para OIDC (GitHub Actions)**
Ejecutar el script `bootstrap-oidc.sh`:
```bash
chmod +x scripts/bootstrap_oidc.sh
./scripts/bootstrap_oidc.sh <account_id> <repo_full_name> <role_name> <region>
```
Ejemplo:
```bash
./scripts/bootstrap_oidc.sh 035462351040 hsniama/infra-devops-aws gh-oidc-terraform-infra-devops-aws us-east-1
```
En donde <account_id> es el ID de tu cuenta, <repo_full_name> es el nombre completo de tu repositorio de GitHub, <role_name> es el nombre del rol que asignamos, puede ser el mismo y <region> es la región de AWS en la cual estamos trabajando.

Este script crea:

- IAM Role: `gh-oidc-terraform-infra-devops-aws`
- Trust policy con GitHub OIDC
- Permisos suficientes para:
  - EKS
  - ECR
  - VPC
  - S3
  - IAM
  - DynamoDB

Resultado de la ejecución del script:

```json
DONE.
Set this GitHub secret in infra-devops-aws repo:
AWS_ROLE_TO_ASSUME = arn:aws:iam::0354623XXXXX:role/gh-oidc-terraform-infra-devops-aws
```
Se debe guardar el ARN generado `AWS_ROLE_TO_ASSUME` como GitHub secret en tu repositorio el cual se detalla más adelante.

En conclusión, se tendrá el rol `gh-oidc-terraform-infra-devops-aws` con el policy `gh-oidc-terraform-infra-devops-aws-policy` enlazado.

  ![Rol Creado](./assets/img/8.png)

Para comprender la función de este script, dirigirse al [Anexo](./assets/Readmes/Anexos.md).

**4. Configuración de GitHub Environments**

Se crea los environments en el repo > settings > Environments:
- `dev` 
- `prod`: Se activa el "Required reviewers" para que prod no aplique sin aprobación.

![Configuración de los 2 Environments.](./assets/img/19.png)

En el caso del ambiente de `prod`, en *Required reviewers* me pongo a mi mismo:

![Required Reviewer](./assets/img/20.png)

**5. Crear Secrets y Variables en GitHub**

Crear el siguiente Secret (obtenido en la ejecución del script `bootstrap-oidc.sh`) con su respectivo valor en repo > settings > secrets & variables > actions > secrets:

![Configuración de secrets](./assets/img/21.png)

En mi caso:
- `AWS_ROLE_TO_ASSUME` → arn:aws:iam::03546XXXX:role/gh-oidc-terraform-infra-devops-aws

El workflow `terraform.yml` de GitHub Actions, usa este rol (AWS_ROLE_TO_ASSUME) con OIDC para obtener credenciales temporales en AWS.

Ahora, se debe crear la siguiente variable en Actions > Variables:

![Configuración de secrets](./assets/img/21.png)

En mi caso:
- `AWS_REGION` → us-east-1

**6. Setear variables de Terraform**

Se debe especificar los valores de las siguientes variables que deben ser únicas a nivel global en AWS:

- eks_name
- ecr_repo_name
- principal_arn del Usuario IAM creado en los primeros pasos (Se obtiene ejecutando el comando aws sts get-caller-identity)
- principal_arn del del role OIDC de GitHub Actions (Es el resultado de la ejecución del script `bootstrap-oidc.sh` en el paso 3 )

Para `DEV` modificar las variables en el archivo `enviroments/dev.tfvars`:
![Configuración de variables.](./assets/img/23.png)
Para `PROD` modificar las variables en el archivo `enviroments/prod.tfvars`:
![Configuración de variables.](./assets/img/24.png)

Las demás variables como `node_instance_types`, `node_ami_type` así como el resto, son opcionales.

## Ejecución del Pipeline

**Workflow: terraform.yml**

Este pipeline ésta ubicado en la ruta [.github/workflows/terraform.yml](./.github/workflows/terraform.yml) y está diseñado para manejar los despliegues de la infraestructura en AWS con Terraform + GitHub Actions, diferenciando entre ambientes de test y prod según el evento que lo dispare. 

El workflow se ejecuta en formas distintas:

Para el ambiente de `TEST`:

1. Push a ramas dev/**
- Corre plan + apply en el ambiente test despues del `git commit -m ""` y `git push`.
- Permite validar cambios en el entorno de prueba sin afectar producción.

Para el ambiente de `PROD`:

1. Pull Request hacia main
- Corre el `Terraform plan` en modo prod.
- Sirve para revisar qué cambios se aplicarían en producción antes de hacer el merge.
- No ejecuta apply, solo muestra el plan.

2. Merge a main
- Corre plan + apply en ambiente prod una vez se aprueba el merge en el PR.
- Despliega la infraestructura real en producción.

---

Nota:
Con el fín de validar y analizar de forma breve nuestra infraestructura sin la necesidad de hacer cambios, commits, pushes, abrir y aprobar PRs, se agregó la facilidad de correr este workflow de forma manual (workflow_dispatch) para desplegar la infraestrctura tanto en el ambiente de `TEST` como `PROD` lo cual:

- Permite lanzar el workflow desde la interfaz de GitHub Actions.
- Tiene un input environment con opciones test o prod para elegir el ambiente a desplegar.
- Es útil para pruebas y despliegues controlados.

Nos dirigimos a Actions > Workflows > terraform.yml > Run Workflow  y escoger la rama `Branch: dev/henry` para desplegar en `TEST` o la rama `Branch: main`  para desplegar en `PROD`. Finalmente, presionar en Run Workflow  y el pipeline se ejecutará.

![Run Workflow](./assets/img/25.png)

Recuerda, que en el caso de correr en PROD, el pipeline se ejecuta pero necesita un *approval* del reviewer que fue configurado en el ambiente de prod en GitHub Environments.

![Run Workflow with approve](./assets/img/26.png)


Para más detalles de como funciona este workflow y que contiene, dirígete al [Anexo](./assets/Readmes/Anexos.md).

## Outputs y Artifacts

Después de que el pipeline finalice correctamente, revisar el step:

**Terraform output**

Valores obtenidos y necesarios:

- aws_region
- ecr_repository_name
- ecr_repository_url
- eks_cluster_name
- eks_cluster_endpoint
- eks_oidc_issuer

![Outputs](./assets/img/27.png)

Estos serán usados por el repo de microservicios para:
- docker build
- docker push a ECR
- aws eks update-kubeconfig
- kubectl apply

Es decir, los outputs suficientes:

- Cluster name y endpoint → para conectar kubectl.
- ECR repo URL → para subir y referenciar imágenes.
- OIDC issuer → útil si configuramos IRSA (roles para service accounts).

También, al concluir la ejecución del pipeline, se obtienen los siguientes artifacts que GitHub Actions guarda como resultado de los jobs:
- terraform-plan-logs-prod/test → Archivo de log (terraform.log) generado durante el plan. Sirve para depuración: si algo falla o quieres revisar qué recursos se iban a crear/modificar, puedes abrir este log.
- terraform-apply-logs-prod/test → Archivo de log (terraform.log) generado durante el apply. Registra todo lo que Terraform hizo efectivamente en AWS. Es la evidencia del despligue.
- tfplan-prod/test → Contiene el plan exacto que generó Terraform (terraform plan). Se usa como input en el job apply para garantizar que se aplique exactamente lo que se revisó en el plan.

![Artifacts](./assets/img/28).

## Conexión al Cluster

Una vez ejecutado correctamente el workflow *terraformn.yml*, ya es posible conectarse al cluster mediante el siguiente comando:
```bash
aws eks update-kubeconfig --region <REGION> --name <CLUSTER_NAME>
```
En donde:
- <REGION> → es la regió que habías configurado al inicio.
- <CLUSTER_NAME> → es el nombre del eks_name configurado en los archivos .tfvars

Ejemplo:
```bash
aws eks update-kubeconfig --region us-east-1 --name eksdevops1720test

kubectl get nodes
```
El acceso está habilitado mediante EKS Access Entries en donde podemos listar todos los Access Entries configurados en nuestro cluster EKS con el siguiente comando:

```bash
aws eks list-access-entries --cluster-name <CLUSTER_NAME> --region <REGION>
```
Nota:
- Un Access Entry es el vínculo entre un principal de IAM (usuario o rol) y las políticas de acceso al cluster (ej. admin, readonly). El resultado te muestra cada ARN que tiene acceso al cluster y qué policies están asociadas. Es como decir: “Muéstrame todos los usuarios/roles que tienen permisos en este cluster”.

Una vez ya conectados al cluster ya se puede construir y subir la imagen al ECR Repositorio usando el output *ECR Repo URL* del pipeline:

Por ejemplo:
```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin <ECR_REPO_URL>

docker build -t devops-microservice-test .
docker tag devops-microservice-test:latest \
  <ECR_REPO_URL>/devops-microservice-test:latest

docker push <ECR_REPO_URL>/devops-microservice-test:latest
```
En donde:
- <ECR_REPO_URL> puede ser `035462531040.dkr.ecr.us-east-1.amazonaws.com`

También ya podríamos crear y exponer manifiestos y servicios de kubernetes para exponerlo dentro del cluster, etc., mediante otro pipeline en otro repositorio (repo de la aplicación).

## Limpieza
Estos dos workflows sirven para hacer limpieza de la infraestructura.

Si desea eliminar la infraestructura en `TEST`, ejecuto manualmente el workflow `destroy-infra-test.yml`.
Si desea eliminar la infraestructura en `PROD`, ejecuto manualmente el workflow `destroy-infra-prod.yml`. Sin embargo, aquí requiero un *approval* del reviewer.


## Conclusión
En este proyecto:

- No se necesita Access Keys en GitHub.
- GitHub Actions obtiene credenciales temporales vía OIDC y permite que se autentique en AWS sin usar llaves estáticas.
- Terraform puede desplegar infraestructura en AWS (de acuerdo a los requisítos de este proyecto) de forma segura y automatizada.
- El usuario terraformUser (en mi caso) tiene permisos mínimos para crear el OIDC, sin ser administrador, gracias a las policy previamente añadidas.
