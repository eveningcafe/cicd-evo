# CodeDeploy application with two deployment groups:
#   - staging: in-place rolling on the staging ASG
#   - prod:    Blue/Green over ALB target groups (blue ↔ green)
#
# About the null_resource workaround for prod:
# Terraform AWS provider 5.x ships a buggy serialization of
# `load_balancer_info { target_group_pair_info { ... } }` on Blue/Green
# deployment groups — the AWS API returns InvalidLoadBalancerInfoException
# regardless of the block shape. To unblock the demo we create the prod
# deployment group WITHOUT load_balancer_info via Terraform, then patch it
# in via `aws deploy update-deployment-group` in a null_resource. The CLI
# accepts the same JSON the API needs.

resource "aws_codedeploy_app" "main" {
  name             = local.name
  compute_platform = "Server"
}

# --- Staging: in-place rolling deploy ---

resource "aws_codedeploy_deployment_group" "staging" {
  app_name              = aws_codedeploy_app.main.name
  deployment_group_name = "${local.name}-staging"
  service_role_arn      = aws_iam_role.codedeploy.arn

  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  autoscaling_groups = [aws_autoscaling_group.staging.name]

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

# --- Prod: Blue/Green over ALB (TF creates the DG shell) ---

resource "aws_codedeploy_deployment_group" "prod" {
  app_name              = aws_codedeploy_app.main.name
  deployment_group_name = "${local.name}-prod"
  service_role_arn      = aws_iam_role.codedeploy.arn

  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  autoscaling_groups = [aws_autoscaling_group.prod_blue.name]

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  # load_balancer_info intentionally omitted — patched by null_resource below.
  lifecycle {
    ignore_changes = [load_balancer_info]
  }
}

# --- Prod: patch in Blue/Green ALB info via AWS CLI (workaround) ---

resource "null_resource" "prod_dg_loadbalancer_info" {
  triggers = {
    dg_name      = aws_codedeploy_deployment_group.prod.deployment_group_name
    listener_arn = aws_lb_listener.prod.arn
    blue_name    = aws_lb_target_group.blue.name
    green_name   = aws_lb_target_group.green.name
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws deploy update-deployment-group \
        --region ${var.region} \
        --application-name ${aws_codedeploy_app.main.name} \
        --current-deployment-group-name ${aws_codedeploy_deployment_group.prod.deployment_group_name} \
        --load-balancer-info '${jsonencode({
    targetGroupPairInfoList = [{
      targetGroups = [
        { name = aws_lb_target_group.blue.name },
        { name = aws_lb_target_group.green.name },
      ]
      prodTrafficRoute = {
        listenerArns = [aws_lb_listener.prod.arn]
      }
    }]
})}'
    EOT
}
}
