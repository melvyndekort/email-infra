terraform {
  required_version = "~> 1.10"

  backend "s3" {
    bucket       = "mdekort.tfstate"
    key          = "email-infra.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.8"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  email   = data.terraform_remote_state.tf_cloudflare.outputs.cloudflare_email
  api_key = data.terraform_remote_state.tf_cloudflare.outputs.cloudflare_api_key
}

provider "grafana" {
  url  = data.terraform_remote_state.tf_grafana.outputs.grafana_url
  auth = data.terraform_remote_state.tf_grafana.outputs.email_infra_token
}
