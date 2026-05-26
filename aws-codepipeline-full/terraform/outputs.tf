output "region" {
  value = var.region
}

output "pipeline_name" {
  value       = aws_codepipeline.main.name
  description = "Name of the CodePipeline pipeline (use with: aws codepipeline get-pipeline-state)."
}

output "github_connection_arn" {
  value       = aws_codestarconnections_connection.github.arn
  description = "ARN of the GitHub CodeConnections connection."
}

output "github_connection_status_note" {
  value = "Connection starts in PENDING. Open: AWS Console → Developer Tools → Settings → Connections → ${aws_codestarconnections_connection.github.name} → Update pending connection → authorize via GitHub OAuth. Pipeline won't trigger until status is AVAILABLE."
}

output "github_repo" {
  value = var.github_repo
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.id
}

output "prod_alb_dns" {
  value       = aws_lb.prod.dns_name
  description = "Public ALB DNS for the production fleet."
}

output "staging_asg_name" {
  value = aws_autoscaling_group.staging.name
}

output "prod_asg_name" {
  value = aws_autoscaling_group.prod_blue.name
}
