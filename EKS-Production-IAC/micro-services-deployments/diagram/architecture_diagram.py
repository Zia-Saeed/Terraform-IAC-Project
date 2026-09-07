"""
Architecture diagram-as-code for the ShopFlow microservices platform.

Requires the `diagrams` package (https://diagrams.mingrammer.com/), which
itself requires the Graphviz binary to be installed on your system:
    macOS:   brew install graphviz
    Ubuntu:  sudo apt-get install graphviz
    Windows: choco install graphviz

    pip install diagrams
    python architecture_diagram.py
    # -> produces shopflow_architecture.png in the same folder
"""
from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EKS, ECR
from diagrams.aws.database import RDS
from diagrams.aws.network import ALB, Route53
from diagrams.aws.mobile import Amplify
from diagrams.onprem.client import User
from diagrams.programming.framework import Django
from diagrams.onprem.queue import Kafka  # stand-in icon for "future: message queue"

graph_attr = {
    "fontsize": "22",
    "bgcolor": "white",
    "pad": "0.5",
    "splines": "spline",
}

with Diagram("ShopFlow Microservices Architecture (EKS)", filename="shopflow_architecture", show=False, graph_attr=graph_attr, direction="TB"):

    user = User("End User\n(browser)")

    with Cluster("AWS Amplify"):
        frontend = Amplify("React Frontend\n(ShopFlow UI)")

    dns = Route53("Route53 DNS")

    with Cluster("Amazon EKS Cluster (VPC)"):
        alb = ALB("ALB Ingress\n(api.shopflow.example.com)")

        with Cluster("shopflow namespace"):
            gateway = Django("api-gateway\n:8000")

            with Cluster("Business microservices"):
                user_svc = Django("user-service\n:8001")
                product_svc = Django("product-service\n:8002")
                order_svc = Django("order-service\n:8003")
                notif_svc = Django("notification-service\n:8004")

        eks_control = EKS("EKS Control Plane")

    with Cluster("Amazon RDS (PostgreSQL)"):
        db = RDS("Shared RDS instance\nuserdb | productdb\norderdb | notifdb")

    ecr = ECR("Amazon ECR\n(container images)")

    # --- request flow ---
    user >> Edge(label="HTTPS") >> frontend
    frontend >> Edge(label="HTTPS  /api/*", color="#7c5cff") >> dns >> alb >> gateway

    gateway >> Edge(label="/api/users/*") >> user_svc
    gateway >> Edge(label="/api/products/*") >> product_svc
    gateway >> Edge(label="/api/orders/*") >> order_svc
    gateway >> Edge(label="/api/notifications/*") >> notif_svc

    order_svc >> Edge(label="reserve stock\n(internal token)", color="#ff6b6b", style="dashed") >> product_svc
    order_svc >> Edge(label="order-confirmed event", color="#5ee7c0", style="dashed") >> notif_svc

    for svc in [user_svc, product_svc, order_svc, notif_svc]:
        svc >> Edge(color="gray", style="dotted") >> db

    ecr >> Edge(style="dotted", color="gray", label="image pull") >> eks_control
    eks_control >> Edge(style="dotted", color="gray") >> gateway
