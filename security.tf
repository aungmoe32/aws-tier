# 12. Create the Security Group for the ALB (Publicly accessible)
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# 13. Create the Security Group for EC2 (Private, restricted to ALB)
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Allow HTTP inbound traffic ONLY from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    # Security Group Chaining: Referencing the ALB's Security Group ID
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 1. Create the IAM Role for EC2
resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 2. Attach the AWS Managed SSM Policy to the Role
resource "aws_iam_role_policy_attachment" "ssm_policy_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 3. Create an IAM Instance Profile (Required to attach a role to an EC2 instance)
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ssm_role.name
}
# 3. Create the Database Security Group (Security Group Chaining)
resource "aws_security_group" "db_sg" {
  name        = "db-security-group"
  description = "Allow MySQL traffic from EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "MySQL from EC2 Application Tier"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    # STRICT PERMISSION: Only accept traffic originating from the EC2 Security Group
    security_groups = [aws_security_group.ec2_sg.id]
  }

  # RDS needs outbound access to AWS control plane for backups/updates
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
