# docker-images

Homelab container-image monorepo. Dockerfiles only, no application code, no local build artifacts.
Images publish to `ghcr.io/0xd9c706e8/<app>`. Repo uses git config `0xD9C706E8`; for any `gh` CLI call use `GH_TOKEN=$(gh auth token) gh ...`.

## Layout

- `images/<app>/Dockerfile`: one directory per image. Directory name **is** the GHCR package name (workflow derives it from `basename`). Renaming a dir renames the published image.
- `images/<app>/rootfs/`: optional, copied into image via `COPY rootfs /` for images that need to ship config files.
- `.github/workflows/build.yaml`: push to `main` + scheduled + manual dispatch.
- `.github/workflows/ci.yaml`: PR validation, no push.
- `renovate.json5`: single source of truth for all version updates.

## Local dev

```bash
docker build -t <app> images/<app>/
docker run --rm <app>
```

No tests. Validation is "does it build, does it start". Local Docker without `buildx` will fail on multi-stage cross-platform `COPY --from`. CI runs `docker/setup-buildx-action` so this always works in CI.

## Local tooling

Linters and formatters run via [pre-commit](https://pre-commit.com). One-time setup:

```bash
brew install pre-commit shfmt yamllint shellcheck
pre-commit install
```

After that every `git commit` runs the full check + auto-format suite locally. CI mirrors the same hooks via `pre-commit/action` in `ci.yaml`'s `lint` job, so nothing slips through if a contributor skips the local install.

Configs live at the repo root: `.pre-commit-config.yaml`, `.prettierrc.json`, `.yamllint.yaml`, `.hadolint.yaml`.

## Per-commit verification cadence

- After every commit on a feature branch: `pre-commit run --all-files` (matches CI's lint job 1:1).
- After commits that touch `images/<app>/Dockerfile`: `docker build --platform linux/arm64 images/<app>/` smoke build (drop `DOCKER_DEFAULT_PLATFORM` if exported). Verify the binary runs (`--version` or equivalent).
- After commits that touch `.github/scripts/detect-images.sh`: probe inside `ubuntu:24.04` against every event flavour (`schedule`, `workflow_dispatch` with/without input + invalid name, `push` with workflow change/single image/zero SHA/no image, `pull_request`).

## Workflow fan-out semantics (non-obvious)

`build.yaml` matrix is built in the `detect` job:

- `workflow_dispatch` with `image` input → that image only
- `schedule` (Sunday 04:00 UTC) → all images
- `workflow_dispatch` without input → all images
- push to `main`: if `build.yaml`, `image-build.yaml`, or any script under `.github/scripts/` changed → all images; otherwise only images with changes in `git diff HEAD~1`

`ci.yaml` uses `git diff origin/<base>...HEAD` (three-dot) and rebuilds all images when either workflow file changed.

Both workflows derive the image set from `ls -d images/* | xargs basename`. Anything you put under `images/` becomes a build target. There is no allowlist.

Trivy scan runs after every push and PR build. It blocks on CRITICAL findings only (`exit-code: "1"`). When the gate fails, the blocking CRITICAL findings are surfaced inline in the GitHub Actions run summary so the failure is immediately actionable. Lower-severity findings are not surfaced; run `trivy image ghcr.io/0xd9c706e8/<app>@<digest>` locally against any published manifest to triage them. Renovate keeps base images digest-pinned, so a fresh CRITICAL CVE in an upstream layer surfaces as a red Build run that demands action: bump the base image, accept the finding via Trivy ignore policy, or rework the layer. HIGH and below are tracked by Renovate's auto-bumps and usually clear within hours of upstream releases.

## Renovate (read carefully before editing)

Two managers cover every version in this repo:

- **Custom regex manager** (`customManagers` in `renovate.json5`): matches `# renovate: datasource=X depName=Y` immediately above `ARG *_VERSION=` in any Dockerfile under `images/`. The annotation must include both `datasource=` and `depName=`; the values can be any Renovate-recognized datasource (`github-releases`, `docker`, etc.).
- **Built-in Dockerfile manager** (active via `config:best-practices`): bumps tag and digest on bare `FROM image:tag@sha256:...` lines without any annotation.

Image-specific Renovate config (custom datasources, additional managers for non-standard ARG patterns, multi-line checksum-aware updates) lands as part of the PR that introduces the image.

## Hard rules

- Registry is always `ghcr.io`. Never Docker Hub.
- Default `permissions: contents: read` at workflow level. Jobs that need more (publish, packages: write) declare it locally.
- All `uses:` action references pinned by commit SHA with a `# vN` trailing comment. Never bare tags.
- `provenance: false` on `docker/build-push-action`. Keep it.
- No `VOLUME` directives. K8s PVC mounts handle this declaratively in downstream manifests.
- Tags published: `:1`, `:1.2`, `:1.2.3`, `:latest`. Renovate downstream pins by digest.
