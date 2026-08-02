terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }

  # El estado se guarda en local y está excluido en .gitignore porque contiene los
  # identificadores de los recursos. Con un solo desarrollador no hace falta un backend
  # remoto; si algún día lo hubiera, aquí iría un bucket de S3 con bloqueo en DynamoDB.
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Proyecto  = "calculadora-gastos"
      Gestor    = "terraform"
      Ambiente  = var.ambiente
    }
  }
}

data "aws_caller_identity" "actual" {}

locals {
  nombre  = "calculadora-gastos"
  cuenta  = data.aws_caller_identity.actual.account_id

  # Los nombres de bucket son únicos a nivel global, de ahí el sufijo con la cuenta.
  bucket_artefactos = "${local.nombre}-artefactos-${local.cuenta}"
  bucket_web        = "${local.nombre}-web-${local.cuenta}"
}
