provider "aws" {
  region = "${var.region}"
}

terraform {
  required_version = "~> 0.12.7"
}

module "ecr_ssh" {
  source = "../modules/ecr"
  name   = "${var.project}/${local.ws}/ecr_ssh"
}

module "fargate_ssh" {
  source                = "../modules/fargate_ssh"
  name                  = "${local.name}-fargate_ssh"
  subnets               = "${module.subnet.private_subnet_ids}"
  security_groups       = ["${module.sg_deny_ingress.id}"]
  assign_public_ip      = false
  task_cpu              = 512
  task_memory           = 1024
  log_group_name        = "/aws/ecs/${var.project}/${local.ws}/fargate_ssh"
  tags                  = "${local.tags}"
  container_definitions = "${file("task-definitions/fargate_ssh.json")}"

  container_definitions_vars = {
    DOCKER_IMAGE_URL = "${module.ecr_ssh.repository_url}"
    SSM_AGENT_CODE   = "${module.secret_activations_code.arn}"
    SSM_AGENT_ID     = "${module.secret_activations_id.arn}"
    AWS_LOGS_GROUP   = "/aws/ecs/${var.project}/${local.ws}/fargate_ssh"
    AWS_LOGS_REGION  = "${var.region}"
    AWS_REGION       = "${var.region}"
    IAM_ROLE         = "${module.ssm_activations.role_name}"
  }
}

module "sg_deny_ingress" {
  source              = "../modules/sg"
  name                = "${local.name}_deny_ingress"
  vpc_id              = "${module.vpc.vpc_id}"
  ingress_port        = 0
  tags                = "${local.tags}"
}

module "secret_activations_code" {
  source        = "../modules/secrets_manager"
  name          = "${var.project}/${local.ws}/activations_code"
  secret_string = "${module.ssm_activations.code}"
}

module "secret_activations_id" {
  source        = "../modules/secrets_manager"
  name          = "${var.project}/${local.ws}/activations_id"
  secret_string = "${module.ssm_activations.id}"
}

module "ssm_activations" {
  source = "../modules/ssm_activations"
  name   = "${local.name}-ssm-activations"
}

module "subnet" {
  source     = "../modules/subnet"
  vpc_id     = "${module.vpc.vpc_id}"
  vpc_cidr   = "${module.vpc.cidr_block}"
  gateway_id = "${module.vpc.gateway_id}"
  tags       = "${local.tags}"
}

module "vpc" {
  source               = "../modules/vpc"
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  tags                 = "${local.tags}"
}

module "vpc_endpoint" {
  source                  = "../modules/vpc_endpoint"
  region                  = "${var.region}"
  vpc_id                  = "${module.vpc.vpc_id}"
  subnet_ids              = "${module.subnet.private_subnet_ids}"
  security_group_ids      = ["${module.sg_443.id}"]
  private_route_table_ids = "${module.subnet.private_route_table_ids}"
  tags                    = "${local.tags}"
}

module "sg_443" {
  source              = "../modules/sg"
  name                = "${local.name}_443"
  vpc_id              = "${module.vpc.vpc_id}"
  ingress_port        = 443
  ingress_cidr_blocks = ["0.0.0.0/0"]
  tags                = "${local.tags}"
}