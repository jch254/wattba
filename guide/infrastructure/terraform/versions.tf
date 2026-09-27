terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "jch254-terraform-remote-state"
    key          = "wattba-site/prod/terraform.tfstate"
    region       = "ap-southeast-4"
    profile      = "jch254"
    encrypt      = true
    use_lockfile = true
  }
}
