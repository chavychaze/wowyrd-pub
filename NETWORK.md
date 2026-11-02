# What leaves your network

Every outbound connection that the WoWyrd stack in this repository makes, for version `0.3.6`.
For `0.3.5`, see this file in the `v0.3.5` release.

```mermaid
flowchart TD
    A[WoWyrd stack] --> B{Who starts the connection?}
    B -->|wowyrd-app, every 24 hours<br/>unless WOWYRD_OFFLINE=true| C[5 public threat-intel lists<br/>or one INTEL_BUNDLE_URL]
    B -->|docker compose pull| D[ghcr.io: WoWyrd images<br/>Docker Hub: postgres, redis, alpine]
    B -->|wowyrd-app, per event| F[Webhook URLs that you register]
    B -->|nothing| G[No telemetry, no usage reporting,<br/>no licence check over the network,<br/>no font download]
```

## Connections

| Destination | Started by | What is sent | When | How to turn it off |
|---|---|---|---|---|
| `raw.githubusercontent.com` (IPsum IP reputation, VPN IP list, datacenter IP list, disposable-email domain list) | `wowyrd-app` | An HTTPS GET for a public file. No transaction or customer data | Each list once every 24 hours | Set `WOWYRD_OFFLINE=true` |
| `check.torproject.org` (Tor exit-node list) | `wowyrd-app` | The same | Once every 24 hours | Set `WOWYRD_OFFLINE=true` |
| The URL in `INTEL_BUNDLE_URL` (unset by default) | `wowyrd-app` | An HTTPS GET. If your licence file has a bundle token, the `Authorization` header holds 3 values: the licence ID, the expiry date and the bundle token. The client name, limits and signature are not sent. With no bundle token, no `Authorization` header is sent | Once every 24 hours, in place of the 5 lists above | Leave `INTEL_BUNDLE_URL` unset, or set `WOWYRD_OFFLINE=true` |
| `ghcr.io` | `docker compose pull` | Your registry token | At install and upgrade | Load the images from a file (`INSTALL.md`, step 2, option B) |
| Docker Hub (`postgres:15-alpine`, `redis:7-alpine`; `alpine:3` for the backup commands in `OPERATIONS.md`) | `docker compose pull`, `docker run` | None | At install and upgrade | Load the images from a file, or mirror them on your own registry |
| Webhook URLs that you register (`POST /v1/webhooks/endpoints`) | `wowyrd-app` | The event that the webhook is subscribed to | Per event | Do not register a webhook, or delete it. `WOWYRD_OFFLINE=true` does not stop webhooks |

## What is not sent

- **No telemetry or usage reporting.** Neither image contains an analytics, crash-reporting or
  usage-metering library.
- **The licence check is offline.** The app checks the licence file on your host. It does not
  contact WoWyrd to do this.
- **The dashboard fonts are in the image.** The analyst's browser loads them from the dashboard,
  not from Google Fonts.
- **MaxMind GeoLite2, IP2Location and the card-BIN database are local files.** The app reads them
  from `config/intel/`. It does not download them.
- **Stripe:** the app only receives Stripe callbacks. It never connects to Stripe.

## Run with no outbound connections

```mermaid
flowchart TD
    A[Load the images from a file] --> B[Set WOWYRD_OFFLINE=true in .env]
    B --> C[Do not register webhooks<br/>to outside hosts]
    C --> D[Start the stack]
    D --> E[The app scores with the lists<br/>already in its database]
    E --> F[2 days after the last download,<br/>the list-based signals have no data]
```

1. Load the images from a file (`INSTALL.md`, step 2, option B).
2. Set `WOWYRD_OFFLINE=true` in `.env`. The app then does not download the 5 lists or the bundle.
3. Do not register webhooks to hosts outside your network.
4. Start the stack. `GET /v1/license-status` shows `"offline_mode": true`, and the dashboard shows
   "Offline mode".

You can also block outbound traffic at your firewall or proxy. That is a second control, not a
replacement for step 2.

In offline mode, the app scores with the list entries that are already in its database. Each list
entry expires 2 days after the last successful download of its list. So the IP-reputation, Tor,
VPN, datacenter and disposable-email signals have no data 2 days after the app stops downloading.
On a new install that starts offline, they have no data at all.

## When a list cannot be fetched

```mermaid
flowchart TD
    A[Download a list] --> B{Result}
    B -->|Host unreachable, timeout,<br/>DNS failure| C[Log a warning<br/>keep the current entries]
    B -->|HTTP error, for example 5xx| C
    B -->|HTTP 200| D[Read the list<br/>record the download time]
    C --> E[Try again within 1 hour]
    D --> F[Next download in 24 hours]
```

- **The host cannot be reached, or sends an HTTP error (for example 5xx):** the app logs a warning,
  keeps the entries that it already has and does not count the list as refreshed. It tries again
  within 1 hour.
- **The host sends HTTP 200 with content that is not a list:** the app counts this as a download.
  The next download is in 24 hours.

`GET /health` shows the state of each list in `feed_health`:

- `last_success`: the time of the last successful download, or `null`.
- `stale`: `true` when there was no successful download in the last 2 days.

In offline mode, every list shows `"stale": true`, because the app does not download.
