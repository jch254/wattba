data "aws_caller_identity" "current" {}

locals {
  bucket_name = "wattba-site-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
}

module "certificate" {
  source = "github.com/jch254/terraform-modules//acm-dns-validated-certificate?ref=1.19.1"

  providers = {
    aws = aws.us_east_1
  }

  domain_name = var.site_domain
}

# The domain, rather than ACM's computed validation record name, is the stable key.
module "certificate_validation_records" {
  source = "github.com/jch254/terraform-modules//cloudflare-dns-records?ref=1.19.1"

  zone_id = var.cloudflare_zone_id
  records = {
    for domain in [var.site_domain] : domain => {
      name = one([
        for option in module.certificate.domain_validation_options :
        option.resource_record_name if option.domain_name == domain
      ])
      type = one([
        for option in module.certificate.domain_validation_options :
        option.resource_record_type if option.domain_name == domain
      ])
      content = one([
        for option in module.certificate.domain_validation_options :
        option.resource_record_value if option.domain_name == domain
      ])
      proxied = false
      ttl     = 1
    }
  }
}

resource "aws_acm_certificate_validation" "site" {
  provider = aws.us_east_1

  certificate_arn         = module.certificate.arn
  validation_record_fqdns = [for record in module.certificate_validation_records.records : record.name]
}

module "site" {
  source = "github.com/jch254/terraform-modules//web-app?ref=1.19.1"

  bucket_name       = local.bucket_name
  dns_names         = [var.site_domain]
  acm_arn           = aws_acm_certificate_validation.site.certificate_arn
  spa_fallback_path = ""
  force_destroy     = false
}

module "site_dns" {
  source = "github.com/jch254/terraform-modules//cloudflare-dns-records?ref=1.19.1"

  zone_id = var.cloudflare_zone_id
  records = {
    site = {
      name    = var.site_domain
      type    = "CNAME"
      content = module.site.cloudfront_domain_name
      proxied = false
      ttl     = 1
    }
  }
}
