resource "aws_ecr_repository" "myapp" {
  name = "myapp"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "myapp-ecr"
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "myapp-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "myapp-igw"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "private-subnet-2"
  }
}


resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "myapp-nat"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route" "private_internet" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# Public
resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Private
resource "aws_route_table_association" "private_1_assoc" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_2_assoc" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Allow traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-sg"
  }
}

resource "aws_ecs_cluster" "myapp" {
  name = "myapp-cluster"
}

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
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "myapp" {
  family                   = "myapp-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"   # Minimum Fargate CPU
  memory                   = "512"   # Minimum Fargate Memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

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

resource "aws_lb" "myapp" {
  name               = "myapp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "myapp" {
  name        = "myapp-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.myapp.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.myapp.arn
  }
}

resource "aws_ecs_service" "myapp" {
  name            = "myapp-service"
  cluster         = aws_ecs_cluster.myapp.id
  task_definition = aws_ecs_task_definition.myapp.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
  subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id] # Private subnets
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