#!/usr/bin/env bash
# CodeBuild only: installs a checksum-verified Terraform release.
set -euo pipefail

: "${CODEBUILD_BUILD_ID:?Run this script only in CodeBuild}"

# Matches the version that wrote the shared state locally.
version=1.15.6
archive="terraform_${version}_linux_amd64.zip"
# CodeBuild standard:7.0 is x86_64.
test "$(uname -m)" = x86_64

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
cd "$work_dir"

curl --fail --silent --show-error --location --retry 3 --max-time 120 \
  "https://releases.hashicorp.com/terraform/$version/$archive" -o "$archive"
curl --fail --silent --show-error --location --retry 3 --max-time 120 \
  "https://releases.hashicorp.com/terraform/$version/terraform_${version}_SHA256SUMS" -o checksums
grep " $archive\$" checksums | sha256sum --check --strict
unzip -q "$archive" terraform
install -m 0755 terraform /usr/local/bin/terraform
terraform version
