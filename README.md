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
| **Identity** | IAM roles (task execution role, scoped GitHub Actions OIDC roles) |
| **Observability** | CloudWatch Logs, CloudWatch dashboard (golden signals) |
| **State** | S3 remote backend with native S3 state locking |
| **CI/CD** | GitHub Actions with OIDC authentication to AWS |

---

## Code layout

| File | Contents |
|---|---|
| `providers.tf` | Terraform/provider config and S3 backend |
| `variables.tf` | Input variables (region, project name, VPC CIDR, image digest) |
| `outputs.tf` | ALB DNS name, cluster name, ECR URL |
| `network.tf` | VPC, subnets, gateways, NAT, route tables |
| `ecs.tf` | ECR data source, cluster, task definition, service |
| `iam.tf` | Task execution role, OIDC provider, scoped CI roles |
| `alb.tf` | Security groups, load balancer, target group, listener |
| `observability.tf` | CloudWatch log group and dashboard |

---

## Key design decisions

**Fargate over EC2.** The app runs on Fargate (serverless containers) rather than self-managed EC2 instances. This removes server management (patching, scaling, capacity) and keeps the focus on the infrastructure patterns, not on administering machines.

**ARM64 / Graviton.** The task runs on ARM64 (`runtime_platform`), matching the container image architecture and taking advantage of Graviton's lower cost.

**Native S3 state locking instead of DynamoDB.** Terraform's classic pattern uses a separate DynamoDB table for state locking. Terraform 1.10+ supports native S3 locking (`use_lockfile`), which removes the extra resource. The state bucket is also decoupled from the project's own lifecycle, so `terraform destroy` never attempts to delete its own backend.

**OIDC instead of static credentials for CI/CD.** The pipeline authenticates to AWS via GitHub's OIDC provider and short-lived credentials, rather than storing long-lived AWS access keys as GitHub secrets. Nothing reusable is stored anywhere.

**Two scoped CI roles, one per event.** Rather than a single admin role, CI uses two roles whose trust policies are bound to specific GitHub events via the `sub` claim:
- **`github-actions-plan`** — trusts only `pull_request` events, with `ReadOnlyAccess`. A pull request (including from a fork) can run `terraform plan` but cannot modify anything.
- **`github-actions-apply`** — trusts only pushes to `refs/heads/main`, with write permissions. Only a merge to `main` can deploy.

This closes the common OIDC pitfall where a role trusted with a wildcard `:*` sub is assumable (with broad permissions) from any pull request.

**Pinned image digest.** The task definition references the ECR image by digest rather than the mutable `:latest` tag, so a given Terraform state always deploys an identical image.

**Chained security groups.** The ALB's security group accepts traffic from the internet; the task's security group accepts traffic *only from the ALB's security group* (referenced by SG, not CIDR), so the container is never directly reachable from the internet.

---

## Observability

- **Logs:** the container's stdout/stderr ships to a CloudWatch log group (`/ecs/flagship-task`) with 7-day retention.
- **Dashboard:** a CloudWatch dashboard tracks the golden signals — ECS CPU/memory utilization (saturation), ALB request count (traffic), target response time (latency), HTTP 5xx count (errors), and healthy host count (availability).

---

## CI/CD pipeline

GitHub Actions (`.github/workflows/terraform.yml`), two jobs selected by event:

- On **pull request** to `main` → assumes `github-actions-plan`, runs `terraform fmt -check`, `validate`, and `plan`. Read-only review of the change.
- On **push** to `main` → assumes `github-actions-apply`, runs `terraform plan -out=tfplan` then `terraform apply tfplan` (applies exactly the plan it computed).
- A `concurrency` group prevents two pipeline runs from applying at the same time, complementing the S3 state lock.
- Authenticates to AWS through OIDC — no stored credentials.

---

## Cost note

The NAT gateway, ALB, and running Fargate task incur cost while deployed. For a learning project, run `terraform destroy` when not in use; the remote state and ECR image persist, so the environment can be recreated with a single `terraform apply`.

---

## Known limitations / next steps

- **Single NAT gateway.** One NAT gateway (in the AZ-b public subnet) serves both private subnets. This is a deliberate cost trade-off — a NAT per AZ would double the cost — but it is a single point of failure for outbound traffic: if that AZ fails, both private subnets lose egress. Production with uptime requirements would run one NAT per AZ.
- **Plan role uses `ReadOnlyAccess`.** The CI plan role can read most of the account (including object contents) to run `terraform plan`. A tighter setup would scope it to `describe`/`list` actions only, since a plan does not need to read data.
- **Apply role uses `PowerUserAccess` + `IAMFullAccess`.** Broad for convenience; a custom least-privilege policy scoped to this project's resources would be the next step. The IAM base layer could also be managed out-of-band so the app pipeline only references roles rather than managing them.
- **HTTP only.** The listener serves plain HTTP on port 80. Production would add an HTTPS listener (port 443) with an ACM certificate.
- **No distributed tracing.** Logs and metrics are in place; traces would matter once the system spans multiple services.

---

## Prerequisites

- AWS account with credentials configured locally (for the initial bootstrap of the CI roles)
- Terraform 1.10+
- A container image pushed to the ECR repository (`nginx-app`)
