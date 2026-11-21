locals {
  project_name = "wattba-site"
  account_id   = data.aws_caller_identity.current.account_id
  state_arn    = "arn:aws:s3:::jch254-terraform-remote-state/wattba-site/prod/terraform.tfstate"
  # Provisioned out of band as a SecureString; never managed or read by Terraform.
  cloudflare_token_arn = "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/wattba-site/cloudflare-api-token"
}

# CodeBuild is a deployment administrator for this stack: it can change its own
# role and project. Only reviewed commits on the deployment branch may run it.
module "codebuild_role" {
  source = "github.com/jch254/terraform-modules//codebuild-terraform-role?ref=1.19.1"

  name           = local.project_name
  s3_bucket_arns = ["arn:aws:s3:::jch254-terraform-remote-state"]
  s3_object_arns = [
    "${local.state_arn}.tflock",
    "arn:aws:s3:::${local.bucket_name}/*",
  ]
  prefix_managed_services = ["iam_role"]
  codebuild_project_arns  = ["arn:aws:codebuild:${var.aws_region}:${local.account_id}:project/${local.project_name}"]
  enable_acm              = true
  acm_resource_arns       = ["arn:aws:acm:us-east-1:${local.account_id}:certificate/*"]
}

resource "aws_iam_role_policy" "deployment" {
  name = "${local.project_name}-deployment"
  role = module.codebuild_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = [local.state_arn]
      },
      {
        # Includes the read-only calls the AWS provider makes when refreshing a bucket.
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketOwnershipControls",
          "s3:PutBucketOwnershipControls",
          "s3:DeleteBucketOwnershipControls",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetBucketAcl",
          "s3:GetBucketCORS",
          "s3:GetBucketWebsite",
          "s3:GetBucketVersioning",
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketLogging",
          "s3:GetLifecycleConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:GetBucketObjectLockConfiguration",
        ]
        Resource = ["arn:aws:s3:::${local.bucket_name}"]
      },
      {
        # CloudFront create and tagging calls do not support narrower resources.
        Effect = "Allow"
        Action = [
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:CreateDistribution",
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",
          "cloudfront:TagResource",
          "cloudfront:UntagResource",
          "cloudfront:ListTagsForResource",
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:GetOriginAccessControl",
          "cloudfront:CreateOriginAccessControl",
          "cloudfront:UpdateOriginAccessControl",
          "cloudfront:DeleteOriginAccessControl",
        ]
        Resource = ["*"]
      },
    ]
  })
}

# Read-only. Keep this ARN out of the role module's ssm_parameter_arns, which
# would also grant writes and deletes.
resource "aws_iam_role_policy" "cloudflare_token_read" {
  name = "${local.project_name}-cloudflare-token-read"
  role = module.codebuild_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = [local.cloudflare_token_arn]
    }]
  })
}

module "codebuild" {
  source = "github.com/jch254/terraform-modules//codebuild-project?ref=1.19.1"

  name                        = local.project_name
  description                 = "Applies the wattba.site Terraform stack and publishes the guide"
  codebuild_role_arn          = module.codebuild_role.role_arn
  build_compute_type          = "BUILD_GENERAL1_SMALL"
  build_docker_image          = "aws/codebuild/standard"
  build_docker_tag            = "7.0"
  image_pull_credentials_type = "CODEBUILD"
  source_type                 = "GITHUB"
  source_location             = "https://github.com/jch254/wattba.git"
  buildspec                   = "buildspec.yml"
  git_clone_depth             = 1
  badge_enabled               = false
  log_retention               = 7
  webhook_enabled             = var.enable_webhook
  webhook_filter_groups = [[
    { type = "EVENT", pattern = "PUSH" },
    { type = "HEAD_REF", pattern = "^refs/heads/${var.deployment_branch}$" },
  ]]
  # CI plans with the same settings as the local apply that created the project.
  environment_variables = [
    { name = "TF_VAR_enable_webhook", value = tostring(var.enable_webhook) },
    { name = "TF_VAR_deployment_branch", value = var.deployment_branch },
  ]

  depends_on = [
    aws_iam_role_policy.deployment,
    aws_iam_role_policy.cloudflare_token_read,
  ]
}
