# Network: reuse an existing VPC + subnets. The demo only creates security
# groups inside that VPC.

data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnet" "selected" {
  for_each = toset(var.subnet_ids)
  id       = each.value
}

locals {
  subnet_ids = var.subnet_ids
}

# === Security groups ===

# ALB: accept HTTP from internet.
resource "aws_security_group" "alb" {
  name_prefix = "${local.name}-alb-"
  description = "Public HTTP for the prod ALB"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Prod EC2: only accept :8080 from the ALB SG.
resource "aws_security_group" "prod_app" {
  name_prefix = "${local.name}-prod-app-"
  description = "App port from ALB only"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# CodeBuild integration-test ENI lives here (when running in VPC mode).
# It needs no ingress; only egress so it can curl staging.
resource "aws_security_group" "codebuild" {
  name_prefix = "${local.name}-codebuild-"
  description = "Outbound for the integration-test CodeBuild project"
  vpc_id      = data.aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Staging EC2: accept :8080 from the CodeBuild SG (integration tests run
# inside this VPC). Subnets are private (NAT egress only) so 0.0.0.0/0
# would not actually work — locking to CodeBuild is both correct and tighter.
resource "aws_security_group" "staging_app" {
  # name_prefix + create_before_destroy avoids the DependencyViolation
  # deadlock when this SG must be replaced: AWS won't delete a SG while
  # EC2 ENIs still reference it. Creating new SG first lets ASG/LT swing
  # references before the old SG gets deleted.
  name_prefix = "${local.name}-staging-app-"
  description = "App port from CodeBuild SG"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.codebuild.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}
