# Three CodeBuild projects, one per Build/Test/IntegrationTest stage.
# All share the same IAM role; buildspec files differ.

locals {
  codebuild_image = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
}

# --- Stage 2: Build ---
resource "aws_codebuild_project" "build" {
  name          = "${local.name}-build"
  description   = "Stage 2: unit tests + package deploy bundle"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = local.codebuild_image
    privileged_mode = false
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "aws-codepipeline-full/buildspecs/build.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${local.name}-build"
    }
  }
}

# --- Stage 3: Test (contract / static) ---
resource "aws_codebuild_project" "contract_test" {
  name          = "${local.name}-contract-test"
  description   = "Stage 3: static + contract checks against the build artifact"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 10

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type         = "LINUX_CONTAINER"
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = local.codebuild_image
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "contract-test.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${local.name}-contract-test"
    }
  }
}

# --- Stage 5: IntegrationTest (post-staging) ---
# Runs inside the VPC (private ENI) so it can reach staging on its private IP.
# The subnets are private (NAT egress only) — perfect for CodeBuild's outbound
# needs (pull image from internet via NAT) without exposing the staging app.
resource "aws_codebuild_project" "integration_test" {
  name          = "${local.name}-integration-test"
  description   = "Stage 5: HTTP checks against deployed staging instance"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type         = "LINUX_CONTAINER"
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = local.codebuild_image

    environment_variable {
      name  = "PROJECT_NAME"
      value = local.name
    }
    environment_variable {
      name  = "STAGING_PORT"
      value = "8080"
    }
  }

  vpc_config {
    vpc_id             = data.aws_vpc.main.id
    subnets            = local.effective_codebuild_subnet_ids
    security_group_ids = [aws_security_group.codebuild.id]
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "integration-test.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${local.name}-integration-test"
    }
  }
}
