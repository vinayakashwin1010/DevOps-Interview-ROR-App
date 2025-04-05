terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-state-bucket" # Replace with your bucket
    key            = "rails-app/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table"
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "./modules/networking"

  app_name            = var.app_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones  = var.availability_zones
}

module "ecr" {
  source = "./modules/ecr"

  app_name    = var.app_name
  environment = var.environment
}

module "s3" {
  source = "./modules/s3"

  app_name    = var.app_name
  environment = var.environment
}

module "rds" {
  source = "./modules/rds"

  app_name                = var.app_name
  environment             = var.environment
  vpc_id                  = module.networking.vpc_id
  private_subnet_ids      = module.networking.private_subnet_ids
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
  db_instance_class       = var.db_instance_class
  db_allocated_storage    = var.db_allocated_storage
  db_engine_version       = var.db_engine_version
  db_parameter_group_name = var.db_parameter_group_name
  db_backup_retention_period = var.db_backup_retention_period
  db_backup_window        = var.db_backup_window
  db_maintenance_window   = var.db_maintenance_window
}

module "ecs" {
  source = "./modules/ecs"

  app_name             = var.app_name
  environment          = var.environment
  vpc_id               = module.networking.vpc_id
  public_subnet_ids    = module.networking.public_subnet_ids
  private_subnet_ids   = module.networking.private_subnet_ids
  ecr_repository_url   = module.ecr.repository_url
  db_host              = module.rds.db_host
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  s3_bucket_name       = module.s3.bucket_name
  region               = var.aws_region
  cpu                  = var.ecs_cpu
  memory               = var.ecs_memory
  desired_count        = var.ecs_desired_count
  container_port       = var.container_port
  alb_port             = var.alb_port
  health_check_path    = var.health_check_path
  rails_master_key     = var.rails_master_key
  rails_env            = var.rails_env
}

module "jenkins" {
    source = "./modules/jenkins"
  
    app_name          = var.app_name
    environment       = var.environment
    vpc_id           = module.networking.vpc_id
    public_subnet_id = module.networking.public_subnet_ids[0]
    key_name         = var.jenkins_key_name
    instance_type    = var.jenkins_instance_type
  }