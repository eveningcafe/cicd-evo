# Production fleet: ALB + blue ASG. Blue/Green CodeDeploy creates the green
# replacement ASG dynamically at deploy time; we only define "blue" here.

# --- ALB + target groups (blue, green) ---

resource "aws_lb" "prod" {
  name               = "${local.name}-prod"
  load_balancer_type = "application"
  subnets            = local.subnet_ids
  security_groups    = [aws_security_group.alb.id]
  internal           = false
}

resource "aws_lb_target_group" "blue" {
  name        = "${local.name}-blue"
  vpc_id      = data.aws_vpc.main.id
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "prod" {
  load_balancer_arn = aws_lb.prod.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  # CodeDeploy flips the default action between blue/green during deploys.
  # Don't fight it with Terraform.
  lifecycle {
    ignore_changes = [default_action]
  }
}

# --- Blue ASG (the initial production fleet) ---

resource "aws_launch_template" "prod_blue" {
  name_prefix   = "${local.name}-prod-blue-"
  image_id      = local.ami_id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.prod_app.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    region      = var.region
    environment = "prod"
  }))

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.name}-prod"
      Project     = local.name
      Environment = "prod"
    }
  }
}

resource "aws_autoscaling_group" "prod_blue" {
  name                = "${local.name}-prod-blue"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 4
  vpc_zone_identifier = local.subnet_ids
  target_group_arns   = [aws_lb_target_group.blue.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.prod_blue.id
    version = "$Latest"
  }

  # CodeDeploy temporarily attaches additional target groups during Blue/Green
  # deployments. Don't let Terraform revert them.
  lifecycle {
    ignore_changes = [target_group_arns, load_balancers]
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-prod"
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = local.name
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = "prod"
    propagate_at_launch = true
  }
}
