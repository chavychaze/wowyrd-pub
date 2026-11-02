# Changelog

Every version published on this repository's
[Releases page](https://github.com/chavychaze/wowyrd-pub/releases), newest first. Each section is
built from that version's Release notes. Earlier versions were not published here. Changes to
this repository's own files between releases are listed under "Unreleased".

Each version has these sections: "What's new", "Breaking changes", "Upgrade safety", "Migration
steps" and "Installing this version".

## Unreleased

No changes since `v0.3.6`.

## v0.3.6 — 2026-11-02

> **Signed.** `v0.3.6` images are cosign-signed again. See `INSTALL.md`, step 3.

### What's new

- **The dashboard has its own read-only key.** A new required setting, `DASHBOARD_API_KEYS`,
  holds the key that the dashboard web page contains. The app accepts this key only for reads
  (`GET`, `HEAD`, `OPTIONS`). Before, the page contained the value of `API_KEYS`, and that key
  worked on every endpoint. See "Breaking changes".
- **Operators sign in to the dashboard for changes.** To block, unblock, or review a case or a
  rule, an operator enters their operator key in the dashboard. The app gives back a session that
  ends after 8 hours, or after 30 minutes without use. The app stores the operator of each new
  block from that session.
- **Security fix: 2 built-in operator accounts.** `v0.3.4` and `v0.3.5` created 2 operator
  accounts, `operator-1-seed` and `operator-2-seed`, on the Full and Lite profiles. Each had a
  fixed key that WoWyrd generated during development. The images contain only a hash of each
  key, not the key. A person with one of these keys who could reach the API could approve
  rule-weight changes and action-gate proposals. We cannot rule out that a copy of these keys
  still exists outside the codebase, so treat them as known. `v0.3.6` deactivates both accounts,
  on a new install and on an upgrade. Until you upgrade, limit network access to the API
  (`INSTALL.md`, step 4). If you replaced their keys yourself, the app does not change your
  accounts. To create your own operators, use `operator_tool` (see `INSTALL.md`, step 4).
- **Security fix: `customer_id` in the case list.** After retention anonymized a case
  (`RETENTION_ANONYMIZE_AFTER_DAYS`), `GET /v1/cases` returned the stored keyed hash of its
  `customer_id`, not a redacted value. Only a caller with a valid API key could get it. This was
  in `v0.3.4` and `v0.3.5`. Now the field says that retention redacted it. See "Breaking changes".
- **Fixed: step-up.** When a decision asked for step-up, the app often did not save the step-up
  and did not send the step-up webhook. This was in `v0.3.4` and `v0.3.5` (Full profile).
- **Case detail and export.** `GET /v1/cases/{assessment_id}` shows one case and the account's
  other Review and Block decisions. `GET /v1/cases/{assessment_id}/export?format=html` (or
  `format=json`) gives one self-contained file for that case.
- **Retro-analysis report page.** `GET /v1/reports/retro-analysis` gives the evidence report as
  one HTML page, with each reason in plain English. To get a PDF, print the page from your
  browser.
- **Evidence report, retro-analysis and fraud feedback on the Lite profile.** `/v1/feedback`,
  confirmed-fraud import and the payment callback now also work on Lite. Champion-challenger
  comparison, manager KPIs, step-up, webhooks and action gates are still Full profile only. See
  `INSTALL.md`, "Which profile to use".
- **Recent transactions when the dashboard opens.** `GET /v1/feed/recent` returns the last
  transactions (200 by default, 500 at most). The feed shows amount, payment type and country.
  The Allow, Review and Blocked counters count the risk decision. A mode label shows whether the
  app really blocks (`ENFORCEMENT_MODE`).
- **Personal data anonymization is visible.** `GET /health` has a new `retention` field. If
  `RETENTION_HASH_KEY` is not set, `retention.active` is `false` and `retention.inactive_reason`
  says why. Before, only a daily log line showed this. See `INSTALL.md`, step 4.
- **Fixed: imported champion-challenger data was never anonymized.** The retention pass now also
  anonymizes it.
- **The approval count of each change is shown.** The evidence report and the pending action-gate
  proposals show how many operators each change needed ("approved, single-operator mode" or
  "approved, N-operator mode").
- **Fixed: an approved rule-weight change applied up to 5 minutes late.** After an operator
  approved a calibration proposal (`POST /v1/calibration-proposals/{proposal_id}/approve`), the
  app kept the old rule weight for up to 5 minutes. Now the new weight applies at once. This was
  in `v0.3.4` and `v0.3.5`. Score thresholds and the step-up threshold were not affected.
- **Monthly volume warning.** If your licence sets a monthly volume limit, the dashboard shows a
  warning at 80% and at 100% of it. Scoring never stops. Licences without a limit work as before.
  `GET /v1/license-status` has 2 new fields: `monthly_volume_limit` and
  `current_month_completed_count`.
- **When a rule-weight change took effect.** The app records the time at which each approved
  rule-weight change took effect. The evidence report (`GET /v1/reports/evidence`) shows it for
  each change.
- **Fixed: a failed champion-challenger import kept part of its rows.** Now an import saves all
  of its rows or none.
- **Block a beneficiary.** A new block type, `BENEFICIARY`, blocks payments to one receiving
  account. It matches the request's `beneficiary_id`. It works on the Full and Lite profiles.
- **Default datacenter ASN list.** The `datacenter_asn` rule now works without a list file: the
  app contains 24 cloud and hosting ASNs. Your own `config/intel/datacenter-asns.txt` replaces
  it. `GET /health` shows which list the app uses. The rule still needs `client_asn` in the
  request. See `INSTALL.md`, step 4.
- **One offline switch.** Set `WOWYRD_OFFLINE=true` and the app does not download threat-intel
  lists or the bundle. `GET /v1/license-status` shows `offline_mode`, and the dashboard shows
  "Offline mode". See `NETWORK.md`.
- **The dashboard fonts are in the image.** The analyst's browser no longer contacts Google Fonts.
- **Threat-intel feed health.** `GET /health` has a new `feed_health` list: the last successful
  download of each list, and whether it is stale (no success in 2 days).
- **Smaller bundle credential.** With `INTEL_BUNDLE_URL` set, the app sends only the licence ID,
  the expiry date and a bundle token. It no longer sends the whole licence file.
- **Ukrainian dashboard.** Each analyst can switch the dashboard between English and Ukrainian.
  The default is English.
- **IPv6 enforcement in the kernel path** (optional eBPF only): IP block list, trusted-proxy
  header and rate limit now also work for IPv6 clients.
- **Approval count setting.** `REQUIRED_APPROVALS_DEFAULT` sets how many operators must approve a
  change: `1` (the default) or `2`. With `2`, the proposer cannot approve their own change, so a
  change needs the proposer and two other operators. This works the same on the Full and Lite
  profiles.
- **Fixed:** a threat-intel list that returned an HTTP error page (for example 5xx) was read as
  the list and counted as refreshed. Now the app keeps its current entries and tries again within
  1 hour.
- **Score thresholds per installation** (Full profile). The Review and Block score thresholds
  can now be changed through `/v1/score-thresholds`. A change goes through the same approval as other
  rule changes. With no change, the thresholds stay as before.
- **New rule: gateway card testing.** The rule finds many different card BINs tried against one
  merchant within 10 minutes. It needs `merchant_id` and `card_bin` in the request. It does not
  see testing that uses many cards from one BIN. It works on the Full and Lite profiles.
- **Three new rules for scams that use a phone call or remote access.** The rules are ready for
  session labels from your own app. Your app sends them in `identity.labels` on
  `POST /v1/evaluate`: `session:active_call`, `session:remote_access_app` and
  `session:payee_details_pasted`. Each rule combines a label with account and payment conditions.
  The rules do not fire until your app sends these labels. They work on the Full and Lite
  profiles.
- **47 rules** in the rule pack (41 in `v0.3.5`), on the Full and Lite profiles. 2 of them are
  for a network sensor that this release does not contain. These 2 rules cannot fire in
  `v0.3.6`.

### Breaking changes

- `DASHBOARD_API_KEYS` is required. Without it, `wowyrd-app` does not start. Set it in `.env`
  before the upgrade. Use a new value, not a value from `API_KEYS`.

- These endpoints no longer accept a key from `API_KEYS`: `POST /v1/block`,
  `DELETE /v1/block/{block_type}/{value}`, `POST /v1/cases/{assessment_id}/review` and
  `POST /v1/rules/{rule_id}/soundness-reviews`. They need an operator key or an operator session
  (`POST /v1/auth/session`). If your integration calls them, change it first.

- `customer_id` in `GET /v1/cases` is now an object, not a string:
  `{"state": "known", "id": "..."}`, `{"state": "not_provided"}` or
  `{"state": "redacted_by_retention"}`. Before, it was a string, or it was not in the response. If
  your integration reads this field, change it to read `state` and `id`.

- `POST /v1/comparisons/import` now accepts at most 20,000 rows in one request, the same limit as
  the other import endpoints. A larger request gets HTTP 400. Split it into smaller requests.

No endpoint or setting was removed or renamed. `GET /health` and `GET /v1/license-status` have new
fields only.

### Upgrade safety

- New database migrations: 12 on the Full profile (PostgreSQL). On the Lite profile (SQLite): 7
  migrations, 2 new columns, 2 new tables and one rebuilt table (block types). The app applies
  them at start.
- Migrations only go forward. After the upgrade, `0.3.5` does not start on this database. To roll
  back, restore the backup that you made before the upgrade (see `OPERATIONS.md`).
- In offline mode, each list entry still expires 2 days after its last download. See `NETWORK.md`.

### Migration steps

1. If your integration reads `customer_id` from `GET /v1/cases`, change it first (see "Breaking
   changes").
2. If your integration blocks, unblocks or reviews with a key from `API_KEYS`, change it to use
   an operator key first (see "Breaking changes").
3. Get the new `docker-compose.yml` and `docker-compose.lite.yml` from this release. They pass
   `DASHBOARD_API_KEYS` to the app and to the dashboard.
4. Add `DASHBOARD_API_KEYS` to `.env`, for example `openssl rand -hex 24`. Optional new
   settings: `WOWYRD_OFFLINE`, `REQUIRED_APPROVALS_DEFAULT`.
5. Optional: verify the images (`INSTALL.md`, step 3).
6. Follow "Upgrade" in `OPERATIONS.md`: back up, set `WOWYRD_VERSION=0.3.6`, pull, start.
7. Create one operator for each person who makes changes (`INSTALL.md`, step 4, "Create your
   operators"). The 2 built-in operator accounts no longer work.
8. Optional, with `INTEL_BUNDLE_URL` only: ask WoWyrd for a licence file with a bundle token.
   Without one, the app sends no credential to the bundle URL.

### Installing this version

Images: `ghcr.io/chavychaze/wowyrd-app:0.3.6`, `ghcr.io/chavychaze/wowyrd-dashboard:0.3.6` (no
leading `v` on the image tag). See `INSTALL.md` for the full install.

Image digests:

- `ghcr.io/chavychaze/wowyrd-app:0.3.6` — `sha256:c7be87d98e9299e8c8084215a052e0ba2d7bd45537d8913fc80d0963462c2bd9`
- `ghcr.io/chavychaze/wowyrd-dashboard:0.3.6` — `sha256:872fbc9d279afbb7696f1c9acc5948ba79c9b2d7ba56131016d80d3dd608565f`

Both images are cosign-signed (keyless) by the release workflow of tag `v0.3.6`. `INSTALL.md`,
step 3, has the verification command.

Changes to this repository's own files in this release:

- `docker-compose.macos.yml`: an overlay that runs the Full profile (PostgreSQL + Redis) on
  macOS / Docker Desktop for an evaluation or a demo — bridge networking, eBPF off. No new images.
  A pilot still runs on a Linux host. See `INSTALL.md`, step 4.
- `OPERATIONS.md`: upgrade, backup, rollback and uninstall runbook for the Full profile.
- `INSTALL.md` step 2, option B: install on a host without registry access (`docker save` /
  `docker load`, checked by image ID).
- `SECURITY.md`: how to report a vulnerability.
- `NETWORK.md`: every outbound connection, and how to run offline.
- `docker-compose.yml` and `docker-compose.lite.yml` pass `DASHBOARD_API_KEYS` to `wowyrd-app`,
  and give it to the dashboard in place of `API_KEYS`. `docker-compose.macos.yml` also gives the
  dashboard `DASHBOARD_API_KEYS`. `.env.example` has the new setting.
- `docker-compose.yml` sets `platform: linux/amd64` for `wowyrd-app` and `wowyrd-dashboard`. The
  images are built for `linux/amd64` only. On an arm64 host (for example a Mac with Apple
  silicon), Docker now pulls the `amd64` image and runs it under emulation.
- `docker-compose.yml` passes `WOWYRD_OFFLINE`, `REQUIRED_APPROVALS_DEFAULT`, `INTEL_BUNDLE_URL`
  and `LICENSE_FILE` from `.env` to `wowyrd-app`. Before this, the Full profile did not pass
  `INTEL_BUNDLE_URL` or `LICENSE_FILE`. `docker-compose.lite.yml` now also passes
  `WOWYRD_OFFLINE` and `REQUIRED_APPROVALS_DEFAULT`.

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

### Breaking changes

None. No API field, endpoint or setting was removed or renamed.

### Upgrade safety

- One new database migration. It adds a column with a default value to the rules table and adds
  the 3 new rules. The app applies it at start.
- Migrations only go forward. After the upgrade, `0.3.4` does not start on this database. To roll
  back, restore the backup that you made before the upgrade (see `OPERATIONS.md`).
- The new request field `sender_id_hash` is optional. The 3 receiving-side rules run only on
  events that carry it. Events without it are scored as before.

### Migration steps

1. Follow "Upgrade" in `OPERATIONS.md`: back up, set `WOWYRD_VERSION=0.3.5`, pull, start.
2. No `.env` change is needed.
3. Optional: to use receiving-side detection, send `sender_id_hash` on incoming-credit events. You
   compute the hash on your side. WoWyrd receives only the hash, not the real sender identifier.

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

### Breaking changes

None. This is the first version published here.

### Upgrade safety

There is no earlier published version to upgrade from. Install it as a new install
(`INSTALL.md`).

### Migration steps

None.

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
