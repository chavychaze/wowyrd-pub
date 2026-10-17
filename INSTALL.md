# WoWyrd — pilot install runbook

The authoritative, step-by-step install procedure for a PILOT-tier evaluation: shadow-mode only,
embedded (SQLite) backend, no Kubernetes, no air-gapped delivery, no kernel-enforcement packaging.
`README.md` stays the general overview; this file is the one source of truth for "what do I
actually run" — update this file when the install procedure changes, don't duplicate its steps
elsewhere (the pilot-tier Deploy webpage links here rather than restating these steps).

## 1. Prerequisites

- Docker + Docker Compose.
- Any Linux, macOS, or kernel version — this profile never touches eBPF/enforcement, so the
  kernel-5.15+ requirement in `README.md` does not apply to this path.
- A GitHub Personal Access Token scoped to `read:packages` (your WoWyrd engineering contact
  issues this on request) — both images are private.
- `WOWYRD_VERSION` **0.3.0 or later.** The embedded SQLite backend this runbook relies on
  (`STORAGE_BACKEND=sqlite`) first shipped in `v0.3.0`; `v0.2.0` images do not contain it, so this
  profile will not work with them. Ask your WoWyrd engineering contact which version to pin if the
  Releases page doesn't yet list one at or above `0.3.0`.

## 2. Authenticate to the image registry (one-time per machine)

```bash
echo "$WOWYRD_PAT" | docker login ghcr.io -u <your-github-username> --password-stdin
```

## 3. Verify the images are genuinely signed by WoWyrd (recommended before first pull)

Releases from `v0.3.3` onward (not yet published; no release up to and including `v0.3.2` is
signed — the current published release, `v0.2.0`, is unsigned) are signed with
[cosign](https://docs.sigstore.dev/cosign/overview/) using GitHub Actions' own keyless/OIDC identity
(Sigstore's public Fulcio/Rekor infrastructure) — no shared signing key exists to leak or need
rotating. **If the version you're pinning is below `0.3.3`, skip this step** — `cosign verify`
will fail on an unsigned image, and that failure says nothing about the image's integrity either
way. Otherwise, install cosign
([instructions](https://docs.sigstore.dev/cosign/system_config/installation/)), then:

```bash
cosign verify \
  --certificate-identity-regexp "^https://github.com/chavychaze/.*$" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/chavychaze/wowyrd-app:<WOWYRD_VERSION>

cosign verify \
  --certificate-identity-regexp "^https://github.com/chavychaze/.*$" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/chavychaze/wowyrd-dashboard:<WOWYRD_VERSION>
```

A Software Bill of Materials (CycloneDX format) for each signed image — `wowyrd-app.cdx.json` and
`bom.json` respectively — is available on request from your WoWyrd engineering contact for a
vendor-security review.

## 4. Configure and start (embedded/SQLite profile — no separate database to provision)

```bash
cp .env.example .env
# edit .env: set WOWYRD_VERSION to 0.3.0 or later (drop the leading "v" — see README.md's
# "Versions" section),
# API_KEYS, and POSTGRES_PASSWORD to any placeholder value (this profile never connects to
# Postgres, but Compose still validates the variable exists — see docker-compose.lite.yml's
# own comment on why).

docker compose -f docker-compose.yml -f docker-compose.lite.yml up -d wowyrd-app wowyrd-dashboard
```

This starts exactly 2 containers (`wowyrd-app`, `wowyrd-dashboard`) — no Postgres, no Redis, no
privileged/host-networking/eBPF configuration of any kind. Confirm that directly if you want to:

```bash
docker compose -f docker-compose.yml -f docker-compose.lite.yml config --services
docker ps   # expect exactly wowyrd-app + wowyrd-dashboard
```

## 5. Confirm shadow mode is running

```bash
curl http://localhost:8090/health
```

Open the dashboard at `http://localhost:3000` (or `http://<HOST_IP>:3000` if you set `HOST_IP` in
`.env`) and confirm it loads — shadow-mode evidence data will populate as real/synthetic traffic
is evaluated. `ENFORCEMENT_MODE` defaults to `observe` — nothing is ever blocked automatically in
this profile.

## 6. If something doesn't work

Reach out to your WoWyrd engineering contact — this is a guided technical pilot, not a self-serve
product. If you're timing this install for the first time, please record: total wall-clock time,
and every step above that needed something not written down here, exactly as written — that
feedback is what keeps this runbook honest.

---

**Status note (2026-10-16): the under-30-minute install by someone who didn't write this runbook
has not been timed for real yet.** An actual timed run on a clean VM, by someone else, is still
outstanding — treat any timing claim as unverified until it has.
