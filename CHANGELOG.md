# Changelog

Every version published on this repository's
[Releases page](https://github.com/chavychaze/wowyrd-pub/releases), newest first. Each section is
built from that version's Release notes. Earlier versions were not published here.

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
