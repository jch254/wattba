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
of use.

## Repository structure

- [`guide/`](guide/) — the Astro site, including its page layout, section
  components, reusable UI components and SVG diagrams.
- [`guide/infrastructure/`](guide/infrastructure/) — manual Terraform hosting and
  a separate static-file publish script; no CodeBuild or automatic deployments.
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

## Manual deployment

Hosting uses the same pinned Terraform modules as the example: a private S3
bucket, CloudFront with Origin Access Control, an ACM certificate in `us-east-1`,
and DNS-only Cloudflare records. Only `wattba.site` is configured, not `www`.
There is no CodeBuild, webhook, deployment role or automatic apply. AWS storage,
requests and CDN traffic can incur charges.

| Setting               | Value                                     |
| --------------------- | ----------------------------------------- |
| Site                  | `https://wattba.site`                     |
| AWS profile / account | `jch254` / `352311918919`                 |
| Site bucket region    | `ap-southeast-2` (Sydney)                 |
| Site bucket           | `wattba-site-352311918919-ap-southeast-2` |
| Existing state bucket | `jch254-terraform-remote-state`           |
| State bucket region   | `ap-southeast-4` (Melbourne)              |
| State key             | `wattba-site/prod/terraform.tfstate`      |

### Provision or update infrastructure

Install Terraform 1.10+, AWS CLI v2 and pnpm 10.32.0. Authenticate the `jch254`
AWS profile using your usual local credential workflow. The backend uses native
S3 state locking: your identity needs access to the state object and permission
to create/delete its `.tflock` object. The existing state bucket is not managed
by this stack; keep versioning enabled for state recovery.

Supply `CLOUDFLARE_API_TOKEN` to Terraform from your local secret manager or
secure shell environment. Scope the token to DNS Edit on the `wattba.site` zone.
Do not put credentials in Terraform variables, backend configuration, scripts,
commits or command-line arguments. If using Varlock, run Terraform through
`varlock run --` from your configured secret environment.

From the repository root:

```sh
terraform -chdir=guide/infrastructure/terraform init
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

### Publish the guide

After applying the stack, run from the repository root:

```sh
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
check `https://wattba.site/` in a fresh browser session and try the access gate.
To roll back, build and publish a previous source revision through the same
manual workflow. This infrastructure has been locally validated, not applied.

## Access gate and browser behaviour

The terminal-style access gate hashes the entered code in the browser and
remembers an unlock for the current session when session storage is available.
It is a presentation gate, **not authentication**: the static guide content and
password hash are publicly inspectable.

Client-side JavaScript is limited to the gate and code-block copy buttons. Web
Crypto and clipboard access require HTTPS or localhost. Boot typing and reveal
animations respect the browser's reduced-motion preference.
