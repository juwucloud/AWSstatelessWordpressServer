########################################
# Auto Scaling Target Tracking for WordPress ASG
# One policy handles both scale-in and scale-out
########################################

resource "aws_autoscaling_policy" "jw_target_tracking" {
  name                   = "jw-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.jwasg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    # CPU Target (50%)
    target_value = 50
  }

  # Warmup time so new instances can fully start WordPress
  estimated_instance_warmup = 180

  depends_on = [
    aws_autoscaling_group.jwasg
  ]
}
