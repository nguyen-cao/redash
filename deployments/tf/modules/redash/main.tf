provider "aws" {
  region  = var.aws_region
  profile = var.profile
}

provider "doppler" {
  doppler_token = var.doppler_token
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["${var.client}-vpc"]
  }
}

data "aws_subnet_ids" "public_subnets" {
  vpc_id = data.aws_vpc.vpc.id
  filter {
    name   = "tag:Name"
    values = ["${var.client}-public-subnet"]
  }
}

data "aws_subnet" "public_subnets" {
  for_each = data.aws_subnet_ids.public_subnets.ids
  id       = each.value
}

data "aws_subnet_ids" "private_subnets" {
  vpc_id = data.aws_vpc.vpc.id
  filter {
    name   = "tag:Name"
    values = ["${var.client}-private-subnet"]
  }
}

data "aws_subnet" "private_subnets" {
  for_each = data.aws_subnet_ids.private_subnets.ids
  id       = each.value
}

data "aws_iam_role" "ecs_iam_assumable_role" {
  name = "${var.client}-ecs-role"
}

data "aws_iam_role" "ecs_execution_iam_assumable_role" {
  name = "${var.client}-ecs-execution-role"
}

data "aws_elasticache_cluster" "redis" {
  cluster_id = "${var.client}-${var.team}-redis"
}

data "aws_db_instance" "postgres" {
  db_instance_identifier = "${var.client}-${var.team}-postgres"
}

data "aws_ecr_repository" "redash" {
  name = "${var.client}-${var.team}/redash"
}

data "aws_security_group" "postgresql_sg" {
  vpc_id = data.aws_vpc.vpc.id
  filter {
    name   = "tag:Name"
    values = ["${var.client}-${var.team}-postgres-sg"]
  }
}

data "aws_security_group" "redis_sg" {
  vpc_id = data.aws_vpc.vpc.id
  filter {
    name   = "tag:Name"
    values = ["${var.client}-${var.team}-redis-sg"]
  }
}

data "doppler_secrets" "postgres" {
  config = var.environment
  project = "${var.team}-postgres"
}

## CloudWatch
resource "aws_cloudwatch_log_group" "app" {
  name = "${var.client}/${var.team}/${var.app}-cloudwatch"
}

## ECS
data "aws_ecs_cluster" "cluster" {
  cluster_name = "${var.client}-${var.environment}"
}

module "ecs_sg" {
  source = "github.com/nguyen-cao/terraform-aws-security-group.git"

  name        = "${var.client}-${var.team}-${var.app}-ecs-sg"
  description = "Security group with ports open for load balancer, egress ports are all world open"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_cidr_blocks = [for subnet in data.aws_subnet.private_subnets : subnet.cidr_block]
  ingress_rules            = ["all-tcp"]
  ingress_with_source_security_group_id = [
    {
      source_security_group_id = module.alb_sg.security_group_id
      from_port                = tonumber(var.app_port)
      to_port                  = tonumber(var.app_port)
      protocol                 = "tcp"
      description              = "${var.app} port"
    }
  ]
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules      = ["all-tcp"]
  tags = {
    Name = "${var.client}-${var.team}-${var.app}-ecs-sg"
  }
}

resource "aws_ecs_task_definition" "redash_server" {
  family                   = "${var.client}-${var.team}-${var.app}-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 4096
  memory                   = 8192
  execution_role_arn       = data.aws_iam_role.ecs_execution_iam_assumable_role.arn
  container_definitions = templatefile("${path.module}/task-definition-server.json",
    {
      image_url        = "${data.aws_ecr_repository.redash.repository_url}:${var.image_tag}"
      redis_url = "redis://${data.aws_elasticache_cluster.redis.cache_nodes.0.address}:${data.aws_elasticache_cluster.redis.cache_nodes.0.port}/0"
      database_url = "postgresql://${data.aws_db_instance.postgres.master_username}:${data.doppler_secrets.postgres.map.DB_PASSWORD}@${data.aws_db_instance.postgres.endpoint}/${data.aws_db_instance.postgres.db_name}"
      container_name   = "${var.client}-${var.team}-${var.app}-server"
      container_command   = "server"
      log_group_region = var.aws_region
      log_group_name   = aws_cloudwatch_log_group.app.name
      log_stream_name   = "ecs"
    }
  )
}

