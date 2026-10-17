---
name: wowyrd-guardrail-checker
description: Checks a piece of draft public-facing WoWyrd text (LinkedIn post, website copy, pitch deck, email, one-pager) against ../WoWyrd-bussiness/docs/messaging/POSITIONING_AND_SAFE_WORDS.md's use/avoid word lists and lead-order hierarchy, and flags claims that may have gone stale relative to what the product actually does today. Use before publishing anything WoWyrd-related, when the user says "check this against guardrails", "is this safe to post", or "guardrail check this text". Complements the technical repo's own claims-guardrail-checker — this one is scoped to business-repo content and also checks for factual drift, not just banned phrases.
metadata:
  version: "1.0.0"
---

# WoWyrd Guardrail Checker

> **Canonical copy** (since 2026-10-17): `WoWyrd-bussiness/.claude/skills/wowyrd-guardrail-checker/`. The
> other repos keep byte-identical copies. Paths are sibling-relative (`../WoWyrd-bussiness/…`,
> `../WoWyrd/…`), so the same file works from any WoWyrd-family repo root, this one included.

Every public-facing sentence about WoWyrd has two ways to be wrong: it can use a banned word, or it
can be a claim that used to be true and quietly stopped being true after a product change (this has
happened for real — see `../WoWyrd-bussiness/docs/messaging/WEBSITE_COPY.md`'s 2026-09-16 entry, where "anything
stronger is a deliberate, reviewed step" stopped being accurate the moment the Action-approval gate
shipped). Check for both, not just the first.

## Method

1. **Read `../WoWyrd-bussiness/docs/messaging/POSITIONING_AND_SAFE_WORDS.md` fresh, every time.** It gets revised; don't
   work from memory of a previous read.
2. **Word-list check**: scan the draft against the "Use these words" and "Avoid these words" lists.
   Flag every match, quoting the exact sentence.
3. **Lead-order check**: does the draft lead with on-premise/data-residency, or does it lead with
   eBPF/kernel/"AI"/latency? The guardrail doc specifies the order — a draft that's individually
   guardrail-clean but leads with the wrong thing is still a finding.
4. **Factual-drift check — the part that's easy to skip**: for any claim about what WoWyrd *does*
   (not just how it's worded), verify it's still true against the actual current state:
   - Check the technical repo's `../WoWyrd/CHANGELOG.md` `[Unreleased]` section and
     `../WoWyrd/docs/product/ROADMAP.md` for anything that changed the claim's accuracy.
   - If the draft describes enforcement/autonomy behavior, cross-check against the most recent
     `../WoWyrd-bussiness/docs/business/pitch/audit-readiness-*.md` record (if one is newer than
     your last check) — that record exists specifically to catch this class of drift.
   - A claim that was true when originally written but isn't anymore is a real finding, not a
     lesser one than a banned word — it already caused a real, live overclaim on `wowyrd.net` once.
5. **Report findings plainly**: quote the exact problem sentence, state what's wrong (banned word /
   wrong lead / factually stale), and propose a specific replacement sentence — don't just flag,
   fix. See `../WoWyrd-bussiness/docs/business/pitch/*-post.md` files' own "## Guardrails" sections for the expected
   output shape (a short checklist of what was verified clean, not just what was wrong).
6. **If this is a new public claim** (not just a rewording), check whether it needs a primary
   source. This repo's established bar: real, dated, named sources only (SEC filings, Fed SR
   letters, named surveys) — never "studies show" or an unsourced statistic. If the draft cites a
   stat without a source you can point to, that's a finding too.

## What NOT to do

- Don't approve a draft based on a summary of the safe-words doc — read the actual current file.
- Don't skip the factual-drift check because the wording looks fine — wording and truth are
  independent axes, both matter.
- Don't silently fix and republish something already live (a website, a sent post) — flag it to the
  user; live surfaces need explicit approval before editing, same as anywhere else.
