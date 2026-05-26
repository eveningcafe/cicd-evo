# The 6-stage pipeline.
# Source -> Build -> Test (contract) -> Staging (deploy) -> IntegrationTest -> Production (approval + Blue/Green deploy)
#
# CodeStarSourceConnection registers a webhook on the GitHub repo so each push
# triggers the pipeline. DetectChanges=true enables that.

resource "aws_codepipeline" "main" {
  name     = local.name
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.id
    type     = "S3"
  }

  # === Stage 1: Source ===
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

  # === Stage 2: Build (unit tests + package) ===
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

  # === Stage 3: Test (contract / static against artifact) ===
  stage {
    name = "Test"

    action {
      name            = "ContractTest"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.contract_test.name
      }
    }
  }

  # === Stage 4: Staging (in-place CodeDeploy) ===
  stage {
    name = "Staging"

    action {
      name            = "DeployStaging"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["BuildArtifact"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.main.name
        DeploymentGroupName = aws_codedeploy_deployment_group.staging.deployment_group_name
      }
    }
  }

  # === Stage 5: IntegrationTest (curl deployed staging) ===
  stage {
    name = "IntegrationTest"

    action {
      name            = "IntegrationTest"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.integration_test.name
      }
    }
  }

  # === Stage 6: Production (manual approval + Blue/Green) ===
  stage {
    name = "Production"

    action {
      name      = "ApproveProd"
      category  = "Approval"
      owner     = "AWS"
      provider  = "Manual"
      version   = "1"
      run_order = 1

      configuration = {
        CustomData = "Approve to deploy to production via Blue/Green."
      }
    }

    action {
      name            = "DeployProd"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["BuildArtifact"]
      run_order       = 2

      configuration = {
        ApplicationName     = aws_codedeploy_app.main.name
        DeploymentGroupName = local.prod_dg_name
      }
    }
  }

  # Pipeline must come after the CLI-managed prod DG exists.
  depends_on = [null_resource.prod_dg]
}
