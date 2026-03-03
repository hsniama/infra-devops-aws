# Flujos de Tráfico EKS - Explicación Detallada

---

## Respuestas a Dudas Específicas

### **1. ¿El ALB/NLB público va DENTRO de las subnets públicas?**

**SÍ, el Load Balancer público se crea FÍSICAMENTE dentro de las subnets públicas.**

```
┌─────────────────────────────────────────────────────┐
│  Subnet Pública 10.110.10.0/24                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────────────────────────────┐          │
│  │  NAT Gateway                          │          │
│  │  • IP Privada: 10.110.10.5            │          │
│  │  • Elastic IP: 54.123.45.67 (pública) │          │
│  └──────────────────────────────────────┘          │
│                                                      │
│  ┌──────────────────────────────────────┐          │
│  │  Application Load Balancer (ALB)      │          │
│  │  • ENI 1: 10.110.10.10                │          │
│  │  • ENI 2: 10.110.11.10 (otra AZ)      │          │
│  │  • DNS: a1b2c3.elb.amazonaws.com      │          │
│  └──────────────────────────────────────┘          │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Detalles técnicos:**
- El ALB/NLB crea **ENIs (Elastic Network Interfaces)** en cada subnet pública
- Cada ENI tiene una **IP privada** de la subnet (ej: 10.110.10.10)
- El DNS del Load Balancer resuelve a **IPs públicas** que AWS gestiona
- El Load Balancer está **físicamente** en las subnets públicas

---

### **2. ¿Se conecta el flujo a los nodos o al Managed Node Group?**

**El flujo se conecta DIRECTAMENTE a los PODS, NO a los nodos.**

```
Concepto IMPORTANTE:

Managed Node Group
    ↓
Es un GRUPO LÓGICO que gestiona múltiples nodos
    ↓
Cada nodo es una instancia EC2 individual
    ↓
Cada nodo ejecuta múltiples pods
    ↓
El Load Balancer enruta tráfico a los PODS (no a los nodos)
```

**Flujo real:**

```
ALB (10.110.10.10)
    │
    ├─ Target Group: IPs de pods
    │
    ├─ Target 1: 10.110.20.45 (Pod A en Node 1)
    ├─ Target 2: 10.110.20.67 (Pod B en Node 1)
    └─ Target 3: 10.110.21.89 (Pod C en Node 2)
