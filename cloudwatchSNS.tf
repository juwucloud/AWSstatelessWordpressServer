# CloudWatch Alarm for High CPU (scale out indicator)
resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = "high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1" # scale out quickly
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "CPU utilization is above 50%"
  alarm_actions       = [aws_sns_topic.autoscaling_alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.jwasg.name
  }
}

# CloudWatch Alarm for Low CPU (scale in indicator)
resource "aws_cloudwatch_metric_alarm" "low_cpu_alarm" {
  alarm_name          = "low-cpu-utilization"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2" # avoid flapping
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "40"  # Below target, indicates scale-in
  alarm_description   = "CPU utilization is below 40%"
  alarm_actions       = [aws_sns_topic.autoscaling_alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.jwasg.name
  }
}

# CloudWatch Dashboard for monitoring
resource "aws_cloudwatch_dashboard" "jwCW_dashboard" {
  dashboard_name = "WordPress-Dashboard"
  dashboard_body = jsonencode({
    widgets = [{
      type   = "metric"
      properties = {
        metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.jwasg.name]]
        region  = var.region
        title   = "ASG CPU Utilization"
      }
    }]
  })
}

# SNS Topic for autoscaling notifications
resource "aws_sns_topic" "autoscaling_alerts" {
  name = "jw-autoscaling-alerts"
}

# SNS Subscription (replace with your email)
resource "aws_sns_topic_subscription" "jw_email_alert" {
  topic_arn = aws_sns_topic.autoscaling_alerts.arn
  protocol  = "email"
  endpoint  = "nanay16969@datehype.com" #temp mail for testing
}

