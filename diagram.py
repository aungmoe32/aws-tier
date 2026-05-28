from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2, AutoScaling
from diagrams.aws.database import RDS
from diagrams.aws.network import ELB, InternetGateway, NATGateway
from diagrams.aws.general import Users

# 1. Define the spacing attributes
graph_attributes = {
    "pad": "1.0",      # Adds padding around the outer edges of the entire image
    "nodesep": "2.5",  # Increases horizontal spacing between adjacent nodes
    "ranksep": "1.5",  # Increases vertical spacing between the different tiers/layers
}

# 2. Pass the attributes into the Diagram using graph_attr
with Diagram("AWS 3-Tier Web Architecture", show=False, direction="TB", graph_attr=graph_attributes):
    
    users = Users("Internet Users")

    with Cluster("AWS Cloud"):
        igw = InternetGateway("Internet Gateway")
        
        with Cluster("VPC (10.0.0.0/16)"):
            alb = ELB("Application Load Balancer")

            with Cluster("Availability Zone 1a (us-east-1a)"):
                with Cluster("Public Subnet 1a (Ingress)"):
                    nat_1a = NATGateway("NAT Gateway 1a")
                
                with Cluster("Private Subnet 1a (Application)"):
                    ec2_1a = EC2("Flask Server 1a")
                
                with Cluster("DB Subnet 1a (Data)"):
                    rds_primary = RDS("MySQL (Primary)")

            with Cluster("Availability Zone 1b (us-east-1b)"):
                with Cluster("Public Subnet 1b (Ingress)"):
                    nat_1b = NATGateway("NAT Gateway 1b")
                
                with Cluster("Private Subnet 1b (Application)"):
                    ec2_1b = EC2("Flask Server 1b")
                
                with Cluster("DB Subnet 1b (Data)"):
                    rds_standby = RDS("MySQL (Standby)")

            asg = AutoScaling("Auto Scaling Group")

            # Traffic Flows
            users >> Edge(color="darkgreen", label="HTTP 80") >> igw >> alb
            
            alb >> Edge(color="darkgreen") >> ec2_1a
            alb >> Edge(color="darkgreen") >> ec2_1b
            
            asg - Edge(style="dotted") - ec2_1a
            asg - Edge(style="dotted") - ec2_1b
            
            ec2_1a >> Edge(color="blue", label="Port 3306") >> rds_primary
            ec2_1b >> Edge(color="blue") >> rds_primary
            
            rds_primary - Edge(color="red", style="dashed", label="Sync Replication") - rds_standby
            
            ec2_1a >> Edge(color="orange", style="dashed", label="Outbound") >> nat_1a
            ec2_1b >> Edge(color="orange", style="dashed") >> nat_1b
            nat_1a >> Edge(color="orange", style="dashed") >> igw
            nat_1b >> Edge(color="orange", style="dashed") >> igw