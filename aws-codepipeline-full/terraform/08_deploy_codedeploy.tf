# CodeDeploy application with two deployment groups:
#   - staging: in-place rolling on the staging ASG  (TF native)
#   - prod:    Blue/Green over ALB target groups   (CLI workaround)
#
# Terraform AWS provider 5.x ships a buggy serialization of
# `load_balancer_info { target_group_pair_info { ... } }` on Blue/Green
# deployment groups — AWS returns InvalidLoadBalancerInfoException both
# when load_balancer_info is set and when it's omitted (the second case
# because the API requires it for WITH_TRAFFIC_CONTROL).
#
# Workaround: create the prod DG entirely via `aws deploy
# create-deployment-group` in a null_resource. The AWS CLI accepts the
# same JSON the API does and just works.

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

# --- Prod: Blue/Green over ALB (CLI workaround) ---

locals {
  prod_dg_name = "${local.name}-prod"

  # Common fields shared by create + update.
  prod_dg_common = {
    serviceRoleArn       = aws_iam_role.codedeploy.arn
    deploymentConfigName = "CodeDeployDefault.AllAtOnce"
    autoScalingGroups    = [aws_autoscaling_group.prod_blue.name]
    deploymentStyle = {
      deploymentOption = "WITH_TRAFFIC_CONTROL"
      deploymentType   = "BLUE_GREEN"
    }
    blueGreenDeploymentConfiguration = {
      deploymentReadyOption        = { actionOnTimeout = "CONTINUE_DEPLOYMENT" }
      greenFleetProvisioningOption = { action = "COPY_AUTO_SCALING_GROUP" }
      terminateBlueInstancesOnDeploymentSuccess = {
        action                       = "TERMINATE"
        terminationWaitTimeInMinutes = 5
      }
    }
    # API rejects `targetGroupPairInfoList` for compute_platform=Server +
    # COPY_AUTO_SCALING_GROUP. Single-TG "instance-shift" Blue/Green works:
    # green ASG provisioned → instances register into TG → blue deregisters
    # → blue ASG terminates after 5 min.
    loadBalancerInfo = {
      targetGroupInfoList = [{ name = aws_lb_target_group.blue.name }]
    }
    autoRollbackConfiguration = {
      enabled = true
      events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
    }
  }

  prod_dg_create_json = jsonencode(merge(local.prod_dg_common, {
    applicationName     = aws_codedeploy_app.main.name
    deploymentGroupName = local.prod_dg_name
  }))

  prod_dg_update_json = jsonencode(merge(local.prod_dg_common, {
    applicationName            = aws_codedeploy_app.main.name
    currentDeploymentGroupName = local.prod_dg_name
  }))
}

resource "null_resource" "prod_dg" {
  triggers = {
    create_json = local.prod_dg_create_json
    update_json = local.prod_dg_update_json
    region      = var.region
    app         = aws_codedeploy_app.main.name
    name        = local.prod_dg_name
  }

  # Create or update — idempotent.
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      if aws deploy get-deployment-group \
           --region "${var.region}" \
           --application-name "${aws_codedeploy_app.main.name}" \
           --deployment-group-name "${local.prod_dg_name}" >/dev/null 2>&1; then
        echo "DG exists, updating..."
        aws deploy update-deployment-group \
          --region "${var.region}" \
          --cli-input-json '${local.prod_dg_update_json}'
      else
        echo "Creating DG..."
        aws deploy create-deployment-group \
          --region "${var.region}" \
          --cli-input-json '${local.prod_dg_create_json}'
      fi
    EOT
  }

  # Delete on destroy.
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      aws deploy delete-deployment-group \
        --region "${self.triggers.region}" \
        --application-name "${self.triggers.app}" \
        --deployment-group-name "${self.triggers.name}" || true
    EOT
  }

  depends_on = [
    aws_codedeploy_app.main,
    aws_iam_role.codedeploy,
    aws_iam_role_policy_attachment.codedeploy,
    aws_autoscaling_group.prod_blue,
    aws_lb_listener.prod,
    aws_lb_target_group.blue,
  ]
}
