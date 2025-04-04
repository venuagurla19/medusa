# ----------------------
# Provider & Backend
# ----------------------

provider "aws" {
    region = var.region
}

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "medusa-vpc"
    }
}

resource "aws_subnet" "public" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
    availability_zone = data.aws_availability_zones.available.names[count.index]
    count             = 2
    map_public_ip_on_launch = true

    tags = {
        Name = "medusa-subnet-%{count.index}""
    }
}


resource "aws-internet_gateway" "gw" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name = "medusa-gateway"
    }
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }
    tags = {
        Name = "medusa-public-rt"
    }
}

resource "aws_route_table-association" "a" {
    count = 2
    subnet_id      = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id

}

# security Group

resource "aws_security_group" "ecs_service" {
    name        = "medusa-ecs-sg"
    description = "Allow HTTP and HTTPS"
    vpc_id      = aws_vpc.main.id

    ingress {
        from_port   = 9000
        to_port     = 9000
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# IAM roles
resource "aws_iam_role" "ecs-task_execution" {
    name        = "ecsTaskExecutionRole"
    description = "ECS Task Execution Role"

    assume_role_policy = jsonencode {
        Version = "2012-10-17",
        Statement = [{
            Action = "sts:AssumeRole",
            Effect = "Allow",
            Principal = {
                Service = "ecs-tasks.amazonaws.com"
            }
        ]}
    )}


resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
    role       = aws_iam_role.ecs_task_execution.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    }

#ECR REPO

resource "aws_ecr_repository" "medusa" {
    name = "medusa"
    image_scanning_configuration {
        scan_on_push = true
        }
    tags = {
        Name = "medusa-ecr"
    }
    }

    # ECS Cluster
#https://chatgpt.com/canvas/shared/67efc61050c081919c5cbcb4ff981949






resource "aws_ecs_cluster" "medusa" {
    name = "medusa-cluster"
    }

resource "aws_ecs_task_definition" "medusa" {
    family                = "medusa-task"
    requires_compatibilities = ["FARGATE"]
    network_mode          = "awsvpc"
    cpu                      = 512
    memory     = 1024
    container_definitions = jsonencode([{
    container_name          = "medusa-container"
    image                   = "${aws_ecr_repository.medusa.repository_url}:latest"
    portMapping = [{
        containerPort = 9000
        hostPort = 9000
        }]
    }])

execution_role_arn = aws_iam_role.ecs_task_execution.arn
task_role_arn      = aws_iam_role.ecs_task_execution.arn

}

resource "aws_ecs_service" "medusa" {
    name            = "medusa-service"
    cluster         = aws_ecs_cluster.medusa.id
    task_definition = aws_ecs_task_definition.medusa.arn
    desired_count   = 1
    launch_type = "FARGATE"

network_configuration {
    subnets = var.public_subnets
    security_groups = [aws_security_group.ecs_service.id]
    assign_public_ip = true
    }
}