resource "aws_ecs_task_definition" "redash_scheduler" {
  family                   = "${var.client}-${var.team}-${var.app}-scheduler"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = data.aws_iam_role.ecs_execution_iam_assumable_role.arn
  container_definitions = templatefile("${path.module}/task-definition-scheduler.json",
    {
      image_url        = "${data.aws_ecr_repository.redash.repository_url}:${var.image_tag}"
      redis_url = "redis://${data.aws_elasticache_cluster.redis.cache_nodes.0.address}:${data.aws_elasticache_cluster.redis.cache_nodes.0.port}/0"
      database_url = "postgresql://${data.aws_db_instance.postgres.master_username}:${data.doppler_secrets.postgres.map.DB_PASSWORD}@${data.aws_db_instance.postgres.endpoint}/${data.aws_db_instance.postgres.db_name}"
      container_name   = "${var.client}-${var.team}-${var.app}-scheduler"
      container_command   = "scheduler"
      log_group_region = var.aws_region
      log_group_name   = aws_cloudwatch_log_group.app.name
      log_stream_name   = "ecs"
    }
  )
}

resource "aws_ecs_task_definition" "redash_worker" {
  family                   = "${var.client}-${var.team}-${var.app}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = data.aws_iam_role.ecs_execution_iam_assumable_role.arn
  container_definitions = templatefile("${path.module}/task-definition-worker.json",
    {
      image_url        = "${data.aws_ecr_repository.redash.repository_url}:${var.image_tag}"
      redis_url = "redis://${data.aws_elasticache_cluster.redis.cache_nodes.0.address}:${data.aws_elasticache_cluster.redis.cache_nodes.0.port}/0"
      database_url = "postgresql://${data.aws_db_instance.postgres.master_username}:${data.doppler_secrets.postgres.map.DB_PASSWORD}@${data.aws_db_instance.postgres.endpoint}/${data.aws_db_instance.postgres.db_name}"
      container_name   = "${var.client}-${var.team}-${var.app}-worker"
      container_command   = "worker"
      log_group_region = var.aws_region
      log_group_name   = aws_cloudwatch_log_group.app.name
      log_stream_name   = "ecs"
    }
  )
}

resource "aws_ecs_service" "redash_server" {
  name            = "${var.client}-${var.team}-${var.app}-server-service"
  cluster         = data.aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.redash_server.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = [for subnet in data.aws_subnet.private_subnets : subnet.id]
    security_groups = [module.ecs_sg.security_group_id]
  }

  load_balancer {
    target_group_arn = module.alb.target_group_arns[0]
    container_name   = "${var.client}-${var.team}-${var.app}-server"
    container_port   = "5000"
  }

  depends_on = [
    data.aws_db_instance.postgres,
    data.aws_elasticache_cluster.redis,
    data.aws_iam_role.ecs_iam_assumable_role,
    module.alb
  ]
}

resource "aws_ecs_service" "redash_scheduler" {
  name            = "${var.client}-${var.team}-${var.app}-scheduler-service"
  cluster         = data.aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.redash_scheduler.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = [for subnet in data.aws_subnet.private_subnets : subnet.id]
  }

  depends_on = [
    aws_ecs_service.redash_server
  ]
}

resource "aws_ecs_service" "redash_worker" {
  name            = "${var.client}-${var.team}-${var.app}-worker-service"
  cluster         = data.aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.redash_worker.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = [for subnet in data.aws_subnet.private_subnets : subnet.id]
  }

  depends_on = [
    aws_ecs_service.redash_server
  ]
}