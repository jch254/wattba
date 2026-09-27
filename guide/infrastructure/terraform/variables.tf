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
