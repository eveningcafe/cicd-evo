# Everything pipeline-flavored: GitHub connection, CodeBuild, CodeDeploy, the
# CodePipeline itself.

# --- Source ---
resource "aws_codestarconnections_connection" "github" {
  name          = "${local.name}-github"
  provider_type = "GitHub"
}

# --- Build ---
resource "aws_codebuild_project" "build" {
  name         = "${local.name}-build"
  service_role = aws_iam_role.codebuild.arn

  artifacts { type = "CODEPIPELINE" }
  source {
    type      = "CODEPIPELINE"
    buildspec = "aws-codepipeline-simple/buildspec.yml"
  }
  environment {
    type         = "LINUX_CONTAINER"
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
  }
  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${local.name}-build"
    }
  }
}

# --- Deploy ---
resource "aws_codedeploy_app" "main" {
  name             = local.name
  compute_platform = "Server"
}

# Tag-based deployment group: any running EC2 with these tags is a target.
# Much simpler than ASG-based — no lifecycle hook, no replacement story.
resource "aws_codedeploy_deployment_group" "main" {
  app_name              = aws_codedeploy_app.main.name
  deployment_group_name = "${local.name}-dg"
  service_role_arn      = aws_iam_role.codedeploy.arn

  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Project"
      value = local.name
      type  = "KEY_AND_VALUE"
    }
  }

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

# --- Pipeline ---
resource "aws_codepipeline" "main" {
  name     = local.name
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.id
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.github_repo
        BranchName       = var.branch_name
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["BuildArtifact"]
      configuration = {
        ApplicationName     = aws_codedeploy_app.main.name
        DeploymentGroupName = aws_codedeploy_deployment_group.main.deployment_group_name
      }
    }
  }
}
