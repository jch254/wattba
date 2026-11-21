# Getting going with AI

A practical guide for non-engineers moving from chatting with AI to using agents
that work on files on their computer. The first-build path uses Claude Code's
Plan mode and a supplied website request, with optional prompt-writing practice.
Delta's assisted review exercise lives separately at `/delta/index.html`.
The optional publishing follow-up at `/publish/index.html` uses Cloudflare Pages
Direct Upload for the reader's plain HTML/CSS portfolio, with a sourced comparison
of Vercel and Netlify. It covers public-file preparation, manual publishing,
verification, updates and recovery, plus technology selection and a generic
existing-site migration checklist and prompt. Examples are anonymous; do not add
personal attribution or identifying example-site links to the published guide.
This is reader guidance, not a change to this
repository's AWS hosting or an automatic deployment integration.
Links use the explicit HTML path so the static S3 origin does not need directory
index rewriting.

The guide is a static Astro site with a retro terminal design based on the
[original design reference](reference/guide-reference.html). Current guide content
lives in `guide/src/components/sections/`; the original export is historical.
Mobile text and touch targets are enlarged where needed for readability and ease
of use. All three pages share a sticky navigation bar with an active-page marker,
a skip link and a link to page contents. The main contents distinguish the first
build from optional follow-up pages; each follow-up has section links and return
navigation. Existing section anchors remain stable.

## Repository structure

- [`guide/`](guide/) — the Astro site, including its page layout, section
  components, reusable UI components and SVG diagrams.
- [`guide/infrastructure/`](guide/infrastructure/) — Terraform hosting, the
  CodeBuild deployment scripts and the static-file publish script.
- [`buildspec.yml`](buildspec.yml) — the CodeBuild build that deploys `main`.
- [`reference/guide-reference.html`](reference/guide-reference.html) — the original
  static design export and source of truth for content and styling.
- `example/` — a local, git-ignored Astro example used as the implementation
  pattern. It is not required to run or build the guide.

## Development

Use a current Node.js LTS release (22.13+ or 24+) and pnpm 10.32.0. From the
repository root:

```sh
cd guide
pnpm install --frozen-lockfile
pnpm dev
```

If pnpm 10.32.0 is not installed, use `npx --yes pnpm@10.32.0` in place of `pnpm`.

## Build and preview

Run these commands from `guide/`:

```sh
pnpm build
pnpm preview
```

The build produces plain static files in `guide/dist/`, including `index.html`.
No runtime server, SSR adapter, analytics or UI framework is included. VT323 and IBM Plex Mono are loaded from Google Fonts, so loading
those fonts requires an internet connection.

## Checks and formatting

Run from `guide/`:

```sh
pnpm typecheck
pnpm lint
pnpm format:check
```

Use `pnpm format` to apply formatting. The project uses Astro's strict TypeScript
settings, ESLint and Prettier.

## Deployment

Hosting uses the same pinned Terraform modules as the example: a private S3
bucket, CloudFront with Origin Access Control, an ACM certificate in `us-east-1`,
and DNS-only Cloudflare records. Only `wattba.site` is configured, not `www`.

A CodeBuild project deploys every commit that lands on `main`, so merging a
pull request is the deployment. Each build applies the Terraform stack and then
builds and publishes the guide. CodeBuild minutes, AWS storage, requests and CDN
traffic can incur charges.

| Setting               | Value                                             |
| --------------------- | ------------------------------------------------- |
| Site                  | `https://wattba.site`                             |
| AWS profile / account | `jch254` / `352311918919`                         |
| Site bucket region    | `ap-southeast-2` (Sydney)                         |
| Site bucket           | `wattba-site-352311918919-ap-southeast-2`         |
| CodeBuild project     | `wattba-site` in `ap-southeast-2`                 |
| Cloudflare token      | `/wattba-site/cloudflare-api-token` (SSM, Sydney) |
| Existing state bucket | `jch254-terraform-remote-state`                   |
| State bucket region   | `ap-southeast-4` (Melbourne)                      |
| State key             | `wattba-site/prod/terraform.tfstate`              |

### Deploy by merging to `main`

A push to `main` triggers the `wattba-site` CodeBuild project, which runs
[`buildspec.yml`](buildspec.yml):

1. Installs pnpm 10.32.0 and a checksum-verified Terraform release.
2. Runs `guide/infrastructure/ci-deploy.bash`, which checks the AWS account,
   plans and applies the Terraform stack, then runs `publish.bash --publish`.

The merge is the only approval: CI applies its own saved plan without a separate
review step. Read Terraform changes in the pull request before merging. A failed
build stops before publishing. To redeploy a commit by hand:

```sh
AWS_PROFILE=jch254 aws codebuild start-build --region ap-southeast-2 \
  --project-name wattba-site --source-version main
```

