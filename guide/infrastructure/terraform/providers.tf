provider "aws" {
  region              = var.aws_region
  profile             = "jch254"
  allowed_account_ids = ["352311918919"]

  default_tags {
    tags = {
      Project     = "wattba-site"
      Environment = "prod"
    }
  }
}

# CloudFront requires the certificate to be in us-east-1.
provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  profile             = "jch254"
  allowed_account_ids = ["352311918919"]

  default_tags {
    tags = {
      Project     = "wattba-site"
      Environment = "prod"
    }
  }
}

# Supplied locally as CLOUDFLARE_API_TOKEN, never through Terraform variables.
provider "cloudflare" {}
