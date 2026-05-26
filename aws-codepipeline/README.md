# AWS CodePipeline 6-Stage Demo

Hands-on demo of an AWS-native CI/CD pipeline using **GitHub → CodeBuild → CodeDeploy → CodePipeline** on **EC2** with **Terraform** as IaC. Deploys the Flask app at `../application/src/app.py` to a staging ASG (in-place) and a production ASG behind an ALB (in-place rolling with traffic control).

## Stages mapping

| # | Stage          | AWS service           | What happens                                                                   |
|---|----------------|-----------------------|--------------------------------------------------------------------------------|
| 1 | **Source**     | GitHub (CodeConnections) | `git push` to GitHub triggers the pipeline via webhook                       |
| 2 | **Build**      | CodeBuild             | `pytest application/tests` (unit tests) + packages deploy zip → artifact bucket |
| 3 | **Test**       | CodeBuild             | Static / contract checks (`python -m compileall`, `pip check`, schema asserts)  |
| 4 | **Staging**    | CodeDeploy (IN_PLACE) | Deploy to staging ASG (1 × t3.micro). Lifecycle hooks install deps + systemd start |
| 5 | **IntegrationTest** | CodeBuild        | Resolves staging instance IP, curls `/healthz`, `/readyz`, `/`. Fails on non-200 |
| 6 | **Production** | Manual approval → CodeDeploy (IN_PLACE with traffic control) | Human gate, then rolling deploy on the prod ASG, draining + re-registering via the ALB target group |

> **Why Test runs both before and after Staging?** Pre-deploy "Test" (stage 3) catches issues without spinning up infrastructure — fast and cheap. Post-deploy "IntegrationTest" (stage 5) catches issues only visible against a running service — config drift, missing env vars, network misroutes. Real teams do both.

> **⚠ Manual step required:** After `terraform apply`, the GitHub CodeConnection is `PENDING`. Open AWS Console → Developer Tools → Settings → Connections → `cicd-evo-github` → **Update pending connection** → authorize via GitHub OAuth. Pipeline will not trigger until status is `AVAILABLE`.

> **Why in-place instead of Blue/Green for prod?** Terraform AWS provider 5.x rejects the `target_group_pair_info` block needed for ALB-based Blue/Green (`InvalidLoadBalancerInfoException`). The in-place + traffic-control pattern still demonstrates: ALB target group draining, lifecycle hook deploys, auto-rollback on validate failure.

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
cd aws-codepipeline/terraform

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

# (8) verify prod once in-place rolling finishes
ALB=$(terraform output -raw prod_alb_dns)
curl "http://$ALB/"

# (9) teardown
BUCKET=$(terraform output -raw artifacts_bucket)
aws s3 rm "s3://$BUCKET" --recursive
terraform destroy -auto-approve
```

## What gets created

~30 resources in the existing VPC: 4 IAM roles · 1 S3 artifacts bucket · 1 CodeConnections connection (GitHub) · 3 CodeBuild projects · 2 EC2 launch templates · 2 Auto Scaling Groups (staging=1, prod=2) · 1 ALB + 1 target group · 1 listener · 3 security groups · 1 CodeDeploy application + 2 deployment groups · 1 CodePipeline.

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
