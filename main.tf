# 1. Define the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# 2. Create the VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# 3. Create a Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # Automatically assigns public IPs to instances (like ALB nodes)

  tags = {
    Name = "public-subnet-1a"
  }
}

# 4. Create a Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  # map_public_ip_on_launch defaults to false

  tags = {
    Name = "private-subnet-1a"
  }
}

# 5. Create an Internet Gateway (IGW)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# 6. Create a Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# 7. Associate the Public Route Table with the Public Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# 8. Create an Elastic IP for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "main-nat-eip"
  }
}

# 9. Create the NAT Gateway (Must be placed in the PUBLIC Subnet)
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  # Ensure the IGW exists before creating the NAT Gateway
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "main-nat-gw"
  }
}

# 10. Create a Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private-route-table"
  }
}

# 11. Associate the Private Route Table with the Private Subnet
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

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

# 14. Create a Second Public Subnet (Required for ALB)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1b"
  }
}

# Associate the SECOND public subnet with the Public Route Table
resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# 15. Create the Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "my-app-alb"
  internal           = false # "false" makes it Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  # The ALB is placed into both public subnets across two AZs
  subnets = [aws_subnet.public.id, aws_subnet.public_2.id]
}

# 16. Create the Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "my-app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Health Check configuration
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 17. Create the ALB Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# 18. Create the EC2 Instance (in the PRIVATE subnet)
resource "aws_instance" "web_server" {
  ami           = "ami-098e39bafa7e7303d" # Standard Amazon Linux 2023 AMI in us-east-1
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private.id

  # Attach the Private EC2 Security Group
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # user_data runs a script on boot to install a web server so the health check passes
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from the Private Subnet in AZ 1a!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "private-web-server"
  }
}

# 19. Register the EC2 Instance to the Target Group
resource "aws_lb_target_group_attachment" "tg_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web_server.id
  port             = 80
}

# 20. Output the ALB DNS Name to your terminal
output "alb_dns_name" {
  value       = aws_lb.app_alb.dns_name
  description = "Copy this URL into your browser to access the website"
}

# 21. Create a Second Private Subnet in AZ 1b
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-subnet-1b"
  }
}

# 22. Associate the Second Private Subnet with the Private Route Table
# This allows the second EC2 instance to reach the internet via the existing NAT Gateway
resource "aws_route_table_association" "private_2_assoc" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

# 23. Create the Second EC2 Instance in AZ 1b
resource "aws_instance" "web_server_2" {
  ami           = "ami-098e39bafa7e7303d"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_2.id # Placed in the new AZ 1b private subnet

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from the Private Subnet in AZ 1b!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "private-web-server-2"
  }
}

# 24. Register the Second EC2 Instance to the Target Group
resource "aws_lb_target_group_attachment" "tg_attachment_2" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web_server_2.id
  port             = 80
}