```

**NO es así:**
```
❌ ALB → Node 1 → Pods
❌ ALB → Managed Node Group → Nodes → Pods
```

**Es así:**
```
✅ ALB → Pod A (directamente)
✅ ALB → Pod B (directamente)
✅ ALB → Pod C (directamente)
```

---

## 📊 Arquitectura Detallada con Ubicaciones Exactas

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    VPC TEST 10.110.0.0/16                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    [Internet Gateway]                           │    │
│  │                    • Punto de entrada/salida                    │    │
│  └──────────────────────┬─────────────────────────────────────────┘    │
│                         │                                               │
│         ┌───────────────┴───────────────┐                              │
│         │                               │                              │
│  ┌──────▼──────────────┐         ┌──────▼──────────────┐              │
│  │  AZ us-east-1a      │         │  AZ us-east-1b      │              │
│  ├─────────────────────┤         ├─────────────────────┤              │
│  │                     │         │                     │              │
│  │ PUBLIC SUBNET       │         │ PUBLIC SUBNET       │              │
│  │ 10.110.10.0/24      │         │ 10.110.11.0/24      │              │
│  │ ┌─────────────────┐ │         │ ┌─────────────────┐ │              │
│  │ │ NAT Gateway     │ │         │ │                 │ │              │
│  │ │ 10.110.10.5     │ │         │ │                 │ │              │
│  │ │ EIP: 54.x.x.x   │ │         │ │                 │ │              │
│  │ └─────────────────┘ │         │ └─────────────────┘ │              │
│  │                     │         │                     │              │
│  │ ┌─────────────────┐ │         │ ┌─────────────────┐ │              │
│  │ │ ALB (ENI)       │◄┼─────────┼─┤ ALB (ENI)       │ │              │
│  │ │ 10.110.10.10    │ │         │ │ 10.110.11.10    │ │              │
│  │ │ DNS: a1b2c3.elb │ │         │ │ (mismo ALB)     │ │              │
│  │ └────────┬────────┘ │         │ └────────┬────────┘ │              │
│  │          │          │         │          │          │              │
│  │          │          │         │          │          │              │
│  │ PRIVATE SUBNET     │         │ PRIVATE SUBNET      │              │
│  │ 10.110.20.0/24     │         │ 10.110.21.0/24      │              │
│  │ ┌─────────────────┐│         │ ┌─────────────────┐ │              │
│  │ │ Managed Node    ││         │ │ Managed Node    │ │              │
│  │ │ Group           ││         │ │ Group           │ │              │
│  │ │ ┌─────────────┐ ││         │ │ ┌─────────────┐ │ │              │
│  │ │ │ Worker Node1│ ││         │ │ │ Worker Node2│ │ │              │
│  │ │ │ 10.110.20.30│ ││         │ │ │ 10.110.21.40│ │ │              │
│  │ │ │             │ ││         │ │ │             │ │ │              │
│  │ │ │ ┌─────────┐ │ ││         │ │ │ ┌─────────┐ │ │ │              │
│  │ │ │ │ Pod A   │ │ ││         │ │ │ │ Pod C   │ │ │ │              │
│  │ │ │ │10.110.20│ │ ││         │ │ │ │10.110.21│ │ │ │              │
│  │ │ │ │   .45   │◄┼─┼┼─────────┼─┼─┼─┤   .89   │ │ │ │              │
│  │ │ │ └─────────┘ │ ││         │ │ │ └─────────┘ │ │ │              │
│  │ │ │             │ ││         │ │ │             │ │ │              │
│  │ │ │ ┌─────────┐ │ ││         │ │ │             │ │ │              │
│  │ │ │ │ Pod B   │ │ ││         │ │ │             │ │ │              │
│  │ │ │ │10.110.20│ │ ││         │ │ │             │ │ │              │
│  │ │ │ │   .67   │ │ ││         │ │ │             │ │ │              │
│  │ │ │ └─────────┘ │ ││         │ │ │             │ │ │              │
│  │ │ └─────────────┘ ││         │ │ └─────────────┘ │ │              │
│  │ └─────────────────┘│         │ └─────────────────┘ │              │
│  │          ▲          │         │          ▲          │              │
│  └──────────┼──────────┘         └──────────┼──────────┘              │
│             │                               │                         │
│             └───────────────┬───────────────┘                         │
│                             │                                         │
│                    ┌────────▼────────┐                                │
│                    │ Internal NLB    │                                │
│                    │ 10.110.20.100   │                                │
│                    │ (para servicios │                                │
│                    │  internos)      │                                │
│                    └─────────────────┘                                │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│  EKS Control Plane (Managed por AWS, fuera de tu VPC)                 │
│  • API Server: https://XXXXX.gr7.us-east-1.eks.amazonaws.com          │
│  • Scheduler, Controller Manager, etcd                                 │
└────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│  ECR Repository                                                        │
│  035462351040.dkr.ecr.us-east-1.amazonaws.com/ecrdevops1720test       │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Flujo 1: Usuario → Aplicación Pública

```
┌─────────────────────────────────────────────────────────────────┐
│  FLUJO: Usuario accede a aplicación web                         │
└─────────────────────────────────────────────────────────────────┘

1. Usuario en Internet
   └─ Navegador: http://a1b2c3.us-east-1.elb.amazonaws.com
       ↓
2. DNS resuelve a IPs públicas del ALB
   └─ 54.123.45.67, 54.123.45.68
       ↓
