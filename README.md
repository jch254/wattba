# Getting going with AI

A practical guide for non-engineers moving from chatting with AI to using agents
that work on files on their computer. It covers writing effective prompts, using
Claude Code, Delta and Zed, building a first website, and reviewing changes safely.

The guide is a static Astro site with a retro terminal design. Its words, links
and section order come from the [design reference](reference/guide-reference.html).
Mobile text and touch targets are enlarged where needed for readability and ease
of use.

## Repository structure

- [`guide/`](guide/) — the Astro site, including its page layout, section
  components, reusable UI components and SVG diagrams.
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
No runtime server, SSR adapter, hosting configuration, analytics or UI framework
is included. VT323 and IBM Plex Mono are loaded from Google Fonts, so loading
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

## Access gate and browser behaviour

The terminal-style access gate hashes the entered code in the browser and
remembers an unlock for the current session when session storage is available.
It is a presentation gate, **not authentication**: the static guide content and
password hash are publicly inspectable.

Client-side JavaScript is limited to the gate and code-block copy buttons. Web
Crypto and clipboard access require HTTPS or localhost. Boot typing and reveal
animations respect the browser's reduced-motion preference.
