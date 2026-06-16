module "ami" {
  source = "./modules/ami"

}

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_acm_certificate" "app_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = { Name = "app-ssl-cert" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "app_cert_validation" {
  certificate_arn         = aws_acm_certificate.app_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}


resource "aws_lb" "app_alb" {
  name               = "my-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  subnets = [for subnet in aws_subnet.public : subnet.id]
}

resource "aws_lb_target_group" "app_tg" {
  name     = "my-app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

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

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "443"
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-2016-08"
  certificate_arn = aws_acm_certificate_validation.app_cert_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.app_alb.dns_name
    zone_id                = aws_lb.app_alb.zone_id
    evaluate_target_health = true
  }
}


module "compute" {
  source = "./modules/compute"

  ami_id                    = module.ami.ami_id
  instance_type             = var.instance_type
  security_group_ids        = [aws_security_group.ec2_sg.id]
  iam_instance_profile_name = aws_iam_instance_profile.ssm_profile.name

  user_data_base64 = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3 python3-pip
    pip3 install flask pymysql boto3

    # Retrieve IMDSv2 metadata
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

    # Write the Python Flask Application
    cat << 'APP_EOF' > /home/ec2-user/app.py
    from flask import Flask
    import pymysql
    import os
    import boto3
    import json

    app = Flask(__name__)

    # Read environment variables injected by Systemd
    AZ = os.environ.get("AZ")
    def get_db_credentials():
        # Connect to Secrets Manager using the EC2's IAM Role
        client = boto3.client('secretsmanager', region_name='us-east-1')
        response = client.get_secret_value(SecretId='prod/webapp/db-credentials')

        # Parse the JSON string we created in Terraform
        return json.loads(response['SecretString'])

    def get_db_connection():
        creds = get_db_credentials()
        return pymysql.connect(
            host=creds['host'],
            user=creds['username'],
            password=creds['password'],
            database=creds['dbname'],
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

  private_subnet_ids = [for subnet in aws_subnet.private : subnet.id]
  target_group_arns  = [aws_lb_target_group.app_tg.arn]
  min_size           = 2
  desired_capacity   = 2
  max_size           = 4

  alb_resource_label = "${aws_lb.app_alb.arn_suffix}/${aws_lb_target_group.app_tg.arn_suffix}"
}
