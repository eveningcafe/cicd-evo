output "region" {
  value = var.region
}

output "pipeline_name" {
  value = aws_codepipeline.main.name
}

output "instance_id" {
  value = aws_instance.app.id
}

output "instance_public_ip" {
  value = aws_instance.app.public_ip
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.id
}

output "connection_arn" {
  value = aws_codestarconnections_connection.github.arn
}

output "connection_console_url" {
  value = "https://${var.region}.console.aws.amazon.com/codesuite/settings/connections?region=${var.region}"
}
