########################################
# Application Load Balancer
########################################

resource "aws_lb" "jwalb" {
  name               = "jwalb"
  load_balancer_type = "application"
  internal           = false # internet-facing

  # ALB lives in the public subnets
  subnets = [
    aws_subnet.jwpublic_1.id,
    aws_subnet.jwpublic_2.id
  ]

  security_groups = [
    aws_security_group.jwsg_alb.id
  ]

  tags = {
    Name = "jwalb"
  }
}

########################################
# Target Group (for WordPress EC2 ASG)
########################################

resource "aws_lb_target_group" "jwalb_tg" {
  name        = "jwalb-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.jwvpc.id

  # Launchtemplate creates this path /var/www/html/health
  health_check {
    enabled             = true 
    port                = 80
    protocol            = "HTTP"
    path                = "/health"
    interval            = 30  # not so aggressive
    timeout             = 10 # not so aggressive
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name = "jwalb-tg"
  }
}

########################################
# Listener (Port 80 -> Target Group)
########################################

resource "aws_lb_listener" "jwalb_listener" {
  load_balancer_arn = aws_lb.jwalb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jwalb_tg.arn
  }

  tags = {
    Name = "jwalb-listener"
  }
}