The CodeBuild role is a deployment administrator for this stack. It can change
the site bucket, CloudFront, the certificate, DNS, and its own role and project.
Protect `main`, require pull request review and never point the project at pull
request or fork code. Only pushes to the deployment branch trigger a build.

CI reads the Cloudflare token from the SSM parameter and passes it only to the
two Terraform commands. The dependency install, site build and upload never
receive it.

### One-time setup

The CodeBuild project is part of the Terraform stack, so it must be created once
with a local apply before merges can deploy.

1. Store a Cloudflare API token scoped to DNS Edit on the `wattba.site` zone.
   This keeps the token out of shell history and process arguments:

   ```sh
   read -rs CF_TOKEN  # paste the token and press Enter; nothing is shown
   printf '%s' "$CF_TOKEN" | AWS_PROFILE=jch254 aws ssm put-parameter \
     --region ap-southeast-2 --name /wattba-site/cloudflare-api-token \
     --type SecureString --value file:///dev/stdin
   unset CF_TOKEN
   ```

2. In the AWS console, connect CodeBuild in `ap-southeast-2` to GitHub with
   access to `jch254/wattba`. Creating the webhook fails without it. To create
   the project first and add the webhook later, set `enable_webhook = false`.
3. Apply the stack locally as described below. The plan should only add the
   CodeBuild project, its log group, role, policies and webhook.
4. Protect `main` on GitHub and require pull request review.

### Provision or update infrastructure locally

Install Terraform 1.10+, AWS CLI v2 and pnpm 10.32.0. CI pins Terraform 1.15.6
in `guide/infrastructure/install-terraform.bash`; keep local and CI versions in
step. No AWS profile is hardcoded, so that CodeBuild can use its service role.
Export `AWS_PROFILE=jch254` locally; the providers reject any other account.
The backend uses native S3 state locking: your identity needs access to the
state object and permission to create/delete its `.tflock` object. The existing
state bucket is not managed by this stack; keep versioning enabled for state
recovery.

Supply `CLOUDFLARE_API_TOKEN` to Terraform from your local secret manager or
secure shell environment. Scope the token to DNS Edit on the `wattba.site` zone.
Do not put credentials in Terraform variables, backend configuration, scripts,
commits or command-line arguments. If using Varlock, run Terraform through
`varlock run --` from your configured secret environment.

From the repository root:

```sh
export AWS_PROFILE=jch254
# -reconfigure is needed once, because the backend no longer names a profile.
terraform -chdir=guide/infrastructure/terraform init -reconfigure
terraform -chdir=guide/infrastructure/terraform fmt -check
terraform -chdir=guide/infrastructure/terraform validate
terraform -chdir=guide/infrastructure/terraform plan -out=site.tfplan
```

Review the plan before applying. In particular, check DNS changes and confirm
there are no unexpected deletions. If an apex DNS record was created outside
this stack, resolve ownership/import it before applying; do not blindly remove
it. The first apply waits for certificate validation and CloudFront deployment,
which can take several minutes. The site will not serve content until published.

```sh
terraform -chdir=guide/infrastructure/terraform apply site.tfplan
```

The saved plan is git-ignored and should be removed after use. Commit the
Terraform provider lockfile (`.terraform.lock.hcl`), but never local state or
plan files. The site bucket cannot be destroyed while it contains objects.

Avoid merging to `main` while applying locally; both use the same state lock.
CodeBuild cannot grant itself permissions it does not already have. When a
change needs new permissions for the deployment role, apply it locally first.

### Publish the guide locally

Merging to `main` publishes the guide. To publish by hand instead, run from the
repository root after applying the stack:

```sh
export AWS_PROFILE=jch254

# Builds and checks the site, then previews uploads without changing AWS.
bash guide/infrastructure/publish.bash

# Explicitly upload the build and wait for CloudFront cache invalidation.
bash guide/infrastructure/publish.bash --publish
```

The script reads the bucket and distribution from Terraform outputs, verifies
the AWS account, installs locked dependencies, runs checks and builds the site.
It uploads fingerprinted assets before HTML, caches only `_astro/` assets for a
year, and marks other files for revalidation. The example's CloudFront cache
policy has a minimum TTL of one second; the publish step invalidates cached
responses and waits for completion. Old files are deliberately retained so open
tabs and cached HTML can still load previous assets; uploads overwrite matching
keys but never delete unrelated or older objects. This is not an atomic release.

Publishing needs AWS credentials only, not the Cloudflare token. After publishing,
check `https://wattba.site/` in a fresh browser session.
To roll back, revert the change on `main`, or build and publish a previous
source revision by hand. The hosting stack is applied and serving the site. The
CodeBuild deployment has been validated locally only (format, validate and a
mocked plan); it has not been applied or run.

## Browser behaviour

The guide is open to anyone with the link. Client-side
JavaScript is limited to the code-block copy buttons. Clipboard access requires
HTTPS or localhost. Animations respect the browser's reduced-motion preference.
