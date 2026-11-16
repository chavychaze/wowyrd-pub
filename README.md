# WoWyrd

WoWyrd measures the fraud and AML rules you already run, on your own data, inside your environment.

The rule review of your own fraud and AML rules is delivered during a pilot, inside your environment: see https://wowyrd.net/rule-review/.
More about WoWyrd: https://wowyrd.net.

## About this repository

This repository holds the install files and public docs for the WoWyrd risk engine and its
optional sensor. **The engine and the sensor are not offered now.** The files, the signed
releases and their notes stay here as a record.

The repository contains **compiled images only**: no source code. The engineering source lives
in a private repository.

## What's here

- `docker-compose.yml` — the minimal install stack: `wowyrd-app` (the risk engine),
  `wowyrd-dashboard` (the evidence/review UI), PostgreSQL, and Redis. No `build:` step — every
  image is pulled pre-compiled from `ghcr.io/chavychaze`. From `v0.3.6`, the dashboard is in
  English and Ukrainian. Each analyst picks the language in the dashboard. The default is English.
- `docker-compose.macos.yml` — an overlay that runs the same stack on macOS / Docker Desktop
  for an evaluation or a demo (bridge networking, eBPF off).
- `docker-compose.lite.yml` — an overlay for a quick look without a database (embedded SQLite,
  2 containers). Not a pilot profile: see "Engine install" below.
- `.env.example` — copy to `.env` and fill in before starting.
- [`INSTALL.md`](INSTALL.md) — the pilot install runbook.
- [`OPERATIONS.md`](OPERATIONS.md) — upgrade, backup, rollback and uninstall.
- [`SECURITY.md`](SECURITY.md) — how to report a vulnerability.
- [`NETWORK.md`](NETWORK.md) — every outbound connection the stack makes, and how to run offline.

## Prerequisites

- Docker + Docker Compose.
- A Linux host for this stack (macOS: evaluation or demo only, see below), `linux/amd64` or
  `linux/arm64` from `v0.3.9`. Kernel 5.17 or newer only if you want optional eBPF-based
  enforcement later (the TC filter uses `bpf_loop`, added in kernel 5.17). On Ubuntu 22.04, the
  GA kernel (5.15) is too old for the TC filter — use the HWE kernel. On a kernel older than 5.17,
  only the XDP part of the optional sensor attaches. Without eBPF, WoWyrd runs
  in PostgreSQL-only mode automatically — this is a fully supported mode for a first
  observe-only pilot, not a degraded fallback to work around.
- macOS / Docker Desktop: this stack's host networking leaves the API (port 8090) unreachable
  from the Mac itself. For an evaluation or a demo on a Mac, add the `docker-compose.macos.yml`
  overlay — see [`INSTALL.md`](INSTALL.md). Use the macOS overlay to evaluate WoWyrd on a Mac.
  Run a pilot on your own data on a Linux server.
- Threat-intel enrichment (Tor/VPN/datacenter/disposable-email/IP reputation) is fetched
  in-process on a schedule — no extra setup needed. Optional local intelligence files
  (IP2Location BIN, MaxMind GeoLite2, a card-BIN database) go in `./config/intel/` if you have
  them; everything degrades gracefully if a given file is absent.

## Authenticate to the image registry (one-time)

The `wowyrd-app`/`wowyrd-dashboard` images are **private** — `docker compose up` will fail with
`unauthorized` until you log in once. Your WoWyrd engineering contact will issue you a GitHub
Personal Access Token scoped to `read:packages` on request; then:

```bash
echo "$WOWYRD_PAT" | docker login ghcr.io -u wowyrd --password-stdin
```

The registry checks the token only. The user name can be any value.

This is a one-time step per machine — Docker caches the credential, so subsequent `docker compose
pull`/`up` calls (including version upgrades) don't need it repeated.

## Quick start

```bash
cp .env.example .env
# edit .env: set WOWYRD_VERSION (see "Versions" below), POSTGRES_PASSWORD, API_KEYS,
# DASHBOARD_API_KEYS (a new value, never one from API_KEYS)
docker compose up -d
# macOS (evaluation/demo): docker compose -f docker-compose.yml -f docker-compose.macos.yml up -d
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

**Drop the leading `v`.** A release is tagged `v0.5.0` on the Releases page, but the actual Docker
image tag is `0.5.0` (no `v`) — set `WOWYRD_VERSION=0.5.0`, not `WOWYRD_VERSION=v0.5.0`, or the
pull will fail with "manifest unknown."

## Safety defaults

`ENFORCEMENT_MODE` defaults to `observe` — nothing is blocked automatically. WoWyrd's model is
observe-first by design: review the evidence it produces before enabling any autonomous
enforcement, and only change this setting deliberately, after that review.

## Engine install (not offered now)

To install the engine, follow [`INSTALL.md`](INSTALL.md). It uses the Full profile
(`docker-compose.yml`: PostgreSQL + Redis), because the champion-challenger comparison and the
full detection need it. `INSTALL.md` also covers verifying image signatures
(`cosign verify`) before you pull. `v0.5.0`, `v0.4.0`, `v0.3.10`, `v0.3.9`, `v0.3.6` and `v0.3.4` are signed; `v0.3.5` is not.

`docker-compose.lite.yml` (embedded SQLite, no separate database) is for a quick look. Its
detection is not the same as Full, so it is not a pilot profile. `INSTALL.md` lists every feature
it leaves out.

## Support

This is a guided technical pilot, not a self-serve SaaS product — reach out to your WoWyrd
engineering contact for onboarding, configuration help, or to report an issue.
