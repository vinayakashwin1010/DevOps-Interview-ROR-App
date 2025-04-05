# Rails Application Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.app_name}-${var.environment}-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "${var.app_name}-${var.environment}-app-container"
    image     = "${var.ecr_repository_url}:app-${var.image_tag}"
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
    }]
    environment = [
      { name = "RAILS_ENV", value = var.rails_env },
      { name = "DATABASE_URL", value = "postgres://${var.db_username}:${var.db_password}@${var.db_host}/${var.db_name}" },
      { name = "S3_BUCKET_NAME", value = var.s3_bucket_name },
      { name = "AWS_REGION", value = var.region }
    ]
    secrets = [
      { name = "RAILS_MASTER_KEY", valueFrom = aws_ssm_parameter.rails_master_key.arn }
    ]
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name,
        "awslogs-region"        = var.region,
        "awslogs-stream-prefix" = "ecs-app"
      }
    }
  }])
}

# Nginx Task Definition
resource "aws_ecs_task_definition" "nginx" {
  family                   = "${var.app_name}-${var.environment}-nginx-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "${var.app_name}-${var.environment}-nginx-container"
    image     = "${var.ecr_repository_url}:nginx-${var.image_tag}"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name,
        "awslogs-region"        = var.region,
        "awslogs-stream-prefix" = "ecs-nginx"
      }
    }
  }])
}

# Update ECS Service to include both services
resource "aws_ecs_service" "app" {
  name            = "${var.app_name}-${var.environment}-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }
}

resource "aws_ecs_service" "nginx" {
  name            = "${var.app_name}-${var.environment}-nginx-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.id
    container_name   = "${var.app_name}-${var.environment}-nginx-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.front_end]
}