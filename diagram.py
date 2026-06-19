from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2, AutoScaling
from diagrams.aws.database import RDS
from diagrams.aws.network import ELB, InternetGateway, NATGateway
from diagrams.aws.security import SecretsManager
from diagrams.aws.management import SystemsManager
from diagrams.aws.general import Users

# Define layout attributes to keep the spacing clean
graph_attributes = {
    "pad": "1.0",
    "nodesep": "1.2",
    "ranksep": "1.5"
}

with Diagram("AWS Enterprise 3-Tier Architecture", show=False, direction="TB", graph_attr=graph_attributes):
    
    users = Users("Internet Users")
    
    with Cluster("AWS Cloud"):
        igw = InternetGateway("Internet Gateway")
        
        # Managed Services outside the VPC routing boundary
        secrets_manager = SecretsManager("Secrets Manager\n(DB Credentials)")
        ssm = SystemsManager("Systems Manager\n(Session Manager)")
        
        with Cluster("VPC (10.0.0.0/16)"):
            alb = ELB("Application Load Balancer")

            # Availability Zone 1a
            with Cluster("Availability Zone 1a (us-east-1a)"):
                with Cluster("Public Subnet 1a (Ingress)"):
                    nat_1a = NATGateway("NAT Gateway 1a")
                
                with Cluster("Private Subnet 1a (Application)"):
                    ec2_1a = EC2("Flask Server 1a")
                
                with Cluster("DB Subnet 1a (Data)"):
                    rds_primary = RDS("MySQL (Primary)")

            # Availability Zone 1b
            with Cluster("Availability Zone 1b (us-east-1b)"):
                with Cluster("Public Subnet 1b (Ingress)"):
                    nat_1b = NATGateway("NAT Gateway 1b")
                
                with Cluster("Private Subnet 1b (Application)"):
                    ec2_1b = EC2("Flask Server 1b")
                
                with Cluster("DB Subnet 1b (Data)"):
                    rds_standby = RDS("MySQL (Standby)")

            # Logical Auto Scaling Group boundary
            asg = AutoScaling("Auto Scaling Group")

            # ----------------------------------------
            # Traffic Flows and API Calls
            # ----------------------------------------

            # 1. User Inbound Traffic
            users >> Edge(color="darkgreen", label="HTTP(S) Traffic") >> igw >> alb
            alb >> Edge(color="darkgreen") >> ec2_1a
            alb >> Edge(color="darkgreen") >> ec2_1b
            
            # 2. ASG grouping visualization
            asg - Edge(style="dotted") - ec2_1a
            asg - Edge(style="dotted") - ec2_1b
            
            # 3. Database Connectivity
            ec2_1a >> Edge(color="blue", label="Port 3306") >> rds_primary
            ec2_1b >> Edge(color="blue") >> rds_primary
            rds_primary - Edge(color="red", style="dashed", label="Sync Replication") - rds_standby
            
            # 4. Outbound Internet via localized NAT Gateways
            ec2_1a >> Edge(color="orange", style="dashed", label="Outbound Route") >> nat_1a
            ec2_1b >> Edge(color="orange", style="dashed") >> nat_1b
            nat_1a >> Edge(color="orange", style="dashed") >> igw
            nat_1b >> Edge(color="orange", style="dashed") >> igw

            # 5. AWS API Calls (Routed out through NAT to AWS services)
            ec2_1a >> Edge(color="purple", style="dotted", label="Fetch Password") >> secrets_manager
            ec2_1b >> Edge(color="purple", style="dotted") >> secrets_manager

            ec2_1a >> Edge(color="teal", style="dotted", label="SSM Telemetry") >> ssm
            ec2_1b >> Edge(color="teal", style="dotted") >> ssm