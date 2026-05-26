resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "${local.name}-artifacts-"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# One SG: world can hit :8080 (subnet must be public for this to be reachable).
resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "App port from anywhere"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Single EC2 instance — no ASG, no LT replication, no Blue/Green. Tag-based
# CodeDeploy targeting picks it up.
resource "aws_instance" "app" {
  ami                         = local.ami_id
  instance_type               = "t3.micro"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user-data.sh", {
    region = var.region
  })

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name    = local.name
    Project = local.name
  }
}
