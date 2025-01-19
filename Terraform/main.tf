provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "subnet1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "ecs_security_group" {
  name        = "ecs_security_group"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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

resource "aws_ecr_repository" "spring_boot_app" {
  name = "spring-boot-app"
}

resource "aws_ecs_cluster" "main" {
  name = "ecs-cluster"
}

resource "aws_ecs_task_definition" "spring_boot_task" {
  family                = "spring-boot-app-task"
  cpu                   = "512"
  memory                = "1024"
  network_mode          = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn         = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "spring-boot-container"
    image     = "aws_account_id.dkr.ecr.us-east-1.amazonaws.com/spring-boot-app:latest"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    }]
  }])
}

resource "aws_security_group" "ecs_service_sg" {
  name_prefix = "ecs-service-sg"
  vpc_id      = aws_vpc.main.id
}

resource "aws_lb" "application_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups   = [aws_security_group.ecs_security_group.id]
  subnets            = [aws_subnet.subnet1.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "ecs_target_group" {
  name     = "ecs-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.application_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      status_code = 200
      content_type = "text/plain"
      message_body = "OK"
    }
  }
}
