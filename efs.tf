########################################
# EFS File System (One Zone)
########################################

resource "aws_efs_file_system" "jwefs" {
  availability_zone_name = "us-west-2a"
  encrypted              = true

  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"   # for costsaving in testing 

  # No backup policy -> for costsaving in testing
  # No lifecycle policy -> for costsaving in testing

  tags = {
    Name = "jwefs"
  }
}

########################################
# Mount Target (One Zone -> only 1 allowed)
########################################

resource "aws_efs_mount_target" "jwefs_mt_1" {
  file_system_id  = aws_efs_file_system.jwefs.id

  # Must be in the same Availability Zone as the One Zone EFS (us-west-2a)
  subnet_id       = aws_subnet.jwprivate_1.id

  # Only inbound NFS from Webserver SG
  security_groups = [aws_security_group.jwsg_efs.id]

}

########################################
# Access Point for /wp-content
########################################

resource "aws_efs_access_point" "jwefs_ap" {
  file_system_id = aws_efs_file_system.jwefs.id

  # Root directory for WordPress content
  root_directory {
    path = "/wp-content"

    creation_info {
      owner_uid   = 48   # Apache user
      owner_gid   = 48   # Apache group
      permissions = "0755"
    }
  }

  # All EFS operations run as Apache (UID/GID 48)
  posix_user {
    uid = 48
    gid = 48
  }

  tags = {
    Name = "jwefs-ap"
  }
}
