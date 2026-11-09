# Changelog

Every version published on this repository's
[Releases page](https://github.com/chavychaze/wowyrd-pub/releases), newest first. Each section is
built from that version's Release notes. Earlier versions were not published here. Changes to
this repository's own files between releases are listed under "Unreleased".

Each version has these sections: "What's new", "Breaking changes", "Upgrade safety", "Migration
steps" and "Installing this version".

## Unreleased

No changes since `v0.3.10`.

## v0.3.10 — 2026-11-09

> **Signed, multi-arch.** `v0.3.10` images are cosign-signed and built for `linux/amd64` and
> `linux/arm64`. See `INSTALL.md`, step 3.

### What's new

- **Your own kernel lists.** An operator can create up to 4 named lists of IPv4 addresses and
  ranges: paste or upload them in the dashboard, or use `/v1/kernel-lists`. The app reports the
  result for each line. A new list starts in `observe` mode: it records hits and blocks nothing.
  It changes to `enforce` only after an operator's approval (`REQUIRED_APPROVALS_DEFAULT`). A list goes back to
  `observe` 30 days after its last upload, unless you set another limit (1 to 3650 days) or no
  limit when you create it. Each change goes to an audit log (`GET /v1/kernel-lists/audit-log`,
  WoWyrd operators only). Client lists need the network sensor (Full profile on Linux). Without
  it, a change returns HTTP 503 and nothing changes.
- **A second managed list: hijacked netblocks (IPv4).** Each install downloads this public list
  itself, at most once a day. The list starts in `observe` mode. To change it to `enforce`, an operator
  proposes and approves the action gate `xdp_managed_hijacked_netblock_enforce`. Like the Tor
  gate, it needs one approval, and the same operator can propose and approve.
  `GET /v1/kernel-sensor/status` gives `managed_hijacked_netblock_mode`. This is a new outbound
  connection: see `NETWORK.md`.
- **The strictest mode wins.** Each list (Tor, hijacked netblocks, your own lists) has its own
  kernel map. If an address is on two lists, the sensor uses `enforce` when either list is in
  `enforce` mode. The emergency switch still lets all traffic through, whatever the lists say. The sensor refuses any
  range wider than `/8`.
- **A list that is too old goes back to `observe`.** If a managed list was not updated for
  `MANAGED_TOR_MAX_LIST_AGE_HOURS` (default 72) or `MANAGED_HIJACKED_NETBLOCK_MAX_LIST_AGE_HOURS`
  (default 168) hours, it goes back to `observe`. Its entries stay in place. A fresh list
  restores the approved mode. Each mode change goes to a new hash-chained audit log
  (`GET /v1/kernel-sensor/mode-audit-log`, WoWyrd operators only). In `GET /health`, `feed_health` shows
  `past_enforcement_limit`. If you approve `enforce` for a list that is already too old, it stays
  in `observe`, and the app tells you why.
- **XDP on several network interfaces.** `NETWORK_INTERFACE` accepts a comma-separated list of up
  to 8 interfaces. All interfaces use the same lists, so a list update, a mode change or the
  emergency switch applies to all of them. If one name is wrong, the app reports it and the other
  interfaces still attach. `GET /v1/kernel-sensor/status` lists each interface and its mode.
- **`GET /health` shows each sensor program.** New fields `xdp_attached` and `tc_attached`. The
  dashboard says when header inspection (the TC filter) is not running. This replaces the
  `v0.3.9` known limit: `kernel_sensor.attached` alone did not show a missing TC filter.
- **`ENFORCEMENT_MODE` applies to the rule engine only.** The kernel lists do not follow it: each
  list has its own mode. `GET /v1/kernel-sensor/status` now also gives
  `rule_engine_enforcement_mode`.
- **Dashboard:** the action-gate tables show plain names for the two kernel list gates.
- **Release pipeline:** it checks that it can sign before it pushes any image. If it cannot sign,
  it stops before the registry.

### Fixed

- **SYN signals no longer miss a burst that crosses a one-second boundary.** The rate is now
  measured over two time buckets. Each signal still fires at most once per second.
- **`BPF_FS_PATH`** now also sets where the sensor pins its maps. Before, it applied only when
  the app opened them.

**Known limits:**

- The kernel lists are IPv4 only. XDP has no IPv6 path yet.
- The kernel lists and their action gates are not available on the Lite profile.
- Client lists need one `wowyrd-app` process. More than one replica is not supported.

### Breaking changes

None for the default setup. If you set `BPF_FS_PATH` to a path other than the default, the sensor
now pins its maps there.

### Upgrade safety

- New database migrations: 3 on the Full profile (PostgreSQL), none on the Lite profile (SQLite).
  The app applies them at start.
- Migrations only go forward. To roll back, restore the backup that you made before the upgrade
  (see `OPERATIONS.md`).
- The hijacked-netblock list and new client lists start in `observe` mode. The upgrade blocks
  nothing by itself. The Tor list keeps the mode that you approved.
- `MANAGED_TOR_MAX_LIST_AGE_HOURS` and `MANAGED_HIJACKED_NETBLOCK_MAX_LIST_AGE_HOURS` must be a
  whole number of 1 or more. Any other value stops the app at start. Through the Compose files,
  an empty value gives the default.

### Migration steps

1. Get the new `docker-compose.yml` from this release. It adds the volume `threat_intel_cache`
   and the two list-age settings.
2. Optional: set `MANAGED_TOR_MAX_LIST_AGE_HOURS`, `MANAGED_HIJACKED_NETBLOCK_MAX_LIST_AGE_HOURS`
   or a comma-separated `NETWORK_INTERFACE` in `.env`.
3. Optional: if your firewall allows outbound hosts by name, add the host of the hijacked-netblock
   list (`NETWORK.md`). Without it, that list stays empty and the other lists still work.
4. Optional: verify the images (`INSTALL.md`, step 3).
5. Follow "Upgrade" in `OPERATIONS.md`: back up, set `WOWYRD_VERSION=0.3.10`, pull, start.
6. Check `GET /health`: `xdp_attached` and `tc_attached` show which sensor programs run.

### Installing this version

Images: `ghcr.io/chavychaze/wowyrd-app:0.3.10`, `ghcr.io/chavychaze/wowyrd-dashboard:0.3.10` (no
leading `v` on the image tag). See `INSTALL.md` for the full install.

Image digests (multi-arch index; each covers `linux/amd64` and `linux/arm64`):

- `ghcr.io/chavychaze/wowyrd-app:0.3.10` — `sha256:e156e90babfc49fd159b28c1dc14ae0d25a1cb4892c0710fb1e30511262f9dff`
- `ghcr.io/chavychaze/wowyrd-dashboard:0.3.10` — `sha256:d0eb2e92a31f4d72036ae6cf602eec915a205b394c8df5c35b350def80c73930`

Both images are cosign-signed (keyless) by the release workflow of tag `v0.3.10`. `INSTALL.md`,
step 3, has the verification command. The index and each platform image are signed.

Changes to this repository's own files in this release:

- `docker-compose.yml`: new volume `threat_intel_cache` for the last valid hijacked-netblock list.
  New pass-through settings `MANAGED_TOR_MAX_LIST_AGE_HOURS` and
  `MANAGED_HIJACKED_NETBLOCK_MAX_LIST_AGE_HOURS`.
- `.env.example`: the two list-age settings, and `NETWORK_INTERFACE` as a list.
- `NETWORK.md`: the hijacked-netblock list host, for version `0.3.10`.
- `INSTALL.md`, `README.md`, `OPERATIONS.md`: version `0.3.10` in the examples.

## v0.3.9 — 2026-11-08

> **Signed, multi-arch.** `v0.3.9` images are cosign-signed and built for `linux/amd64` and
> `linux/arm64`. See `INSTALL.md`, step 3.

> `v0.3.7` and `v0.3.8` were not published on this repository. `v0.3.9` contains their changes.

### What's new

- **Images for `linux/amd64` and `linux/arm64`.** Each image tag is one signed multi-arch index.
  Docker pulls the image for the host's own platform. An arm64 host (for example a Mac with Apple
  silicon, or an arm64 Linux server) no longer runs the app under emulation.
