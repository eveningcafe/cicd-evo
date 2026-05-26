provider "aws" {
  region = var.region

  default_tags {
    tags = merge(
      {
        Project   = var.project_name
        ManagedBy = "terraform"
        Demo      = "aws-codepipeline-6-stage"
      },
      var.tags,
    )
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Latest Amazon Linux 2023 AMI via SSM (no hardcoded IDs that go stale).
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  ami_id     = data.aws_ssm_parameter.al2023.value
  name       = var.project_name
}
