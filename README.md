# terraform-aws-ecs-fargate-alb

Deploy a Dockerized web application on AWS using ECS Fargate, Application Load Balancer (ALB), and Terraform.

## Architecture

- **ECR**: Stores Docker images.
- **VPC, Subnets, NAT Gateway**: Networking for public/private resources.
- **ALB**: Exposes the app to the internet.
- **ECS Cluster, Task Definition, Service**: Runs and manages the containerized app.

## Prerequisites

- AWS account and credentials configured
- Terraform installed
- Docker installed

## Usage

1. **Clone the repository**
   ```sh
   git clone https://github.com/yourusername/terraform-aws-ecs-fargate-alb.git
   cd terraform-aws-ecs-fargate-alb

2. ****Build and push your Docker image**

aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
docker build -t myapp .
docker tag myapp:latest <account-id>.dkr.ecr.<region>.amazonaws.com/myapp:latest
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/myapp:latest


Notes
ECS tasks run in private subnets; ALB is in public subnets.
NAT Gateway allows ECS tasks outbound internet access.
No public IPs are assigned to ECS tasks.
HTTPS can be added later by creating an ACM certificate and a 443 listener.