- **Evidence report and manager KPIs on the Lite profile.** `GET /v1/reports/evidence` and
  `GET /v1/reports/manager-kpis` work on Lite. In `v0.3.6` they returned HTTP 500 there.
- **47 rules** in the rule pack, on the Full and Lite profiles. 2 of them use the network sensor
  (XDP): they fire only on the Full profile on a Linux host where the sensor attaches.
- **The network sensor is in the image.** On the Full profile on Linux, the app now starts the
  kernel sensor by default when the host allows it: TC and, new in this release, XDP. If the host
  does not allow it, the app runs in PostgreSQL-only mode, as before. `GET /health` gives the
  reason in `kernel_sensor.unavailable_reason`. The dashboard shows it on the Performance tab.
- **New setting `WOWYRD_EBPF_DISABLE`.** Set it to `true` to never start the sensor. The macOS
  and Lite overlays set it to `true`.
- **Managed Tor exit list in the kernel.** The sensor can check incoming connections against the
  public Tor exit list. The app updates the list on its normal schedule. The list starts in
  `observe` mode: it records hits and blocks nothing. To change it to `enforce`, an operator
  proposes the change on the action gate `xdp_managed_tor_enforce` and approves it
  (`POST /v1/action-gates/xdp_managed_tor_enforce/proposals`, then
  `POST /v1/action-gates/proposals/{proposal_id}/approve`). This gate needs one approval, also
  when `REQUIRED_APPROVALS_DEFAULT` is `2`. The same operator can propose and approve. The app
  checks the mode that the kernel reports after each change.