3. Tráfico llega a Internet Gateway
   └─ IGW recibe paquete con destino 54.123.45.67
       ↓
4. IGW enruta a ALB en subnet pública
   └─ ALB ENI: 10.110.10.10 (subnet pública)
       ↓
5. ALB consulta Target Group
   └─ Targets registrados:
       • 10.110.20.45 (Pod A) - healthy
       • 10.110.20.67 (Pod B) - healthy
       • 10.110.21.89 (Pod C) - healthy
       ↓
6. ALB selecciona un pod (round-robin)
   └─ Selecciona Pod A (10.110.20.45)
       ↓
7. ALB envía tráfico DIRECTAMENTE al Pod
   └─ Paquete: src=10.110.10.10, dst=10.110.20.45
       ↓
8. Paquete atraviesa de subnet pública a privada
   └─ Permitido por Security Groups y Route Tables
       ↓
9. Pod A recibe la petición
   └─ Contenedor nginx procesa HTTP request
       ↓
10. Pod A responde
    └─ Paquete: src=10.110.20.45, dst=10.110.10.10
        ↓
11. ALB recibe respuesta
    └─ ALB reenvía a usuario
        ↓
12. Usuario recibe HTML
```

**Puntos clave:**
- ✅ ALB está FÍSICAMENTE en subnets públicas
- ✅ ALB enruta DIRECTAMENTE a IPs de pods (no a nodos)
- ✅ El tráfico cruza de subnet pública a privada
- ✅ Security Groups permiten tráfico ALB → Pods

---

## 🔄 Flujo 2: Pod → Internet (Descargar imagen ECR)

```
┌─────────────────────────────────────────────────────────────────┐
│  FLUJO: Pod descarga imagen de Docker desde ECR                 │
└─────────────────────────────────────────────────────────────────┘

1. EKS Scheduler asigna pod a Node 1
   └─ Pod necesita imagen: 035462351040.dkr.ecr.us-east-1.amazonaws.com/app:latest
       ↓
2. Kubelet en Node 1 intenta descargar imagen
   └─ Container runtime (containerd) hace pull
       ↓
3. Pod genera tráfico saliente
   └─ src=10.110.20.45, dst=ECR (IP pública)
       ↓
4. Route Table de subnet privada
   └─ Destino: 0.0.0.0/0 → NAT Gateway (10.110.10.5)
       ↓
5. Tráfico llega a NAT Gateway (subnet pública)
   └─ NAT traduce IP privada → IP pública
       • src=10.110.20.45 → src=54.x.x.x (Elastic IP del NAT)
       • dst=ECR (sin cambios)
       ↓
6. NAT envía paquete a Internet Gateway
   └─ IGW enruta hacia Internet
       ↓
7. Tráfico llega a ECR
   └─ ECR valida autenticación (IAM role del node)
       ↓
8. ECR envía imagen de vuelta
   └─ dst=54.x.x.x (Elastic IP del NAT)
       ↓
9. IGW recibe respuesta
   └─ Enruta a NAT Gateway
       ↓
10. NAT Gateway traduce de vuelta
    └─ dst=54.x.x.x → dst=10.110.20.45 (IP del pod)
        ↓
11. Pod recibe imagen
    └─ Container runtime extrae y ejecuta imagen
```

**Puntos clave:**
- ✅ Pods en subnet privada NO tienen IP pública
- ✅ NAT Gateway traduce IP privada → pública
- ✅ NAT Gateway está en subnet pública
- ✅ Todo el tráfico saliente pasa por NAT

---

## 🔄 Flujo 3: EKS Control Plane → Managed Node Group

```
┌─────────────────────────────────────────────────────────────────┐
│  FLUJO: Control Plane gestiona nodos y programa pods            │
└─────────────────────────────────────────────────────────────────┘

1. Usuario ejecuta: kubectl apply -f deployment.yaml
   └─ kubectl envía petición a EKS API Server
       ↓
