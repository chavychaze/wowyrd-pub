# Security policy

## Report a vulnerability

```mermaid
flowchart TD
    A[You find a vulnerability] --> B[Email security@wowyrd.net<br/>not a public issue]
    B --> C[WoWyrd acknowledges<br/>target: 3 business days]
    C --> D[WoWyrd sends a first assessment<br/>target: 10 business days]
    D --> E[WoWyrd and you agree on<br/>the fix and the disclosure date]
    E --> F[The fix ships in a new release<br/>CHANGELOG.md names it]
```

1. Email **security@wowyrd.net**. Start the subject with `Security:`.
2. Do not open a public GitHub issue for a vulnerability.
3. Include:
   - the WoWyrd version (`WOWYRD_VERSION`);
   - the steps to reproduce the problem;
   - what an attacker can do with it;
   - your name or handle, if you want credit.

## What we do and when

| Step | Target |
|---|---|
| Acknowledge your report | Within 3 business days |
| Send a first assessment | Within 10 business days |

Business days are Ukrainian working days, in the Europe/Kyiv time zone.

These are targets, not guarantees. We do not promise a fix date. After the first assessment, we
agree with you on the fix and on when the issue becomes public.

## Scope

- The `wowyrd-app` and `wowyrd-dashboard` images on `ghcr.io/chavychaze`.
- The Compose files and the documentation in this repository.

Report a vulnerability in PostgreSQL, Redis or Docker to that project directly.

## Fixed in `v0.3.6`: the dashboard held a full API key

Up to `v0.3.5`, the dashboard web page contained the value of `API_KEYS`, and that key worked on
every API endpoint. From `v0.3.6`, the page contains `DASHBOARD_API_KEYS`, which the app accepts
only for reads. Changes need an operator key. The page still gives read access to your data, so
limit network access as `INSTALL.md` step 4 describes ("Limit who can open the dashboard and the
API").
