# wowyrd-pub — Working Rules

This is the **public distribution repo**: compiled images only (`docker-compose.yml`,
`docker-compose.lite.yml`, `.env.example`, `README.md`) — no source code. The engineering source
lives in the private `../WoWyrd/` repo; all business/strategy/positioning material lives in
`../WoWyrd-bussiness/`.

## Single source of truth for business-side data (added 2026-10-11)

This repo holds no business data of its own, and never should. `../WoWyrd-bussiness/docs/strategy/
CRM.csv` and `SCORECARD.md` are the single source of truth for business-side data (contacts,
leads, consulting conversations, staffing, email/outreach history) across the whole WoWyrd
infra — this repo, `../WoWyrd/`, and `../WoWyrd-bussiness/` itself. See that repo's `CLAUDE.md` for
the full statement.

## Guardrails still apply here

`README.md` is public-facing text — any claim in it is subject to
`../WoWyrd-bussiness/docs/messaging/POSITIONING_AND_SAFE_WORDS.md` exactly as if it were website
copy or a pitch deck. Being a different (and much smaller) repo isn't a reason to skip the
`wowyrd-guardrail-checker` skill before changing wording here — it's exactly the kind of
client-facing surface that guardrail exists to protect.

## Versioning

No `latest` tag — real releases are pinned explicitly. See `README.md`'s "Versions" section before
changing anything related to `WOWYRD_VERSION`.
