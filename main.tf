# ECR repository for Docker images
resource "aws_ecr_repository" "myapp" {
  name = "myapp"

  description = "ECR repository to store Docker images for myapp"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "myapp-ecr"
  }
}

# VPC for the application
resource "aws_vpc" "main" {
  cidr_block  = "10.0.0.0/16"
  description = "Main VPC for myapp containing public and private subnets"

  tags = {
    Name = "myapp-vpc"
  }
}

# Internet gateway for public subnets
resource "aws_internet_gateway" "igw" {
  vpc_id      = aws_vpc.main.id
  description = "Internet gateway for public subnet access"

  tags = {
    Name = "myapp-igw"
  }
}

# Public subnets for ALB
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  description             = "Public subnet 1 for ALB"

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  description             = "Public subnet 2 for ALB"

  tags = {
    Name = "public-subnet-2"
  }
}

# Private subnets for ECS Fargate tasks
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  description       = "Private subnet 1 for ECS Fargate tasks"

  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  description       = "Private subnet 2 for ECS Fargate tasks"

  tags = {
    Name = "private-subnet-2"
  }
}

# NAT Gateway for private subnets to access internet
resource "aws_eip" "nat_eip" {
  domain      = "vpc"
  description = "Elastic IP for NAT Gateway"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id
  description   = "NAT Gateway for private subnets"

  tags = {
    Name = "myapp-nat"
  }
}

# Route tables
resource "aws_route_table" "public_rt" {
  vpc_id      = aws_vpc.main.id
  description = "Route table for public subnets"

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  description            = "Route to internet for public subnets"
}

resource "aws_route_table" "private_rt" {
  vpc_id      = aws_vpc.main.id
  description = "Route table for private subnets"
  
  tags = {
    Name = "private-rt"
  }
}

resource "aws_route" "private_internet" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
  description            = "Route to internet for private subnets via NAT"
}

# Associate route tables to subnets
resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
  description    = "Associate public subnet 1 with public route table"
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
  description    = "Associate public subnet 2 with public route table"
}

resource "aws_route_table_association" "private_1_assoc" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
  description    = "Associate private subnet 1 with private route table"
}

resource "aws_route_table_association" "private_2_assoc" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
  description    = "Associate private subnet 2 with private route table"
}

# Security group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB allowing HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "alb-sg"
  }
}

# Security group for ECS tasks
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Security group for ECS Fargate tasks allowing traffic only from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow traffic only from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "ecs-sg"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "myapp" {
  name        = "myapp-cluster"
  description = "ECS Cluster for running myapp Fargate tasks"
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  description = "IAM role for ECS tasks to pull images from ECR and write logs"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  description = "Attach ECS Task Execution policy to the role"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "myapp" {
  family                   = "myapp-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  description              = "Task definition for myapp container"

  container_definitions = jsonencode([
    {
      name      = "myapp"
      image     = "590183665491.dkr.ecr.us-east-1.amazonaws.com/myapp:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
    }
  ])
}

# ALB
resource "aws_lb" "myapp" {
  name               = "myapp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  description        = "Application Load Balancer to route traffic to ECS tasks"
}

# Target group for ECS
resource "aws_lb_target_group" "myapp" {
  name        = "myapp-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  description = "Target group for ECS Fargate tasks"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.myapp.arn
  port              = 80
  protocol          = "HTTP"
  description       = "HTTP listener forwarding requests to ECS target group"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.myapp.arn
  }
}

# ECS Service
resource "aws_ecs_service" "myapp" {
  name            = "myapp-service"
  cluster         = aws_ecs_cluster.myapp.id
  task_definition = aws_ecs_task_definition.myapp.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  description     = "ECS Service running myapp tasks behind ALB"

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.myapp.arn
    container_name   = "myapp"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.http]
}