module "ami" {
  source = "./modules/ami"

}

module "loadbalancer" {
  source = "./modules/loadbalancer"

  domain_name            = var.domain_name
  alb_security_group_ids = [module.security.alb_sg_id]
  public_subnet_ids      = values(module.vpc.public_subnet_ids)
  vpc_id                 = module.vpc.vpc_id
}


module "compute" {
  source = "./modules/compute"

  ami_id                    = module.ami.ami_id
  instance_type             = var.instance_type
  security_group_ids        = [module.security.ec2_sg_id]
  iam_instance_profile_name = module.iam.instance_profile_name

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

  private_subnet_ids = values(module.vpc.private_subnet_ids)
  target_group_arns  = [module.loadbalancer.target_group_arn]
  min_size           = 2
  desired_capacity   = 2
  max_size           = 4

  alb_resource_label = "${module.loadbalancer.alb_arn_suffix}/${module.loadbalancer.target_group_arn_suffix}"
}


module "database" {
  source = "./modules/database"

  db_username        = var.db_username
  db_name            = var.db_name
  db_subnet_ids      = values(module.vpc.db_subnet_ids)
  security_group_ids = [module.security.db_sg_id]
}

module "vpc" {
  source = "./modules/vpc"

  network_config = var.network_config
}

module "iam" {
  source     = "./modules/iam"
  secret_arn = module.database.secret_arn
}

module "security" {
  source = "./modules/security"

  vpc_id = module.vpc.vpc_id
}
