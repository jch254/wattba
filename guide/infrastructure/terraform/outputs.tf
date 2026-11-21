output "site_bucket" {
  description = "Private S3 bucket used by the publish script."
  value       = module.site.s3_bucket_id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution to invalidate after publishing."
  value       = module.site.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "Cloudflare DNS-only CNAME target."
  value       = module.site.cloudfront_domain_name
}

output "site_url" {
  description = "Public guide URL."
  value       = "https://${var.site_domain}"
}

output "aws_region" {
  description = "Site bucket region for the publish script."
  value       = var.aws_region
}

output "aws_account_id" {
  description = "Account guard for the publish script."
  value       = data.aws_caller_identity.current.account_id
}

output "codebuild_project" {
  description = "CodeBuild project that deploys the deployment branch."
  value       = module.codebuild.project_name
}
