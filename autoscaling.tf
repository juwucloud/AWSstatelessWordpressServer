########################################
# Launch Template for WordPress EC2
########################################

resource "aws_launch_template" "jwlt" {
  depends_on = [ 
    aws_efs_file_system.jwefs,
    aws_secretsmanager_secret_version.db_creds_update,
    aws_db_instance.jwrds
  ]

  name_prefix   = "jwlt-"
  key_name      = var.key_name
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t2.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.jw_instance_profile.name
  }

  network_interfaces {
    security_groups = [aws_security_group.jwsg_web.id]
  }

  # Load User Data from file (base64 required by AWS)
  user_data    = base64encode(templatefile("${path.module}/LaunchTemplateUserData.sh", {
    efs_id     = aws_efs_file_system.jwefs.id
    efs_ap_id  = aws_efs_access_point.jwefs_ap.id
  }))

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
  desired_capacity = 1 # 2 for production
  max_size         = 3 # 4 for production
  min_size         = 1 # 2 for production

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
