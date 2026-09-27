#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: bash guide/infrastructure/publish.bash [--dry-run|--publish]\n'
  printf 'Builds and checks the guide. Defaults to an S3 dry run; --publish uploads and invalidates CloudFront.\n'
}

mode="${1:---dry-run}"
if [[ "$#" -gt 1 ]]; then usage >&2; exit 2; fi
case "$mode" in
  --help|-h) usage; exit 0 ;;
  --dry-run|--publish) ;;
  *) usage >&2; exit 2 ;;
esac

site_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
terraform_dir="$site_dir/infrastructure/terraform"
profile=jch254
export AWS_PAGER=""

for tool in aws terraform pnpm; do
  command -v "$tool" >/dev/null || { printf 'Required command missing: %s\n' "$tool" >&2; exit 1; }
done

# Read destinations from the applied stack, never from arbitrary script arguments.
bucket="$(terraform -chdir="$terraform_dir" output -raw site_bucket)"
distribution="$(terraform -chdir="$terraform_dir" output -raw cloudfront_distribution_id)"
region="$(terraform -chdir="$terraform_dir" output -raw aws_region)"
account="$(terraform -chdir="$terraform_dir" output -raw aws_account_id)"
actual_account="$(aws sts get-caller-identity --profile "$profile" --query Account --output text)"
if [[ "$actual_account" != "352311918919" || "$account" != "$actual_account" || "$bucket" != "wattba-site-$account-$region" || ! "$distribution" =~ ^[A-Z0-9]+$ ]]; then
  printf 'Account or deployment target mismatch; refusing to publish.\n' >&2
  exit 1
fi

cd "$site_dir"
pnpm install --frozen-lockfile
pnpm typecheck
pnpm lint
pnpm format:check
pnpm build
test -s dist/index.html || { printf 'Build did not produce dist/index.html.\n' >&2; exit 1; }

sync_options=(--profile "$profile" --region "$region" --no-progress)
if [[ "$mode" == --dry-run ]]; then
  sync_options+=(--dryrun)
  printf 'DRY RUN: %s -> s3://%s (no upload or invalidation)\n' "$site_dir/dist" "$bucket"
else
  printf 'Publishing %s -> s3://%s\n' "$site_dir/dist" "$bucket"
fi

# Fingerprinted assets go first. Retain older assets for cached HTML and open tabs.
# Use cp rather than sync so cache headers are refreshed even for unchanged files.
aws s3 cp dist/ "s3://$bucket/" --recursive --exclude '*' --include '_astro/*' \
  --cache-control 'public,max-age=31536000,immutable' "${sync_options[@]}"
aws s3 cp dist/ "s3://$bucket/" --recursive --exclude '_astro/*' --exclude '*.html' \
  --cache-control 'public,max-age=0,must-revalidate' "${sync_options[@]}"
aws s3 cp dist/ "s3://$bucket/" --recursive --exclude '*' --include '*.html' \
  --cache-control 'public,max-age=0,must-revalidate' "${sync_options[@]}"

if [[ "$mode" == --publish ]]; then
  invalidation="$(aws cloudfront create-invalidation --profile "$profile" \
    --distribution-id "$distribution" --paths '/*' --query Invalidation.Id --output text)"
  printf 'Waiting for CloudFront invalidation %s...\n' "$invalidation"
  aws cloudfront wait invalidation-completed --profile "$profile" \
    --distribution-id "$distribution" --id "$invalidation"
  printf 'Published. Check https://wattba.site/ in a new browser session.\n'
fi
