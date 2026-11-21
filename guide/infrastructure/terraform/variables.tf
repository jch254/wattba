variable "aws_region" {
  description = "AWS region for the static site bucket (the state bucket is separate)."
  type        = string
  default     = "ap-southeast-2"
}

variable "site_domain" {
  description = "Public hostname of the guide."
  type        = string
  default     = "wattba.site"
}

variable "cloudflare_zone_id" {
  description = "Existing wattba.site zone in the user's Cloudflare account."
  type        = string
  default     = "aeb76be43e751d19fd89a4269a310222"
}

variable "enable_webhook" {
  description = "Deploy automatically when a commit lands on the deployment branch. Needs CodeBuild's GitHub connection in this region."
  type        = bool
  default     = true
}

variable "deployment_branch" {
  description = "Branch whose commits CodeBuild deploys."
  type        = string
  default     = "main"
}
