# Staging fleet: 1 EC2 instance, in-place CodeDeploy.

resource "aws_launch_template" "staging" {
  name_prefix   = "${local.name}-staging-"
  image_id      = local.ami_id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.staging_app.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    region      = var.region
    environment = "staging"
  }))

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.name}-staging"
      Project     = local.name
      Environment = "staging"
    }
  }
}

resource "aws_autoscaling_group" "staging" {
  name                = "${local.name}-staging"
  desired_capacity    = 1
  min_size            = 1
  max_size            = 1
  vpc_zone_identifier = local.subnet_ids
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.staging.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-staging"
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = local.name
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = "staging"
    propagate_at_launch = true
  }
}
