#!/usr/bin/env bash
# CodeBuild entrypoint: applies the Terraform stack, then publishes the guide.
# Never enable tracing here; the Cloudflare token passes through this shell.
set +x
set -euo pipefail

: "${CODEBUILD_BUILD_ID:?Run this entrypoint only in CodeBuild}"

infrastructure_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
terraform_dir="$infrastructure_dir/terraform"
plan=ci.tfplan
export AWS_PAGER="" TF_IN_AUTOMATION=1
# CI always uses the stored token, never one inherited from the project or a start-build override.
unset CLOUDFLARE_API_TOKEN TF_LOG TF_LOG_PATH TF_LOG_CORE TF_LOG_PROVIDER

account="$(aws sts get-caller-identity --query Account --output text)"
if [[ "$account" != 352311918919 ]]; then
  printf 'Refusing to deploy outside account 352311918919.\n' >&2
  exit 1
fi

trap 'rm -f "$terraform_dir/$plan"' EXIT
terraform -chdir="$terraform_dir" init -input=false -lockfile=readonly

# Not exported: only the two Terraform commands below receive the token, so the
# site's dependency install, build and upload never see it.
cloudflare_token="$(aws ssm get-parameter --region ap-southeast-2 \
  --name /wattba-site/cloudflare-api-token --with-decryption \
  --query Parameter.Value --output text)"
CLOUDFLARE_API_TOKEN="$cloudflare_token" terraform -chdir="$terraform_dir" \
  plan -input=false -lock-timeout=5m -out="$plan"
# A merge to the deployment branch is the approval for this saved plan.
CLOUDFLARE_API_TOKEN="$cloudflare_token" terraform -chdir="$terraform_dir" \
  apply -input=false -lock-timeout=5m "$plan"
unset cloudflare_token

bash "$infrastructure_dir/publish.bash" --publish
