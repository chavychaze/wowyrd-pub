# Changelog

Every version published on this repository's
[Releases page](https://github.com/chavychaze/wowyrd-pub/releases), newest first. Each section is
built from that version's Release notes. Earlier versions were not published here. Changes to
this repository's own files between releases are listed under "Unreleased".

## Unreleased

- `docker-compose.macos.yml`: an overlay that runs the Full profile (PostgreSQL + Redis) on
  macOS / Docker Desktop for an evaluation or a demo — bridge networking, eBPF off. No new images.
  A pilot still runs on a Linux host. See `INSTALL.md`, step 4.

## v0.3.5 — 2026-10-22

> **Not cosign-signed.** `v0.3.5` images are unsigned; see "Installing this version" below.

### What's new

- **Receiving-side (inbound) mule detection.** Every mule signal WoWyrd shipped before this
  release looked at convergence on a payout destination from the sending side. This release adds
  the receiving side: three new rules detect money arriving at one of your own accounts from
  multiple first-time external senders, a credit followed by most of it leaving again within
  minutes (pass-through/layering), and a new account's first large incoming credit. 41 rules total
  now (38 sending-side, 3 receiving-side) — identical rule pack across the standard and Lite
  (embedded SQLite) editions.
- **Direction-aware scoring.** The 38 pre-existing rules now explicitly apply only to outgoing
  transactions — a receiving-side event never double-fires an unrelated sending-side rule, and
  never inflates a customer's own velocity counters or geo-history from an unrelated event.

### Installing this version

Images: `ghcr.io/chavychaze/wowyrd-app:0.3.5`, `ghcr.io/chavychaze/wowyrd-dashboard:0.3.5` (no
leading `v` on the image tag — see `chavychaze/wowyrd-pub`'s `INSTALL.md` for the full install
flow).

Image digests:

- `ghcr.io/chavychaze/wowyrd-app:0.3.5` — `sha256:b551eb5255d6c5189b719038d824425e1454ce6fc68a1e2d3e6d89e0e3d33839`
- `ghcr.io/chavychaze/wowyrd-dashboard:0.3.5` — `sha256:c8d907be03d14217670530d24557a813d6c92839fc0aaa9f2408c88a78cf5a23`

**This release is not cosign-signed.** The images were built and pushed manually while the
signed release pipeline was unavailable. `INSTALL.md`'s `cosign verify` step will not succeed
against `0.3.5` specifically — a future release will restore signing once the pipeline is running
again. The full local test suite (813/813), lint, and static-analysis checks all ran clean
before this release shipped.

Available now — install it in your own environment today.

## v0.3.4 — 2026-10-18

### What's new

- **Pilot tooling, and the Lite edition now ships the full rule pack.** New import paths for
  onboarding a pilot: a configurable column-mapping import (`POST /v1/ingest/import/mapped`) for
  a partner's own export format, a client known-fraud pre-configuration import (backdated
  ground-truth, zero live side effects), and a champion-challenger comparison import to run
  side by side against a client's existing anti-fraud system. A curated `ua-nbu` rule pack is
  now available for the Ukrainian NBU regulatory context — a data-only selection from the same
  rules, no new rule logic. The Lite (embedded SQLite, zero separate database service) edition
  now ships the full 38-rule baseline pack, identical to the default Postgres+Redis edition — it
  previously shipped only 6 IP-intelligence rules.
- **Step-up / "contact the customer."** A configurable score threshold and action mapping can
  now route a borderline decision to a step-up (contact-the-customer) flow instead of a flat
  allow/block: a `step_up_requested` webhook, `GET /v1/step-ups` to list pending ones, and
  `POST /v1/step-ups/{id}/outcome` to record the real-world result — changes to the threshold and
  mapping go through the approval workflow, with an audit trail (configurable to require a
  second approver).
- **A new rule for account-drain scams.** Given an optional balance snapshot, a payout that
  drains most of an account's available balance to a beneficiary added immediately beforehand
  now routes to step-up — the classic "safe account" authorized-push-payment pattern.
- **Retro-analysis now works end to end.** Importing a client's historical transaction data
  (`POST /v1/ingest/import`) now scores every event against its own real historical time, not
  the moment the import happens to run — account-age, correlation, and dormancy checks all
  reflect what was actually true when the transaction occurred. *Known limitation*: the evidence
  report's date filter currently uses import time, not the transactions' own dates — filtering
  by the transactions' own historical period is coming next.
- **Geo/ASN fallback for clients behind a CDN or proxy.** When WoWyrd's own IP-based geolocation
  can't resolve a real client IP (a common case once Cloudflare, a WAF, or a load balancer sits
  in front of the integration), the evaluator now accepts the caller's own trusted-edge-resolved
  country and ASN as a fallback — never overriding a real, resolvable IP, and recording which
  source was used on every decision. A new `session_multiple_asns` signal uses the same data.
  A new `datacenter_asn` signal checks the caller-supplied ASN against a configured list
  (`DATACENTER_ASN_DB_PATH`) — like the existing BIN database, it's inert until that list is
  provided.
- **Dashboard rebuilt on Tailwind CSS v4.** Dependency audit passing: npm, 0 advisories; Rust,
  `rustls` updated for RUSTSEC-2026-0346/0348/0349, plus 3 documented exceptions for a crate
  that is not compiled into the binary.

### Installing this version

Images: `ghcr.io/chavychaze/wowyrd-app:0.3.4`, `ghcr.io/chavychaze/wowyrd-dashboard:0.3.4`
(no leading `v` on the image tag — see `chavychaze/wowyrd-pub`'s `INSTALL.md` for the full
install flow). **First signed release**: both images are cosign-signed (keyless) with SBOMs
attached — `INSTALL.md` has the exact verification commands.

Image digests:

- `ghcr.io/chavychaze/wowyrd-app:0.3.4` — `sha256:069ea1c3c9c4dcc791fa8b729248f7015727467c59352f513034b2c9d5e01cda`
- `ghcr.io/chavychaze/wowyrd-dashboard:0.3.4` — `sha256:76f8d7de2550d5cc5903517afe2656908bc530069c891a555fb6cc85743c9668`

SBOM for `wowyrd-dashboard` generated from the tagged source after the build — the dashboard
image itself was built, pushed, and cosign-signed in the original CI run; only the
SBOM-attachment step failed, for a reason unrelated to the image content. Image digests and
signatures are unchanged from the original run.

v0.3.3 was an internal partial build and was not released.

Pre-1.0 and observe-first by default: intended for evaluation and pilots.
