# AWS CodePipeline Full Demo (6 stages)

Hands-on demo of an AWS-native CI/CD pipeline using **GitHub → CodeBuild → CodeDeploy → CodePipeline** on **EC2** with **Terraform** as IaC. Deploys the Flask app at `../application/src/app.py` to a staging ASG (in-place) and a production ASG behind an ALB (**Blue/Green** via target-group swap).

## System architecture

### Pipeline flow

```
              ┌──────────┐  git push
              │  GitHub  │ ─────────────┐
              │ eveningcafe/cicd-evo    │ webhook (CodeConnections)
              └──────────┘              ▼
                              ┌───────────────────────┐
                              │   CodePipeline        │  orchestrates the 6 stages
                              │   cicd-evo            │  artifacts → S3 (versioned)
                              └─────────┬─────────────┘
                                        │
   ┌─────────────┬───────────────┬──────┴────────┬──────────────────┬────────────────┐
   ▼             ▼               ▼               ▼                  ▼                ▼
 1.Source     2.Build         3.Test          4.Staging       5.IntegrationTest  6.Production
 GitHub       CodeBuild       CodeBuild       CodeDeploy       CodeBuild         ManualApproval
 (Source)     build.yml       contract-       deploy-group     integration-       + CodeDeploy
              pytest +        test.yml        "staging"        test.yml           deploy-group
              package zip     pip check,      IN_PLACE         curl staging       "prod"
                              compileall      to staging       /healthz,/        IN_PLACE w/
                                              ASG (1x)         (in-VPC)          BLUE_GREEN
                                                                                 over ALB
                                                                                 (blue↔green TG)
```

### Runtime topology (after deploy)

```
   Internet
       │
       │ :80
       ▼
┌────────────────────────────────────────────────────────────────────────┐
│ VPC vpc-036b914bdf14d227e   (172.31.0.0/16, existing default VPC)      │
│                                                                        │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                 ALB cicd-evo-prod  (internet-facing)            │  │
│   │   listener :80  →  target-group "blue" :8080                    │  │
│   │   SG: cicd-evo-alb  (ingress :80 from 0.0.0.0/0)                │  │
│   └────────┬─────────────────────────┬──────────────────────────────┘  │
│            │                         │                                 │
│   ┌────────▼──────────┐    ┌─────────▼──────────┐                      │
│   │  subnet 1a (priv) │    │  subnet 1b (priv)  │  NAT egress only     │
│   │  172.31.64.0/20   │    │  172.31.16.0/20    │  (no ingress from    │
│   │                   │    │                    │   internet to EC2)   │
│   │  ┌─────────────┐  │    │  ┌──────────────┐  │                      │
│   │  │ prod EC2    │  │    │  │ prod EC2     │  │  ASG cicd-evo-prod   │
│   │  │ t3.micro    │  │    │  │ t3.micro     │  │  desired=2           │
│   │  │ gunicorn    │  │    │  │ gunicorn     │  │                      │
│   │  │ :8080       │  │    │  │ :8080        │  │  SG: prod-app        │
│   │  │ + CD agent  │  │    │  │ + CD agent   │  │  (only ALB SG can    │
│   │  └─────────────┘  │    │  └──────────────┘  │   hit :8080)         │
│   │                   │    │                    │                      │
│   │  ┌─────────────┐  │    │                    │                      │
│   │  │ staging EC2 │  │    │                    │  ASG cicd-evo-       │
│   │  │ t3.micro    │  │    │                    │  staging desired=1   │
│   │  │ gunicorn    │  │    │                    │                      │
│   │  │ :8080       │  │    │                    │  SG: staging-app     │
│   │  │ + CD agent  │  │    │                    │  (only codebuild SG  │
│   │  └─────────────┘  │    │                    │   can hit :8080)     │
│   │                   │    │                    │                      │
│   │  ┌─────────────┐  │    │  ┌──────────────┐  │  CodeBuild           │
│   │  │ CodeBuild   │  │    │  │ CodeBuild    │  │  integration-test    │
│   │  │ ENI (temp)  │  │    │  │ ENI (temp)   │  │  ENI created during  │
│   │  │ SG:codebuild│  │    │  │ SG:codebuild │  │  build, deleted after│
│   │  └─────────────┘  │    │  └──────────────┘  │                      │
│   └───────────────────┘    └────────────────────┘                      │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

Out-of-VPC (region-scoped) AWS services:

  ┌──────────────────┐     ┌─────────────────────┐     ┌─────────────────┐
  │  CodePipeline    │     │ CodeBuild           │     │ CodeDeploy      │
  │  cicd-evo        │     │ build / contract /  │     │ app: cicd-evo   │
  │                  │     │ integration         │     │ DG: staging,    │
  └──────────────────┘     └─────────────────────┘     │     prod        │
                                                       └─────────────────┘

  ┌──────────────────┐     ┌─────────────────────┐     ┌─────────────────┐
  │ S3 artifacts     │     │ CodeConnections     │     │ IAM roles (5):  │
  │ bucket (versioned│     │ "cicd-evo-github"   │     │ pipeline, build,│
  │ + encrypted)     │     │ → eveningcafe/...   │     │ deploy, ec2,    │
  └──────────────────┘     └─────────────────────┘     │ events          │
                                                       └─────────────────┘
```

