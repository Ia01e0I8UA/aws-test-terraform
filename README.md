# AWS Infrastructure — Containerized App on ECS Fargate (Terraform)

Production-style AWS infrastructure provisioned entirely as code with Terraform, running a containerized application on ECS Fargate behind an Application Load Balancer, with centralized observability and a GitHub Actions CI/CD pipeline that authenticates to AWS via OIDC (no long-lived credentials).

This is a portfolio project: the goal is to demonstrate the full lifecycle of cloud infrastructure — network, compute, access, identity, observability, and automated delivery — built to common production patterns.

---

## Architecture

```
                    Internet
                       │
                       ▼
            ┌──────────────────────┐
            │  Application Load     │   public subnets (2 AZs)
            │  Balancer (HTTP :80)  │
            └──────────┬───────────┘
                       │  forwards to target group
                       ▼
            ┌──────────────────────┐
            │  ECS Fargate task     │   private subnets (2 AZs)
            │  (nginx container)    │
            └──────────┬───────────┘
                       │  outbound only
                       ▼
                   NAT Gateway ──► Internet Gateway ──► pulls image from ECR
```

- **Multi-AZ** across `eu-west-1a` and `eu-west-1b` for availability.
- The **load balancer** sits in public subnets and is the only internet-facing entry point.
- The **application** runs in private subnets, unreachable directly from the internet — only the ALB can reach it (enforced by chained security groups).
- The task reaches **ECR** (outside the VPC) through the NAT gateway for image pulls.

---

## Stack

| Layer | Services |
|---|---|
| **Network** | VPC, public/private subnets (2 AZs), Internet Gateway, NAT Gateway, route tables |
| **Compute** | ECS Fargate, ECR (container registry) |
| **Access** | Application Load Balancer, target group, listener, security groups |
| **Identity** | IAM roles (task execution role, GitHub Actions OIDC role) |
| **Observability** | CloudWatch Logs, CloudWatch dashboard (golden signals) |
| **State** | S3 remote backend with native S3 state locking |
| **CI/CD** | GitHub Actions with OIDC authentication to AWS |

---

## Key design decisions

**Fargate over EC2.** The app runs on Fargate (serverless containers) rather than self-managed EC2 instances. This removes server management (patching, scaling, capacity) and keeps the focus on the infrastructure patterns, not on administering machines.

**ARM64 / Graviton.** The task runs on ARM64 (`runtime_platform`), matching the container image architecture and taking advantage of Graviton's lower cost.

**Native S3 state locking instead of DynamoDB.** Terraform's classic pattern uses a separate DynamoDB table for state locking. Terraform 1.10+ supports native S3 locking (`use_lockfile`), which removes the extra resource. The state bucket is also decoupled from the project's own lifecycle, so `terraform destroy` never attempts to delete its own backend.

**OIDC instead of static credentials for CI/CD.** The pipeline authenticates to AWS via GitHub's OIDC provider and short-lived credentials, rather than storing long-lived AWS access keys as GitHub secrets. Nothing reusable is stored anywhere; the trust is scoped to this specific repository via the `sub` claim condition.

**Least-privilege-ish IAM for CI.** The GitHub Actions role uses `PowerUserAccess` + IAM permissions rather than full `AdministratorAccess`, limiting what a compromised pipeline could touch. (See "Known limitations" for the next step.)

**Chained security groups.** The ALB's security group accepts traffic from the internet; the task's security group accepts traffic *only from the ALB's security group* (referenced by SG, not CIDR), so the container is never directly reachable from the internet.

---

## Observability

- **Logs:** the container's stdout/stderr ships to a CloudWatch log group (`/ecs/flagship-task`) with 7-day retention.
- **Dashboard:** a CloudWatch dashboard tracks the golden signals — ECS CPU/memory utilization (saturation), ALB request count (traffic), target response time (latency), HTTP 5xx count (errors), and healthy host count (availability).

---

## CI/CD pipeline

GitHub Actions (`.github/workflows/terraform.yml`):

- On **pull request** to `main` → `terraform plan` (review the change before merging).
- On **push** to `main` → `terraform apply` (deploy).
- Authenticates to AWS through OIDC — no stored credentials.

---

## Cost note

The NAT gateway, ALB, and running Fargate task incur cost while deployed. For a learning project, run `terraform destroy` when not in use; the remote state and ECR image persist, so the environment can be recreated with a single `terraform apply`.

---

## Known limitations / next steps

- **HTTP only.** The listener serves plain HTTP on port 80. Production would add an HTTPS listener (port 443) with an ACM certificate.
- **CI/CD runs `apply` automatically on merge** with `-auto-approve`. A stricter setup would require manual approval before apply.
- **IAM for CI could be tightened** from `PowerUserAccess` + `IAMFullAccess` to a custom least-privilege policy scoped to the project's resources.
- **IAM could be separated** into a privileged base layer (managed out-of-band) that the app pipeline only references, rather than managing IAM roles itself.
- **No distributed tracing.** Logs and metrics are in place; traces would matter once the system spans multiple services.

---

## Prerequisites

- AWS account with credentials configured locally (for the initial bootstrap)
- Terraform 1.10+
- A container image pushed to the ECR repository (`nginx-app`)
