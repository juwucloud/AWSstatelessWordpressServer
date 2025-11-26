########################################
# Launch Template for WordPress EC2
########################################

resource "aws_launch_template" "jwlt" {
  name_prefix   = "jwlt-"
  image_id      = var.ami_id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.jw_instance_profile.name
  }

  # Enforce IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  network_interfaces {
    security_groups = [aws_security_group.jwsg_web.id]
  }

  # Load User Data from file (base64 required by AWS)
  user_data = filebase64("${path.module}/LaunchTemplateUserData.sh")

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "jwweb"
    }
  }

  tags = {
    Name = "jwlt"
  }
}

########################################
# Auto Scaling Group
########################################

resource "aws_autoscaling_group" "jwasg" {
  name             = "jwasg"
  desired_capacity = 2
  max_size         = 3
  min_size         = 1

  vpc_zone_identifier = [
    aws_subnet.jwprivate_1.id,
    aws_subnet.jwprivate_2.id
  ]

  target_group_arns = [
    aws_lb_target_group.jwalb_tg.arn
  ]

  # Crucial: allows WordPress to fully boot before ALB health checks apply
  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.jwlt.id
    version = "$Latest"
  }

  # Make sure ALB listener exists first
  depends_on = [
    aws_lb_listener.jwalb_listener
  ]

  # Propagate Name tag to all instances
  tag {
    key                 = "Name"
    value               = "jweb"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