- **Emergency switch.** `POST /v1/emergency-bypass` with `{"enable": true, "reason": "..."}`
  makes the kernel sensor let all traffic through at once. `{"enable": false}` turns it off.
  It needs an operator key or session, and no second approval. Each change goes to a separate
  audit log (`GET /v1/emergency-bypass/audit-log`, WoWyrd operators only). The response gives the
  state that the kernel reports.
- **Sensor status for operators.** `GET /v1/kernel-sensor/status` gives `attached` and the Tor
  list mode. `GET /v1/emergency-bypass` gives the switch state. Both need an operator key or
  session. `GET /health` does not show these states. `attached`, and `kernel_sensor.attached` in
  `GET /health`, say whether the loader really attached a sensor program to the network
  interface.

- **Proposals expire.** A proposal that nobody approves or rejects now expires after
  `PROPOSAL_TTL_DAYS` days (new setting, default `7`). This applies to rule calibration, action
  gate, action mapping and step-up threshold proposals. On the Lite profile, it applies to rule
  calibration proposals. An expired proposal cannot be approved or rejected. To make the change,
  propose it again, and link the new proposal to the expired one with `reproposes_id`.
  On the Full profile, a daily job expires them, and `GET /health` shows it in
  `proposal_expiry_sweep`. On the Lite profile, the deadline is checked when an operator approves
  or rejects.

**Known limit:** `kernel_sensor.attached` is `true` when XDP or TC is attached, and it then gives
no reason. On a kernel older than 5.17, the TC filter does not load, but XDP can still attach. So
`attached: true` does not prove that the TC filter is loaded. Use kernel 5.17 or newer.

### Breaking changes

- **The sensor control socket moved** from `/var/run/` to `/var/run/wowyrd/loader.sock`. The
  directory must be mode `0700` and owned by root, and the socket is `0600`. If the directory
  exists with other settings, the sensor does not start, and the app runs in PostgreSQL-only
  mode. If you set `LOADER_SOCKET` yourself, or you mount `/var/run` from the host or another
  container, change it before the upgrade. The new `docker-compose.yml` sets the new path.
- **The sensor starts by default.** Before, it started only when `BPF_OBJECT_PATH` was set.
  An empty `BPF_OBJECT_PATH` no longer stops it. Use `WOWYRD_EBPF_DISABLE=true`.

### Upgrade safety

- New database migrations: 11 on the Full profile (PostgreSQL), 9 on the Lite profile (SQLite).
  The app applies them at start.
- Migrations only go forward. To roll back, restore the backup that you made before the upgrade
  (see `OPERATIONS.md`).
