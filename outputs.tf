output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.jwalb.dns_name
}

output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = aws_db_instance.jwrds.endpoint
}

output "efs_id" {
  description = "ID of the EFS filesystem"
  value       = aws_efs_file_system.jwefs.id
}

output "access_point_id" {
  description = "ID of the EFS access point"
  value       = aws_efs_access_point.jwefs_ap.id
}

output "autoscaling_group_name" {
  description = "Name of the AutoScaling group"
  value       = aws_autoscaling_group.jwasg.name
}

output "launch_template_id" {
  description = "ID of the EC2 Launch Template"
  value       = aws_launch_template.jwlt.id
}

output "alb_dns" {
  description = "DNS name of the ALB"
  value       = aws_lb.jwalb.dns_name
}
