# Create the Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "my-app-alb"
  internal           = false # "false" makes it Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  # The ALB is placed into both public subnets across two AZs
  subnets = [aws_subnet.public.id, aws_subnet.public_2.id]
}

# Create the Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "my-app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Health Check configuration
  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Create the ALB Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Create the Launch Template
resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-launch-template-"
  image_id      = "ami-098e39bafa7e7303d"
  instance_type = "t2.micro"

  # Attach the Private EC2 Security Group
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_profile.name
  }

  # Launch Templates require user_data to be base64 encoded
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3 python3-pip
    pip3 install flask pymysql

    # Retrieve IMDSv2 metadata
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

    # Write the Python Flask Application
    cat << 'APP_EOF' > /home/ec2-user/app.py
    from flask import Flask
    import pymysql
    import os

    app = Flask(__name__)

    # Read environment variables injected by Systemd
    DB_HOST = os.environ.get("DB_HOST")
    DB_USER = os.environ.get("DB_USER")
    DB_PASS = os.environ.get("DB_PASS")
    DB_NAME = os.environ.get("DB_NAME")
    AZ = os.environ.get("AZ")

    def get_db_connection():
        return pymysql.connect(
            host=DB_HOST, 
            user=DB_USER, 
            password=DB_PASS, 
            database=DB_NAME, 
            cursorclass=pymysql.cursors.DictCursor
        )

    @app.route('/')
    def index():
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # Create table if it doesn't exist
            cursor.execute("CREATE TABLE IF NOT EXISTS visits (id INT AUTO_INCREMENT PRIMARY KEY, az VARCHAR(255))")
            
            # Insert a new visit record into the database
            cursor.execute("INSERT INTO visits (az) VALUES (%s)", (AZ,))
            conn.commit()
            
            # Query the total number of visits
            cursor.execute("SELECT COUNT(*) as count FROM visits")
            count = cursor.fetchone()['count']
        conn.close()
        
        return f"<h1>Hello from AZ: {AZ}</h1><p>Total website visits logged in RDS: {count}</p>"

    # Dedicated health check path for the ALB
    @app.route('/health')
    def health():
        return "OK", 200

    if __name__ == '__main__':
        # Run on Port 80 to accept traffic from the ALB
        app.run(host='0.0.0.0', port=80)
    APP_EOF

    # Create a Systemd service to run the Python app continuously
    cat << SVC_EOF > /etc/systemd/system/flaskapp.service
    [Unit]
    Description=Flask Web Server
    After=network.target

    [Service]
    User=root
    # Terraform dynamically injects the RDS connection details here
    Environment="DB_HOST=${aws_db_instance.app_database.address}"
    Environment="DB_USER=${aws_db_instance.app_database.username}"
    Environment="DB_PASS=${aws_db_instance.app_database.password}"
    Environment="DB_NAME=webappdb"
    Environment="AZ=$AZ"
    ExecStart=/usr/bin/python3 /home/ec2-user/app.py
    Restart=always

    [Install]
    WantedBy=multi-user.target
    SVC_EOF

    # Start the Python server
    systemctl daemon-reload
    systemctl start flaskapp
    systemctl enable flaskapp
  EOF
  )

  # Automatically tag the EC2 instances created by the ASG
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "asg-web-server"
    }
  }
}

# Create the Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  name = "app-autoscaling-group"

  # Instructs the ASG to deploy instances evenly across both private subnets
  vpc_zone_identifier = [aws_subnet.private.id, aws_subnet.private_2.id]

  # Automatically registers new instances to your ALB Target Group
  target_group_arns = [aws_lb_target_group.app_tg.arn]

  # Self-Healing: Tell the ASG to use the ALB's health checks to determine instance health
  health_check_type         = "ELB"
  health_check_grace_period = 300 # Give the instance 5 minutes to boot before checking health

  # Capacity settings
  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
}




resource "aws_autoscaling_policy" "request_count_tracking" {
  name                   = "alb-request-count-policy"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"

      # Requires the ALB Target Group ARN suffix so CloudWatch knows which traffic to monitor
      resource_label = "${aws_lb.app_alb.arn_suffix}/${aws_lb_target_group.app_tg.arn_suffix}"
    }

    # Scale out if each server is handling more than 1000 requests per minute
    target_value = 1000.0
  }
}



