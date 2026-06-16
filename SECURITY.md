# Security Policy

## Supported Versions

Only the `:latest` tag and the most recent semver-aligned tags (`:N`, `:N.M`,
`:N.M.P`) for each image are supported. Older tags remain available on GHCR
but receive no security updates beyond what upstream image rebuilds carry.

## Reporting a Vulnerability

For sensitive disclosures, please use GitHub's
[private vulnerability reporting](https://github.com/0xD9C706E8/docker-images/security/advisories/new).
Response within a week is typical.

For non-sensitive issues (e.g. a CVE that's already publicly disclosed
upstream and just needs a base-image bump), opening a regular issue with the
CVE ID and affected image is fine.

## What's In Scope

- The Dockerfiles, workflows, and scripts in this repository.
- Misconfigurations in the build pipeline that could lead to image tampering.
- Secrets or credentials inadvertently committed to the repo.

## What's Out of Scope

- Upstream application vulnerabilities. Those belong to the respective
  upstream projects (linked from each image's `image.yaml` and README).
- Renovate-tracked base image CVEs that surface as Trivy findings but are
  unfixable upstream. These are documented via per-image `.trivyignore`
  files with revisit dates.
- CVEs in transitive dependencies of upstream applications. Same routing as
  the upstream-app case above.

## Hardening Posture

Every image:

- Publishes to `ghcr.io/0xd9c706e8/<app>` with digest-pinned tags. Downstream
  consumers pin by digest via Renovate.
- Runs rootless. Distroless static where the upstream allows pure-Go builds;
  slim Debian or Alpine otherwise.
- Builds for `linux/amd64` and `linux/arm64` from a single Dockerfile.
- Is scanned by Trivy on every push and PR. CI blocks on CRITICAL findings.
