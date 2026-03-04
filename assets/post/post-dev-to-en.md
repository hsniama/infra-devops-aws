## The Discovery

A few months ago, while talking with a DevOps Engineer friend, he shared one of his frustrations:

*"In some of the companies and projects I've worked on, I've had to build all the infrastructure: VPCs, subnets, EKS... plus set up the deployment pipeline, both for the platform and the microservice. But as a DevOps Engineer, what I really want is to focus on deploying the microservice. My dream would be to simply run kubectl apply... and have everything work.*"

That's when it became clear: the DevOps Engineer ends up fighting with VPCs and subnets when they should really be focusing on automating application deployments.

**That reflection changed everything.**

---

## The Missing Separation of Responsibilities

This project was born precisely to solve that clash of responsibilities.

We assume the role of **Cloud/Platform Engineer** and build the base infrastructure shell so that the DevOps/App Delivery team can then deploy applications on an already prepared platform.

In our approach:
- **Cloud/Platform Engineering (this repository)** builds the foundation: network, infrastructure, identity, remote state, cluster, registry, and infrastructure pipeline.
- **DevOps/App Delivery (application repository, later)** consumes outputs from this foundation to deploy microservices with speed and less risk.

It's not bureaucracy. It's organizational and technical design for scaling. As a **Cloud/Platform Engineer**, my job isn't for every DevOps Engineer to recreate infrastructure. My job is to **build the platform once** and have them consume it.


![Roles diff](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/juydh55nx19my656q0g8.png)

---

## What I Built

I decided to materialize this vision in a real project:

**A complete, reusable, and open source AWS platform.**

