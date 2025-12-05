# CloudWatch Alarm for Scale Out
resource "aws_cloudwatch_metric_alarm" "scale_out_alarm" {
  alarm_name          = "autoscaling-scale-out"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "GroupDesiredCapacity"
  namespace           = "AWS/AutoScaling"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Autoscaling scaled out"
  alarm_actions       = [aws_sns_topic.autoscaling_alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.jwasg.name
  }
}

# CloudWatch Alarm for Scale In
resource "aws_cloudwatch_metric_alarm" "scale_in_alarm" {
  alarm_name          = "autoscaling-scale-in"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "GroupDesiredCapacity"
  namespace           = "AWS/AutoScaling"
  period              = "60"
  statistic           = "Average"
  threshold           = "2"
  alarm_description   = "Autoscaling scaled in"
  alarm_actions       = [aws_sns_topic.autoscaling_alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.jwasg.name
  }
}

# SNS Topic for autoscaling notifications
resource "aws_sns_topic" "autoscaling_alerts" {
  name = "autoscaling-alerts"
}

# SNS Subscription (replace with your email)
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.autoscaling_alerts.arn
  protocol  = "email"
  endpoint  = "nanay16969@datehype.com" #temp mail for testing
}