2. EKS API Server valida y guarda en etcd
   └─ Deployment: 3 replicas de nginx
       ↓
3. Controller Manager detecta cambio
   └─ Crea 3 ReplicaSets
       ↓
4. Scheduler busca nodos disponibles
   └─ Consulta recursos de cada nodo:
       • Node 1: 2 vCPU, 4GB RAM (50% usado)
       • Node 2: 2 vCPU, 4GB RAM (30% usado)
       ↓
5. Scheduler asigna pods a nodos
   └─ Pod A → Node 1
   └─ Pod B → Node 1
   └─ Pod C → Node 2
       ↓
6. API Server notifica a kubelet de cada nodo
   └─ Mensaje a Node 1: "Ejecuta Pod A y Pod B"
   └─ Mensaje a Node 2: "Ejecuta Pod C"
       ↓
7. Kubelet en Node 1 recibe instrucción
   └─ Descarga imagen de ECR (Flujo 2)
   └─ Crea contenedores
   └─ Asigna IPs a pods:
       • Pod A: 10.110.20.45
       • Pod B: 10.110.20.67
       ↓
8. Kubelet en Node 2 recibe instrucción
   └─ Descarga imagen de ECR
   └─ Crea contenedor
   └─ Asigna IP a pod:
       • Pod C: 10.110.21.89
       ↓
9. Pods reportan estado a API Server
   └─ Pod A: Running
   └─ Pod B: Running
   └─ Pod C: Running
       ↓
10. kubectl get pods muestra:
    NAME           READY   STATUS    IP
    nginx-xxx-a    1/1     Running   10.110.20.45
    nginx-xxx-b    1/1     Running   10.110.20.67
    nginx-xxx-c    1/1     Running   10.110.21.89
```

**Puntos clave:**
- ✅ Control Plane NO está en tu VPC
- ✅ Control Plane se comunica con nodos vía API Server endpoint
- ✅ Scheduler asigna pods a NODOS individuales
- ✅ Kubelet en cada nodo ejecuta los pods
- ✅ Managed Node Group es solo un grupo lógico de nodos

---

## 🔄 Flujo 4: Pod → Pod (Comunicación Interna)

```
┌─────────────────────────────────────────────────────────────────┐
│  FLUJO: Pod A necesita conectarse a base de datos (Pod C)       │
└─────────────────────────────────────────────────────────────────┘

Escenario: Tienes un Service interno para la base de datos

apiVersion: v1
kind: Service
metadata:
  name: database
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
spec:
  type: LoadBalancer
  selector:
    app: postgres
  ports:
  - port: 5432

1. Kubernetes crea Internal NLB
   └─ Busca subnets con "kubernetes.io/role/internal-elb" = "1"
   └─ Encuentra subnets privadas
   └─ Crea NLB con IP privada: 10.110.20.100
       ↓
2. Pod A necesita conectarse a database
   └─ DNS: database.default.svc.cluster.local
       ↓
3. CoreDNS resuelve a IP del Service
   └─ database.default.svc.cluster.local → 10.110.20.100 (NLB)
       ↓
4. Pod A envía tráfico a NLB
   └─ src=10.110.20.45, dst=10.110.20.100:5432
       ↓
5. Internal NLB recibe tráfico
   └─ Consulta Target Group:
       • 10.110.21.89 (Pod C - postgres) - healthy
       ↓
6. NLB enruta a Pod C
   └─ src=10.110.20.45, dst=10.110.21.89:5432
       ↓
7. Pod C (postgres) recibe conexión
   └─ Procesa query SQL
       ↓
8. Pod C responde
   └─ src=10.110.21.89, dst=10.110.20.45
       ↓
9. NLB reenvía respuesta a Pod A
   └─ Pod A recibe datos