![AWS Architecture](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/dn6ee9clbnomjdjqavac.png)
_See full diagram on_ [GitHub](https://github.com/hsniama/infra-devops-aws/blob/dev/henry/assets/diagrams/aws/aws_infrastructure_diagram.png)

As you can see, we take responsibility for preparing the complete infrastructure shell so that a DevOps/App team can then focus on deploying product, not fighting with base infrastructure.

Specifically, we leave ready:
- AWS networks separated by environment (`test` and `prod`).
- EKS clusters per environment.
- ECR repositories per environment for images.
- Secure authentication via OIDC in GitHub Actions.
- Terraform remote state with locking.
- Infrastructure CI/CD with clear rules per environment.

We're not trying to "do everything in one repo". We're trying to collaborate better: platform on one side, applications on the other, with a clear contract between both.

## Technologies we use to build this foundation

- **AWS**: VPC, EKS, ECR, IAM, S3, DynamoDB
- **Terraform**: to build AWS resources with reusable modules
- **GitHub Actions**: to run the infrastructure pipeline per environment
- **OIDC**: Federated authentication without static Access Keys
- **EKS Access Entries**: to control who enters the cluster without relying only on manual configurations

---

## The 4 Pillars That Make the Difference

### 1. Environment Separation (For Real)

Most say "we have TEST and PROD separated" but they share a VPC.

**I went further:**

- **TEST** → VPC `10.110.0.0/16` 
- **PROD** → VPC `10.111.0.0/16` 


![VPCs](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/cshg89c8v5blfz74jwjd.png)

- **Completely independent** Terraform states per environment and separate variables per tfvars.

![Terraform States](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/agd9j7mprx2fd9ypdcl3.png)

- The pipeline dynamically selects backend and variables based on the branch, avoiding collisions between environments and **zero shared resources**.


![Pipeline](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/1jq48r0jx0lbigbtiv73.png)

**Why?**

Because on a Friday at 6 PM, someone is going to make a change in TEST. And if they share resources, PROD goes down.

**With this separation, I can destroy/modify TEST without fear.** That peace of mind is priceless.

---

### 2. OIDC: The Security Innovation That Changes Everything

Here's the gem of the project. 
**The problem everyone has:** 
- AWS credentials stored in **GitHub Secrets** 
- Example: 
   - `AWS_ACCESS_KEY_ID: AKIAXXXXX` 
   - `AWS_SECRET_ACCESS_KEY: xxxxx` 

If someone commits those keys; it's a **disaster**

**My solution: OIDC**

![OIDC-Flow](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/ir0agcmskthbjb3ux49k.png)

No static keys in GitHub.

This directly improves:
- Operational security.
- Credential expiration.
- Control via trust policy.
- Reduced attack surface.
- Zero permanent credentials: **Zero risk**.

And the best part: the Trust Policy ensures that **only my repository** can assume the role.

---

### 3. Outputs: The Bridge Between Platform and Applications

This is where the separation of roles comes to life.
The platform doesn't deliver "raw infrastructure", but ready-to-use outputs:

| Output        | Example                                         |
|---------------|-------------------------------------------------|
| **ECR_URL**   | 123456.dkr.ecr.us-east-1.amazonaws.com/app      |
| **EKS_CLUSTER** | eksdevops1720testXX                           |
| **EKS_ENDPOINT** | https://XXXXX.eks.amazonaws.com              |
| **REGION**    | us-east-1                                       |

![Outputs](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/8k7ubu95tcnbokxpyf2b.png)
_See Outputs on_ [GitHub](https://github.com/hsniama/infra-devops-aws/actions/runs/22232310474/job/64315042012)

How the DevOps Engineer consumes them in their repo (pipeline):

```yaml
# Pipeline that leverages platform outputs
docker push $ECR_URL/mi-app:latest
aws eks update-kubeconfig --name $EKS_CLUSTER
kubectl apply -f k8s/
```
Direct console example:
```bash
aws eks update-kubeconfig --name eksdevops1720testXX
kubectl apply -f deployment.yaml
# and it works... No additional configuration.
```

**That's it.**

The DevOps Engineer,
- Doesn't need to deeply understand how the VPC is configured.  
- Doesn't need to fully understand route tables.  
- Doesn't need to be an expert in EKS cluster setup.

**They only need to deploy their application** on the previously deployed platform.

---

### 4. Intelligent Pipeline: Fast in TEST, Safe in PROD

![Ci-Cd](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/u8nsnhlyf2chgp0hdec0.png)

I designed the pipeline thinking about **speed vs control**: 
**TEST (Speed)** 
- `git push origin dev/**`. 
- Terraform deploys automatically. 
- No approvals. 
- Feedback in ~15 minutes. 

**PROD (Control)** 
- Pull Request to `main`.
- Terraform plan (team review). 
- Mandatory manual approval - Merge → deployment

**What's innovative:**
- OIDC authentication (no keys).
- Remote state with locking (no conflicts).
- Saved artifacts (easy rollback).
- Approvals only where they matter.

This enables clean deployments with valuable artifacts:

![Pipeline](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/hppaul3q6dw8dozfni52.png)

---

## Cluster Access: EKS Access Entries

AWS launched something revolutionary: **Access Entries**. Instead of manually editing ConfigMaps, you can now define Cluster access directly in Terraform:

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

**What changes with Access Entries?**

1. **AWS-managed** - No more manual ConfigMaps.
2. **Native IAM integration** - Roles and users directly in AWS.
3. **Automatic validation** - Terraform validates before applying.
4. **Complete audit** - CloudTrail logs every action.

**What it means in practice**

When a DevOps Engineer needs cluster access, I simply:
- Add their IAM role in Terraform (in our case, in the module).
- Run `terraform apply`
- Done: They have immediate cluster access.

EKS Clusters:

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/2tx2yvotentiyuvmpxaj.png)

Cluster Access (as DevOps Engineer):
![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/i1rmcb57grncl7n4ed6a.png)

List of configured EKS Access Entries (example):
![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/dw3bkz3o6zfv8pwvahli.png)

This is what we implemented in the project. Where the separation of responsibilities comes into action:
- I as Cloud/Platform Engineer manage WHO has access.
- They use that access to deploy.
- Nobody touches ConfigMaps without risk of breaking anything.
- Everything versioned in Git.

---

## Real Scope of This Project

This repository doesn't deploy microservices directly. Its purpose is to **build the solid foundation** for that to happen well later.

It also doesn't include yet:
- complete workload observability,
- app ingress/controller,
- application layer autoscaling.

What it does:
- Defines networks, clusters, repositories (ECR), and infrastructure pipeline.
- Publishes ready-to-use outputs for other repos to deploy applications.
- Establishes modern security (OIDC, temporary IAM roles).

What it doesn't include (by design):
- Complete workload observability
- Application ingress/controller
- Application layer autoscaling

This is not an accidental gap.
It's a conscious scope decision:

- The base platform ensures security and governance.
- Application delivery is managed in separate repos.
- Separation of responsibilities avoids friction and chaotic scaling.

## Considerations Before Using in Production

This foundation is solid, but for real production it's worth reinforcing:

- **Observability**: EKS control plane logs, metrics, and alerts.
- **EKS endpoint hardening**: restrict `public_access_cidrs` or private-only endpoint in prod.
- **More granular IAM**: reduce broad permissions and lock down to specific resources.
- **CI security**: IaC/policy/image checks.
- **Workload autoscaling**: HPA + Cluster Autoscaler/Karpenter.
- **HA/cost architecture**: evaluate NAT per AZ based on RTO/RPO and budget.

---

## Who This Platform Is For

### If You're a Cloud/Platform Engineer:
- Use it as a foundation for your organization or projects.
- Adapt the modules to your needs.
- Contribute improvements to the project.

### If You're a DevOps Engineer:
- Use it as a reference for what you need.
- Focus on deploying applications, not infrastructure.

---

## What's Next

This platform is the **starting point**, not the final destination.

**Next evolutions:**
- Multi-region (disaster recovery)
- Service Mesh (advanced observability)
- GitOps (ArgoCD/FluxCD)
- Security policies (OPA)

**But the fundamentals are already here:**
- Separation of responsibilities
- Security by design
- Real automation
- Reusability

**And it's ready to use today.**

---

## Repository

Everything is documented, tested, and with steps to build and deploy:

📦 **Repository:** [github.com/hsniama/infra-devops-aws](https://github.com/hsniama/infra-devops-aws)


**Clone. Adapt. Deploy. Contribute. **

---

## Open Source and Collaboration

If you're interested in this line of work, you can collaborate with ideas or PRs:

- IAM hardening per resource.
- End-to-end observability.
- Policy-as-code in pipeline.
- Blueprint of the application repo that consumes outputs.

Remember that **The best platform is built together.**

---

## Final Reflection

The best automation isn't the one that does more things. It's the one that better defines responsibilities and reduces systemic risk.

This project is about that: as a platform team, first designing the right shell so that deploying applications later is simpler, safer, and more repeatable.

---

- ⭐ Give it a star on GitHub  
- 🔄 Share with your team  
- 💬 Leave me your comments  
- 🤝 Contribute to the project  

**Let's build better platforms, together.**

---

Tags: AWS, Terraform, PlatformEngineering, DevOps, CloudArchitecture, OpenSource, OIDC, Kubernetes, AWS, Cloud

---

- **Author:** Henry Niama  
- **Role:** Systems Engineer  
- **GitHub:** [@hsniama](https://github.com/hsniama/infra-devops-aws)  
- **LinkedIn:** [Henry Niama](https://linkedin.com/in/hsniama)
