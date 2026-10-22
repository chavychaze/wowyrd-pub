# WoWyrd

Pre-transaction risk control for financial and high-velocity platforms. Observe-first,
on-premise: WoWyrd runs inside your own environment, so raw transaction data can stay on
your infrastructure rather than leaving it to be scored. First deliverable is an evidence
report, not a block — shadow-mode / champion-challenger validation, with controlled
enforcement only after evidence review.

WoWyrd is available now: install it in your environment today and run a pilot on your own
data.

This repository contains **compiled images only** — no source code. It's the quick-start
distribution surface for a WoWyrd install; the engineering source lives in a private
repository.

## What's here

- `docker-compose.yml` — the minimal install stack: `wowyrd-app` (the risk engine),
  `wowyrd-dashboard` (the evidence/review UI), PostgreSQL, and Redis. No `build:` step — every image is pulled
  pre-compiled from `ghcr.io/chavychaze`.
- `.env.example` — copy to `.env` and fill in before starting.

## Prerequisites

- Docker + Docker Compose.
- Linux (kernel 5.15+) if you want optional eBPF-based enforcement later. On macOS, or on an
  older kernel, WoWyrd runs in PostgreSQL-only mode automatically — this is a fully supported
  mode for a first observe-only pilot, not a degraded fallback to work around.
- Threat-intel enrichment (Tor/VPN/datacenter/disposable-email/IP reputation) is fetched
  in-process on a schedule — no extra setup needed. Optional local intelligence files
  (IP2Location BIN, MaxMind GeoLite2, a card-BIN database) go in `./config/intel/` if you have
  them; everything degrades gracefully if a given file is absent.

## Authenticate to the image registry (one-time)

The `wowyrd-app`/`wowyrd-dashboard` images are **private** — `docker compose up` will fail with
`unauthorized` until you log in once. Your WoWyrd engineering contact will issue you a GitHub
Personal Access Token scoped to `read:packages` on request; then:

```bash
echo "$WOWYRD_PAT" | docker login ghcr.io -u <your-github-username> --password-stdin
```

This is a one-time step per machine — Docker caches the credential, so subsequent `docker compose
pull`/`up` calls (including version upgrades) don't need it repeated.

## Quick start

```bash
cp .env.example .env
# edit .env: set WOWYRD_VERSION (see "Versions" below), POSTGRES_PASSWORD, API_KEYS
docker compose up -d
```

Check it's healthy:

```bash
curl http://localhost:8090/health
```

Dashboard: `http://localhost:3000` (or `http://<HOST_IP>:3000` if set in `.env`).

## Versions

Explicit versioning only — there is no `latest` tag. Check this repository's Releases page for
the current version, then pin `WOWYRD_VERSION` in `.env` to it and change it deliberately, not
automatically, when you're ready to upgrade.

**Drop the leading `v`.** A release is tagged `v0.3.5` on the Releases page, but the actual Docker
image tag is `0.3.5` (no `v`) — set `WOWYRD_VERSION=0.3.5`, not `WOWYRD_VERSION=v0.3.5`, or the
pull will fail with "manifest unknown."

## Safety defaults

`ENFORCEMENT_MODE` defaults to `observe` — nothing is blocked automatically. WoWyrd's model is
observe-first by design: review the evidence it produces before enabling any autonomous
enforcement, and only change this setting deliberately, after that review.

## Pilot install (no separate database to provision)

For a pilot on your own data — embedded SQLite backend, shadow-mode only, nothing
privileged/eBPF-related — see [`INSTALL.md`](INSTALL.md), which also covers verifying image
signatures (`cosign verify`) before you pull. `v0.3.4` is signed; `v0.3.5` is not.

## Support

This is a guided technical pilot, not a self-serve SaaS product — reach out to your WoWyrd
engineering contact for onboarding, configuration help, or to report an issue.
