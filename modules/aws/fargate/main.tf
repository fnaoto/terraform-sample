# ECS Cluster

resource "aws_ecs_cluster" "fargate" {
  name = var.name
}

## ECS Service

resource "aws_ecs_service" "fargate" {
  name            = var.name
  cluster         = aws_ecs_cluster.fargate.id
  task_definition = aws_ecs_task_definition.fargate.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_groups
    assign_public_ip = var.assign_public_ip
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

## ECS Task

resource "aws_ecs_task_definition" "fargate" {
  family                   = var.name
  container_definitions    = data.template_file.fargate.rendered
  task_role_arn            = aws_iam_role.fargate.arn
  execution_role_arn       = aws_iam_role.fargate.arn
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  requires_compatibilities = ["FARGATE"]
  tags                     = var.tags
}

data "template_file" "fargate" {
  template = var.container_definitions
  vars     = var.container_definitions_vars
}

## CloudWatch logs

resource "aws_cloudwatch_log_group" "fargate" {
  name = var.log_group_name
  tags = var.tags
}

## IAM

resource "aws_iam_role" "fargate" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume_policy.json
  tags               = var.tags
}

data "aws_iam_policy_document" "assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "task_execution_role_policy" {
  role       = aws_iam_role.fargate.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "fargate" {
  role       = aws_iam_role.fargate.name
  policy_arn = aws_iam_policy.fargate.arn
}

resource "aws_iam_policy" "fargate" {
  name   = "${var.name}_fargate"
  policy = data.aws_iam_policy_document.fargate.json
}

data "aws_iam_policy_document" "fargate" {
  statement {
    actions = [
      "kms:Decrypt",
      "secretsmanager:GetSecretValue",
      "ssm:*",
      "iam:PassRole",
    ]

    resources = [
      "*",
    ]
  }
}