### Resources currently deployed (Terraform state)

| Layer       | Resource                                                          | Count |
|-------------|-------------------------------------------------------------------|-------|
| Network     | VPC / subnets *(reused, not created)*                             | —     |
|             | Security groups (`alb`, `prod_app`, `staging_app`, `codebuild`)   | 4     |
| Source      | `aws_codestarconnections_connection` (GitHub)                     | 1     |
| Pipeline    | `aws_codepipeline` (6 stages)                                     | 1     |
| Build       | `aws_codebuild_project` × (build, contract-test, integration-test)| 3     |
| Deploy      | `aws_codedeploy_app` + 2 deployment groups (staging, prod)        | 1 + 2 |
| Compute     | `aws_launch_template` × (staging, prod)                           | 2     |
|             | `aws_autoscaling_group` (staging=1 instance, prod=2 instances)    | 2     |
|             | `aws_lb` + listener + target group "blue"                         | 1+1+1 |
| Artifacts   | `aws_s3_bucket` + versioning + encryption + public-block          | 1     |
| IAM         | Roles: pipeline, codebuild, codedeploy, ec2-instance, +policies   | 4     |
| **Total**   |                                                                   | **~30** |

## Stages mapping

| # | Stage          | AWS service           | What happens                                                                   |
|---|----------------|-----------------------|--------------------------------------------------------------------------------|
| 1 | **Source**     | GitHub (CodeConnections) | `git push` to GitHub triggers the pipeline via webhook                       |
| 2 | **Build**      | CodeBuild             | `pytest application/tests` (unit tests) + packages deploy zip → artifact bucket |
| 3 | **Test**       | CodeBuild             | Static / contract checks (`python -m compileall`, `pip check`, schema asserts)  |
| 4 | **Staging**    | CodeDeploy (IN_PLACE) | Deploy to staging ASG (1 × t3.micro). Lifecycle hooks install deps + systemd start |
| 5 | **IntegrationTest** | CodeBuild        | Resolves staging instance IP, curls `/healthz`, `/readyz`, `/`. Fails on non-200 |
| 6 | **Production** | Manual approval → CodeDeploy (BLUE_GREEN over ALB) | Human gate, then CodeDeploy launches a green ASG from the same launch template, validates, flips ALB listener blue → green, terminates blue after 5 min |

> **Why Test runs both before and after Staging?** Pre-deploy "Test" (stage 3) catches issues without spinning up infrastructure — fast and cheap. Post-deploy "IntegrationTest" (stage 5) catches issues only visible against a running service — config drift, missing env vars, network misroutes. Real teams do both.

> **⚠ Manual step required:** After `terraform apply`, the GitHub CodeConnection is `PENDING`. Open AWS Console → Developer Tools → Settings → Connections → `cicd-evo-github` → **Update pending connection** → authorize via GitHub OAuth. Pipeline will not trigger until status is `AVAILABLE`.

> **Blue/Green via CLI workaround:** Terraform AWS provider 5.x has a serialization bug for `load_balancer_info { target_group_pair_info }` on Blue/Green deployment groups — the AWS API returns `InvalidLoadBalancerInfoException`. The fix in `terraform/08_deploy_codedeploy.tf` is to create the DG without `load_balancer_info` then patch it with `aws deploy update-deployment-group` in a `null_resource`. From there on, Blue/Green works normally (CodeDeploy spins up a green ASG, validates, flips the listener).

## Prerequisites

- AWS account with admin-ish IAM rights
- AWS CLI v2 configured (`aws sts get-caller-identity` works)
- Terraform ≥ 1.5, `git`, `jq`, `curl`
- A **GitHub repo** to host the source (this demo uses `eveningcafe/cicd-evo`)
- **An existing VPC + ≥2 subnets in different AZs** — the demo does NOT create its own network. Provide the IDs in `terraform.tfvars`.

## Required Terraform variables

Edit `terraform/terraform.tfvars`:

```hcl
region        = "ap-southeast-1"
project_name  = "cicd-evo"
instance_type = "t3.micro"

vpc_id     = "vpc-xxxxxxxx"
subnet_ids = [
  "subnet-aaaaaaaa",
  "subnet-bbbbbbbb",
]

github_repo = "your-org/your-repo"
branch_name = "main"
```

