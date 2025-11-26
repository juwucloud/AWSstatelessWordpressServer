########################################
# Auto Scaling Policies for WordPress ASG
# Target Tracking based on CPU Utilization
########################################

resource "aws_autoscaling_policy" "jw_scale_out" {
  name                   = "jw-scale-out"
  autoscaling_group_name = aws_autoscaling_group.jwasg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    # Target CPU for scaling decisions
    target_value = 60
  }

  # Time to wait after scale-out before evaluating again
  # Warmup allows new instances to fully boot WordPress
  estimated_instance_warmup = 180

  depends_on = [
    aws_autoscaling_group.jwasg
  ]
}

########################################
# Scale-In policy (same metric, same target)
########################################

resource "aws_autoscaling_policy" "jw_scale_in" {
  name                   = "jw-scale-in"
  autoscaling_group_name = aws_autoscaling_group.jwasg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    # Same target ensures symmetrical behavior
    target_value = 60
  }

  # Warmup also applies to scale-in evaluation
  estimated_instance_warmup = 180

  depends_on = [
    aws_autoscaling_group.jwasg
  ]
}
