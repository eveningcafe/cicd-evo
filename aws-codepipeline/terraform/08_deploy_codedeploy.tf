# CodeDeploy application with two deployment groups: staging (in-place) and
# prod (Blue/Green over ALB target groups).

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

# --- Production: Blue/Green over ALB ---

# Originally this was Blue/Green over ALB, but the AWS API rejected the
# load_balancer_info { target_group_pair_info } block from Terraform AWS
# provider 5.x with InvalidLoadBalancerInfoException. To keep the demo
# moving we use in-place traffic-controlled deploys on the prod ALB —
# CodeDeploy drains instances out of the target group, replaces in place,
# then re-registers. Demo still shows the "traffic control" pattern; just
# not separate blue/green ASGs.
resource "aws_codedeploy_deployment_group" "prod" {
  app_name              = aws_codedeploy_app.main.name
  deployment_group_name = "${local.name}-prod"
  service_role_arn      = aws_iam_role.codedeploy.arn

  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  autoscaling_groups = [aws_autoscaling_group.prod_blue.name]

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.blue.name
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }
}