```

**Puntos clave:**
- ✅ Internal NLB está en subnets PRIVADAS
- ✅ Solo accesible desde dentro de la VPC
- ✅ Pods se comunican vía IPs privadas
- ✅ No sale a Internet

---

## 🔄 Flujo 5: kubectl (Usuario) → EKS

```
┌─────────────────────────────────────────────────────────────────┐
│  FLUJO: Usuario ejecuta kubectl desde su laptop                 │
└─────────────────────────────────────────────────────────────────┘

1. Usuario ejecuta: kubectl get pods
   └─ kubectl lee ~/.kube/config
       ↓
2. kubectl encuentra configuración del cluster
   └─ server: https://XXXXX.gr7.us-east-1.eks.amazonaws.com
   └─ user: terraformUser (IAM)
       ↓
3. kubectl genera token de autenticación
   └─ Ejecuta: aws eks get-token --cluster-name eksdevops1720test
       ↓
4. AWS CLI usa credenciales de terraformUser
   └─ ~/.aws/credentials
       ↓
5. AWS STS valida identidad
   └─ sts:GetCallerIdentity
   └─ Respuesta: arn:aws:iam::035462351040:user/terraformUser
       ↓
6. AWS STS genera token temporal
   └─ Token válido por 15 minutos
       ↓
7. kubectl envía petición a EKS API Server
   └─ Headers:
       • Authorization: Bearer <token>
       • Host: XXXXX.gr7.us-east-1.eks.amazonaws.com
       ↓
8. EKS API Server valida token
   └─ Verifica firma con AWS STS
       ↓
9. EKS consulta Access Entry
   └─ ¿terraformUser tiene acceso?
   └─ Sí: AmazonEKSClusterAdminPolicy
       ↓
10. EKS ejecuta comando
    └─ Lista pods de todos los namespaces
        ↓
11. EKS responde con lista de pods
    └─ JSON con información de pods
        ↓
12. kubectl formatea y muestra
    NAME           READY   STATUS
    nginx-xxx-a    1/1     Running
    nginx-xxx-b    1/1     Running
    nginx-xxx-c    1/1     Running
```

**Puntos clave:**
- ✅ kubectl se conecta al endpoint público del API Server
- ✅ Autenticación vía IAM (no certificados)
- ✅ Access Entry define permisos en el cluster
- ✅ Token temporal (15 min), no credenciales estáticas

---

## 📊 Resumen de Conexiones

### **Load Balancer Público (ALB/NLB)**
```
Ubicación: Subnets PÚBLICAS (10.110.10.0/24, 10.110.11.0/24)
Conexión: Internet → IGW → ALB → Pods (IPs privadas)
Target: IPs de PODS directamente (no nodos)
```

### **Load Balancer Interno (NLB)**
```
Ubicación: Subnets PRIVADAS (10.110.20.0/24, 10.110.21.0/24)
Conexión: Pod → Internal NLB → Pod
Target: IPs de PODS directamente
```

### **Managed Node Group**
```
Concepto: Grupo LÓGICO de nodos EC2
Ubicación: Nodos están en subnets PRIVADAS
Conexión: Control Plane → Nodos individuales → Pods
Flujo de tráfico: ALB NO se conecta al Managed Node Group
                  ALB se conecta DIRECTAMENTE a los pods
```

### **NAT Gateway**
```
Ubicación: Subnet PÚBLICA (10.110.10.0/24)
Conexión: Pods → NAT → IGW → Internet (ECR, updates, etc)
Propósito: Permitir salida a Internet desde subnets privadas
```

---

## 🎯 Diagrama Generado

Ver: `generated-diagrams/diagram_56548df5.png`

Este diagrama muestra:
- ✅ Ubicación exacta de Load Balancers en subnets públicas
- ✅ Managed Node Group como contenedor de nodos
- ✅ Flujos de tráfico con colores diferentes
- ✅ Conexiones directas ALB → Pods (no a nodos)
- ✅ Comunicación interna vía NLB
- ✅ Salida a Internet vía NAT Gateway
