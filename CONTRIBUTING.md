# Contributing

Thanks for thinking about contributing. A few things that make patches easier
to land.

## What This Repo Is

Container-image monorepo. Dockerfiles only, no application code. Each image
directory under `images/` becomes a `ghcr.io/0xd9c706e8/<app>` publish target.

## Before Opening a PR

- Skim the root [README](README.md) for the project's conventions (registry,
  Renovate annotations, multi-arch, rootless, no `VOLUME`, action SHA pinning).
  The "What I optimized for" section explains the rationale.
- Run `pre-commit run --all-files`. CI runs the same suite.
- Smoke-build any Dockerfile you touched:
  `docker build --platform linux/arm64 images/<app>/`. Verify the binary
  actually runs (`--version` or equivalent).

## Conventions

- Conventional Commits. Subject ≤72 chars, imperative, no trailing period.
- One logical change per PR. Cleanup commits get squashed at merge time.
- Action references in workflows are SHA-pinned with a `# vN` trailing comment.
  Tag-pinning is rejected by review.
- Base images are digest-pinned. Renovate tracks them via the
  `# renovate: datasource=X depName=Y` annotation immediately above each
  `ARG *_VERSION=` line.

## Adding a New Image

- Create `images/<app>/Dockerfile` (build from upstream source where the
  upstream allows it).
- Add an `images/<app>/image.yaml` declaring `upstream`, `base`, `description`,
  `license`, and optionally `platforms`.
- Add a per-image `images/<app>/README.md` covering composition, volumes,
  ports, environment, security.
- If the image needs upstream-shaped Trivy ignores, add
  `images/<app>/.trivyignore` with `exp:YYYY-MM-DD` expiration dates and a
  comment explaining the revisit trigger.

The build workflow auto-discovers the directory; no allowlist edits needed.

## Code of Conduct

By participating in this project, you agree to abide by its
[Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting Security Issues

Don't open a public issue for a sensitive vulnerability. See
[SECURITY.md](SECURITY.md) for the disclosure path.