The subnets must already route to an Internet Gateway (the default VPC's subnets do). Public IP is auto-assigned by the launch template, so subnets that have `MapPublicIpOnLaunch=false` still work.

## Run order (manual, learn-by-doing)

Convenience scripts under `scripts/` exist, but the steps below are the underlying commands. Run them by hand to see what each tool does.

```bash
cd aws-codepipeline-full/terraform

# (1) sanity
aws sts get-caller-identity
terraform -version

# (2) init + plan + apply  (~5–7 min)
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# (3) AUTHORIZE the GitHub connection (one-time, manual)
#     Open the URL printed below and click "Update pending connection",
#     then complete the GitHub OAuth flow.
echo "AWS Console → Developer Tools → Settings → Connections → $(terraform output -raw github_connection_arn | awk -F/ '{print $NF}')"
aws codeconnections get-connection --connection-arn "$(terraform output -raw github_connection_arn)" --region "$(terraform output -raw region)" --query 'Connection.ConnectionStatus' --output text
# Re-run the get-connection call until it prints AVAILABLE.

# (4) push code to GitHub — triggers the pipeline
(cd ../.. && git push origin main)

# (5) watch the pipeline (re-run as often as you like)
PIPELINE=$(terraform output -raw pipeline_name)
REGION=$(terraform output -raw region)
aws codepipeline get-pipeline-state --name "$PIPELINE" --region "$REGION" \
  --query 'stageStates[].{Stage:stageName,Status:latestExecution.status}' --output table

# (6) verify staging once stage 4 succeeds
IP=$(aws ec2 describe-instances --region "$REGION" \
  --filters 'Name=tag:Environment,Values=staging' 'Name=instance-state-name,Values=running' \
  --query 'Reservations[].Instances[0].PublicIpAddress' --output text)
curl "http://$IP:8080/healthz"

# (7) approve production when stage 6 waits
TOKEN=$(aws codepipeline get-pipeline-state --name "$PIPELINE" --region "$REGION" \
  --query "stageStates[?stageName=='Production'].actionStates[?actionName=='ApproveProd'].latestExecution.token | [0][0]" \
  --output text)
aws codepipeline put-approval-result --pipeline-name "$PIPELINE" --region "$REGION" \
  --stage-name Production --action-name ApproveProd \
  --token "$TOKEN" --result summary=ok,status=Approved

# (8) verify prod once Blue/Green finishes (~5–8 min)
ALB=$(terraform output -raw prod_alb_dns)
curl "http://$ALB/"

# (9) teardown
BUCKET=$(terraform output -raw artifacts_bucket)
aws s3 rm "s3://$BUCKET" --recursive
terraform destroy -auto-approve
```

## What gets created

~32 resources in the existing VPC: 4 IAM roles · 1 S3 artifacts bucket · 1 CodeConnections connection (GitHub) · 3 CodeBuild projects · 2 EC2 launch templates · 2 Auto Scaling Groups (staging=1, prod=2; CodeDeploy clones the prod ASG at deploy time for green) · 1 ALB + 2 target groups (blue, green) · 1 listener · 4 security groups · 1 CodeDeploy application + 2 deployment groups · 1 CodePipeline · 1 null_resource (Blue/Green CLI patch).

> No VPC/subnets/IGW are created — those are reused from your existing network.

## Cost estimate

Running 24/7: ~$25/month (mostly ALB at ~$16 and t3.micros at ~$8). Running for a 1-hour demo and then destroying: under $1.

The pipeline itself is free (CodeCommit free tier covers 5 users, CodeBuild has 100 free min/mo on `general1.small`, CodePipeline has 1 free pipeline/mo).

## Rollback demo

After a successful production deploy, edit `application/src/app.py` so `/healthz` returns 500. `git push origin main`. CodeDeploy's `ValidateService` hook on the staging stage fails; pipeline halts; previous version stays live. If the failure reaches prod, `auto_rollback_configuration` on the prod deployment group rolls back to the previous revision automatically.

## What this does NOT cover

- Containers (ECR / ECS / Fargate). See `application/ci-providers/codebuild/buildspec.yml` for the container path.
- Vault / Secrets Manager. See `../secrets-examples/`.
- Multi-region / multi-account.
- Lambda traffic shifting / Argo Rollouts-style automated canary.

For the corresponding research write-up, see `../README.md` (Phần I–VII).

## Files

- `buildspecs/` — three CodeBuild buildspec files (`build`, `contract-test`, `integration-test`)
- `appspec/` — CodeDeploy `appspec.yml` + lifecycle hook scripts + systemd unit
- `terraform/` — IaC (`*.tf` + `user-data.sh` + `terraform.tfvars.example`)
- `scripts/` — optional convenience wrappers; the README's run order shows the raw commands instead
