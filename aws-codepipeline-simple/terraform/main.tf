provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Demo      = "aws-codepipeline-simple"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  name       = var.project_name
  account_id = data.aws_caller_identity.current.account_id
  ami_id     = data.aws_ssm_parameter.al2023.value
}