- The Tor list starts in `observe` mode. The upgrade blocks nothing by itself.
- No pending proposal expires at the upgrade. A proposal that exists before the upgrade gets a
  deadline of 7 days after it was proposed, or 7 days after the upgrade, whichever is later.
  `PROPOSAL_TTL_DAYS` applies to new proposals only. We recommend that you approve or reject
  pending proposals before you upgrade.
- The TC filter needs kernel 5.17 or newer. On an older kernel, the XDP sensor can attach
  without the TC filter (we saw this on kernel 5.15). See "Known limit". Use kernel 5.17 or newer.

### Migration steps

1. If you set `LOADER_SOCKET`, or mount `/var/run`, change it first (see "Breaking changes").
2. Get the new `docker-compose.yml`, `docker-compose.macos.yml` and `docker-compose.lite.yml` from
   this release.
3. Optional: add `WOWYRD_EBPF_DISABLE=true` to `.env` to keep PostgreSQL-only mode on the Full
   profile.
4. Optional: set `PROPOSAL_TTL_DAYS` in `.env`, as a whole number of 1 or more. Any other value
   (for example `0` or `abc`) stops the app at start.
5. Optional: verify the images (`INSTALL.md`, step 3).
6. Follow "Upgrade" in `OPERATIONS.md`: back up, set `WOWYRD_VERSION=0.3.9`, pull, start.
7. Check `GET /health`: `kernel_sensor` says if the sensor started, or why it did not.

### Installing this version

Images: `ghcr.io/chavychaze/wowyrd-app:0.3.9`, `ghcr.io/chavychaze/wowyrd-dashboard:0.3.9` (no
leading `v` on the image tag). See `INSTALL.md` for the full install.

Image digests (multi-arch index; each covers `linux/amd64` and `linux/arm64`):

- `ghcr.io/chavychaze/wowyrd-app:0.3.9` — `sha256:5827c5c70331d4aa74cc144d158f2514c0dce01277e4e6e7dda486a1b76507de`
- `ghcr.io/chavychaze/wowyrd-dashboard:0.3.9` — `sha256:ab9bee2751dcb509845de62918b7e5d9288a584f297d386e3a77471c681b34b5`

Both images are cosign-signed (keyless) by the release workflow of tag `v0.3.9`. `INSTALL.md`,
step 3, has the verification command. The index and each platform image are signed.

Changes to this repository's own files in this release:

- `docker-compose.yml`: `LOADER_SOCKET` is `/var/run/wowyrd/loader.sock`. New pass-through
  settings `WOWYRD_EBPF_DISABLE`, `PROPOSAL_TTL_DAYS` and `RETENTION_BLOCK_REDACT_AFTER_DAYS`.
- `docker-compose.macos.yml` and `docker-compose.lite.yml` set `WOWYRD_EBPF_DISABLE=true`.
  `docker-compose.lite.yml` also passes `PROPOSAL_TTL_DAYS` and
  `RETENTION_BLOCK_REDACT_AFTER_DAYS`.
- `INSTALL.md`: an empty `NETWORK_INTERFACE` does not turn eBPF off. The sensor uses the first
  network interface that is not loopback. The text said PostgreSQL-only mode. Docs fix only.
- `INSTALL.md` and `README.md`: eBPF needs kernel 5.17 or newer, not 5.15. Docs fix only.
- `SECURITY.md`: report a vulnerability to security@wowyrd.net.
- `docker-compose.yml` no longer sets `platform: linux/amd64`. Docker pulls the image for the
  host's own platform.
- `.env.example` has `WOWYRD_EBPF_DISABLE`, `PROPOSAL_TTL_DAYS` and
  `RETENTION_BLOCK_REDACT_AFTER_DAYS`.

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
- **Retro-analysis and fraud feedback on the Lite profile.** The retro-analysis report page,
  `/v1/feedback`, confirmed-fraud import and the payment callback now also work on Lite. The
  evidence report (`GET /v1/reports/evidence`), champion-challenger comparison, manager KPIs,
  step-up, webhooks and action gates are still Full profile only. See `INSTALL.md`, "Which
  profile to use".
- **Known issue (Lite profile):** `GET /v1/reports/evidence` and `GET /v1/reports/manager-kpis`
  return HTTP 500, not the "not available in the embedded lite profile" error. Use the
  retro-analysis report page on Lite.
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
