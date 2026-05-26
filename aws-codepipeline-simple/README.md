# AWS CodePipeline — Minimal 3-Stage Demo

The simplest possible pipeline that still uses all 3 AWS CI/CD services:

```
              git push                 webhook
   GitHub ─────────────► CodePipeline ─────────► CodeBuild ──► CodeDeploy ──► 1 × EC2
                          (3 stages)              (build.zip)   (in-place)     gunicorn :8080
```

No ALB, no ASG, no Blue/Green, no staging/prod split, no manual approval, no integration test. Just **Source → Build → Deploy**. ~12 AWS resources total.

For the full production-style demo (6 stages, ALB, ASG×2, traffic control, manual approval, integration tests in VPC), see `../aws-codepipeline-full/`.

## What it deploys

| # | Stage  | Service              | What runs |
|---|--------|----------------------|-----------|
| 1 | Source | GitHub via CodeConnections | `git push` to `main` triggers via webhook |
| 2 | Build  | CodeBuild            | `pytest`, then zip `app/` + appspec + scripts → S3 artifact |
| 3 | Deploy | CodeDeploy           | In-place to **one EC2 instance** matched by tag `Project=cicd-evo-simple` |

## Resources created (~12)

- 1 × **EC2 t3.micro** in a public subnet (so you can `curl` it directly)
- 1 × Security group (ingress :8080 from 0.0.0.0/0)
- 1 × Instance profile + IAM role (SSM + S3 read for artifacts)
- 1 × **CodeBuild project**
- 1 × **CodeDeploy app + 1 deployment group** (targets by tag, no ASG)
- 1 × **CodePipeline** (3 stages)
- 1 × **CodeConnections** to GitHub (manual authorize once)
- 1 × S3 artifacts bucket (versioned, encrypted)
- 3 × IAM roles (CodeBuild, CodeDeploy, CodePipeline)

## Prerequisites

- AWS CLI v2 configured, Terraform ≥ 1.5, `git`
- A GitHub repo with this code already pushed (`eveningcafe/cicd-evo` by default)
- A **public subnet** in your AWS account (route table → IGW). The complex demo's `terraform/01_network.tf` shows how to find one; this demo just expects you to provide the subnet ID.

## Run order (manual)

```bash
cd aws-codepipeline-simple/terraform

cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars                  # set region, subnet_id, github_repo

terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Authorize the GitHub connection (one-time)
open "$(terraform output -raw connection_console_url)"
# → "Update pending connection" → GitHub OAuth → Authorize

# Trigger the pipeline (or just `git push` to main)
aws codepipeline start-pipeline-execution \
  --name $(terraform output -raw pipeline_name) \
  --region $(terraform output -raw region)

# Watch
aws codepipeline get-pipeline-state \
  --name $(terraform output -raw pipeline_name) \
  --region $(terraform output -raw region) \
  --query 'stageStates[].{Stage:stageName,Status:latestExecution.status}' --output table

# Verify once Deploy stage succeeds
IP=$(terraform output -raw instance_public_ip)
curl http://$IP:8080/healthz
curl http://$IP:8080/
```

## Teardown

```bash
BUCKET=$(terraform output -raw artifacts_bucket)
aws s3 rm "s3://$BUCKET" --recursive
terraform destroy -auto-approve
```

## What this teaches vs. what it skips

| Demo teaches                                       | Skipped (see full demo) |
|----------------------------------------------------|------------------------|
| GitHub source via CodeConnections + webhook        | Multi-environment (staging/prod) |
| CodeBuild buildspec phases + S3 artifact handoff   | Manual approval gates  |
| CodeDeploy AppSpec + lifecycle hooks on EC2        | ALB target-group draining / traffic control |
| Pipeline IAM `iam:PassRole` patterns               | CodeBuild VPC mode (ENI per build) |
| Tag-based deployment targeting                     | ASG auto-replacement + COPY_AUTO_SCALING_GROUP |

Files:

- `buildspec.yml` — single CodeBuild spec
- `appspec.yml` — CodeDeploy lifecycle for EC2
- `scripts/install.sh` — install dependencies + start gunicorn
- `scripts/validate.sh` — curl localhost:8080/healthz
- `terraform/` — ~5 .tf files, ~150 lines total
