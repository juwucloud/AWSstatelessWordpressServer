# AWS Stateless WordPress Infrastructure

A production-ready, highly available WordPress deployment on AWS using Terraform. This project demonstrates modern cloud architecture patterns with infrastructure as code, implementing a stateless web tier with shared storage and managed database services.

## 🏗️ Architecture Overview

![Architecture Diagram](AWSstatelessWordpressServer.png)

### Key Components

- **Multi-AZ VPC** with public and private subnets across two availability zones
- **Application Load Balancer** for high availability
- **Auto Scaling Group** with EC2 instances in private subnets
- **Amazon EFS** for shared WordPress content storage
- **Amazon RDS** for managed MySQL database
- **AWS Secrets Manager** for secure credential management
- **Bastion Host** for secure SSH access
- **NAT Gateway** for outbound internet connectivity

### Design Principles

- **Stateless Web Tier**: EC2 instances store no persistent data
- **High Availability**: Multi-AZ deployment with auto-scaling
- **Security**: Private subnets, security groups, and managed credentials
- **Scalability**: Horizontal scaling based on demand
- **Infrastructure as Code**: Fully reproducible via Terraform

## 📁 Project Structure

```text
AWSstatelessWordpressServer/
├── main.tf                      # Root module configuration
├── providers.tf                 # Terraform and AWS provider setup
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── terraform.tfvars             # Variable values (not committed)
├── vpc.tf                       # VPC, subnets, routing
├── security-groups.tf           # Security group definitions
├── loadbalancer.tf              # Application Load Balancer
├── autoscaling.tf               # Launch template and ASG
├── scaling.tf                   # Auto scaling policies
├── rds.tf                       # RDS database instance
├── efs.tf                       # EFS file system and mount targets
├── secretsmanager.tf            # Secrets Manager configuration
├── bastion.tf                   # Bastion host setup
├── iam.tf                       # IAM roles and policies
├── ami.tf                       # AMI data sources
├── LaunchTemplateUserData.sh    # WordPress instance initialization
├── BastionUserdata.sh           # Bastion host setup script
└── LICENSE                      # MIT License
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0 installed
- SSH key pair created in your target AWS region

### Deployment Steps

1. **Clone the repository**
```bash
git clone <repository-url>
cd AWSstatelessWordpressServer
```


2. **Configure variables**
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```


3. **Set up database credentials in AWS Secrets Manager**
```bash
aws secretsmanager create-secret \
--name "wpsecrets" \
--description "WordPress database credentials" \
--secret-string '{
    "db_name": "wordpress",
    "db_user": "wpuser",
    "db_password": "your-secure-password",
    "db_host": "will-be-updated-by-terraform"
}'
```

4. **Deploy infrastructure**
```bash
terraform init
terraform plan
terraform apply
```



5. **Access your WordPress site**
   - Use the ALB DNS name from Terraform outputs
   - Complete WordPress setup via web interface

6. **Test autoscaling**
   - via Bastion host install stresstest on Webserver
```bash
sudo dnf install stress -y
stress --cpu 2 --timeout 600
```



## ⚙️ Configuration

### Required Variables

```hcl
region = "us-west-2"
vpc_cidr = "10.0.0.0/16"
public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
db_secret_name = "wpsecrets"
key_name = "your-ec2-key-pair"
```

### Optional Customizations

- Instance types for web servers and database
- EFS performance mode and throughput
- Auto scaling parameters
- Security group rules

## 🔒 Security Features

- **Network Isolation**: Web servers in private subnets
- **Encrypted Storage**: EFS and RDS encryption at rest
- **Secrets Management**: Database credentials in AWS Secrets Manager
- **Security Groups**: Least privilege access controls
- **SSL/TLS**: Encrypted data in transit

## 🔧 Troubleshooting

### Common Issues

1. **Database Connection Failures**
   - Verify Secrets Manager configuration
   - Check security group rules
   - Ensure RDS is in available state

2. **EFS Mount Issues**
   - Confirm mount targets in correct subnets
   - Verify security group allows NFS traffic (port 2049)
   - Check EFS file system state

3. **Load Balancer Health Checks**
   - Verify `/health` endpoint responds
   - Check security group allows ALB traffic
   - Review user data script logs in `/var/log/user-data.log`

### Debugging Commands

```bash
# Check instance logs
aws logs describe-log-groups --log-group-name-prefix "/aws/ec2"

# View user data execution
ssh -i your-key.pem ec2-user@bastion-ip
sudo tail -f /var/log/user-data.log

# Test database connectivity
mysql -h <rds-endpoint> -u <username> -p
```

## 🚧 Limitations & Future Enhancements

### Current Limitations
- Single-zone EFS for cost optimization
- Basic SSL configuration
- Limited monitoring and alerting

### Planned Improvements
- [ ] Multi-AZ EFS deployment
- [ ] AWS Certificate Manager integration
- [ ] Enhanced CloudWatch dashboards
- [ ] AWS WAF integration
- [ ] Container-based deployment option
- [ ] CI/CD pipeline integration

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Note**: This project is designed for learning and demonstration purposes. For production use, additional security hardening and monitoring should be implemented based on your specific requirements.