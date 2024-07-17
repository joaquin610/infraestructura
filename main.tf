terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.56.0"
    }
  }
  required_version = ">= 1.8.5"
}
variable "aws_access_key" {
  description = "AWS access key"
}

variable "aws_secret_key" {
  description = "AWS secret key"
}

variable "aws_session_token" {
  description = "AWS session token"
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  token      = var.aws_session_token
  region     = "us-east-1"
}





# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main VPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Subnet 1
resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Subnet 1"
  }
}

# Subnet 2
resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Subnet 2"
  }
}

# Associate Route Table with Subnets
resource "aws_route_table_association" "subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "subnet2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "allow_http" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

# ECS Service
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Allow HTTP Security Group"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "main-ecs-cluster"
}

# ECS Task Definition 
resource "aws_ecs_task_definition" "taskProducts" {
  family                   = "products-service"
  container_definitions    = jsonencode([
    {
      name  = "app"
      image = "banchero/be_products_service"
      memory = 512
      cpu    = 256
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  task_role_arn            = "arn:aws:iam::715200188486:role/LabRole"
  execution_role_arn       = "arn:aws:iam::715200188486:role/LabRole"
}

resource "aws_ecs_task_definition" "taskOrders" {
  family                   = "orders-service"
  container_definitions    = jsonencode([
    {
      name  = "app"
      image = "banchero/be_orders_service" 
      memory = 512
      cpu    = 256
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  task_role_arn            = "arn:aws:iam::715200188486:role/LabRole"
  execution_role_arn       = "arn:aws:iam::715200188486:role/LabRole"
}

resource "aws_ecs_task_definition" "taskPayment" {
  family                   = "payment-service"
  container_definitions    = jsonencode([
    {
      name  = "app"
      image = "banchero/be_payment_service" 
      memory = 512
      cpu    = 256
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  task_role_arn            = "arn:aws:iam::715200188486:role/LabRole"
  execution_role_arn       = "arn:aws:iam::715200188486:role/LabRole"
}

resource "aws_ecs_task_definition" "taskShipping" {
  family                   = "shipping-service"
  container_definitions    = jsonencode([
    {
      name  = "app"
      image = "banchero/be_shipping_service" 
      memory = 512
      cpu    = 256
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  task_role_arn            = "arn:aws:iam::715200188486:role/LabRole"
  execution_role_arn       = "arn:aws:iam::715200188486:role/LabRole"
}


resource "aws_ecs_service" "service" {
  count            = 4
  name             = element(["BE_Orders_Service", "BE_Shipping_Service", "BE_Products_Service", "BE_Payments_Service"], count.index)
  cluster          = aws_ecs_cluster.main.id
  task_definition  = element([aws_ecs_task_definition.taskOrders.arn, aws_ecs_task_definition.taskShipping.arn, aws_ecs_task_definition.taskProducts.arn, aws_ecs_task_definition.taskPayment.arn], count.index)
  desired_count    = 1
  launch_type      = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
    security_groups = [aws_security_group.allow_http.id]
    assign_public_ip = true
  }

  force_new_deployment = true
  tags = {
    Name   = element(["BE_Orders_Service", "BE_Shipping_Service", "BE_Products_Service", "BE_Payments_Service"], count.index)
    Origin = "Terraform"
  }
}

# S3 Bucket
resource "aws_s3_bucket" "FE_react" {
  bucket = "fe-react-bucket"
  acl    = "private"
  tags = {
    Name = "FE_react"
  }
}

# en caso de querer acceder al fe del forma publica descomentar esto
# comentado de momento por motivos de seguridad
# resource "aws_s3_bucket_public_access_block" "FE_react" {
#   bucket = aws_s3_bucket.FE_react.id

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# ECR Repositories
# como furuta mejora podriamos pasar de almacenar las img en docker a aws
resource "aws_ecr_repository" "orders_repo" {
  name = "orders-service-repo"
  tags = {
    Name = "Orders Service Repo"
  }
}

resource "aws_ecr_repository" "shipping_repo" {
  name = "shipping-service-repo"
  tags = {
    Name = "Shipping Service Repo"
  }
}

resource "aws_ecr_repository" "products_repo" {
  name = "products-service-repo"
  tags = {
    Name = "Products Service Repo"
  }
}

resource "aws_ecr_repository" "payments_repo" {
  name = "payments-service-repo"
  tags = {
    Name = "Payments Service Repo"
  }
}
