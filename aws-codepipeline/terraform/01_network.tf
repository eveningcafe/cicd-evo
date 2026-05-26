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
  name        = "${local.name}-alb"
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
}

# Prod EC2: only accept :8080 from the ALB SG.
resource "aws_security_group" "prod_app" {
  name        = "${local.name}-prod-app"
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
}

# Staging EC2: accept :8080 from anywhere (so CodeBuild integration tests
# can hit it without putting CodeBuild in this VPC). Demo-friendly; not
# what you'd do in prod.
resource "aws_security_group" "staging_app" {
  name        = "${local.name}-staging-app"
  description = "App port from anywhere for integration tests"
  vpc_id      = data.aws_vpc.main.id

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
