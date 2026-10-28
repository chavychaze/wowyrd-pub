# wowyrd-pub — Working Rules

This is the **public distribution repo**: compiled images only (the Compose files, `.env.example`
and the public docs: `README.md`, `INSTALL.md`, `OPERATIONS.md`, `SECURITY.md`, `CHANGELOG.md`) —
no source code. The engineering source
lives in the private `../WoWyrd/` repo; all business/strategy/positioning material lives in
`../WoWyrd-bussiness/`.

## Single source of truth for business-side data (added 2026-10-11)

This repo holds no business data of its own, and never should. `../WoWyrd-bussiness/docs/strategy/
CRM.csv` and `SCORECARD.md` are the single source of truth for business-side data (contacts,
leads, consulting conversations, staffing, email/outreach history) across the whole WoWyrd
infra — this repo, `../WoWyrd/`, and `../WoWyrd-bussiness/` itself. See that repo's `CLAUDE.md` for
the full statement.

**Log back, don't just build forward**: there's no automatic sync between repos/sessions. When
something here is worth another session knowing, add a row to `../WoWyrd-bussiness/docs/strategy/
SCORECARD.md`'s "Cross-Repo Coordination Log" yourself, or `SendMessage` the WoWyrd-bussiness
session directly if one's live — don't assume it'll be picked up from a pasted transcript later.

## Guardrails still apply here

`README.md` and every other public `.md` here (`INSTALL.md`, `OPERATIONS.md`, `SECURITY.md`,
`CHANGELOG.md`) are public-facing text — any claim in them is subject to
`../WoWyrd-bussiness/docs/messaging/POSITIONING_AND_SAFE_WORDS.md` exactly as if it were website
copy or a pitch deck. Being a different (and much smaller) repo isn't a reason to skip the
`wowyrd-guardrail-checker` skill before changing wording here — it's exactly the kind of
client-facing surface that guardrail exists to protect.

**Tone (founder direction, 2026-10-22)**: WoWyrd is a built, tested product available to install
today. Public text never says "PoC", "proof of concept" or "prototype". Use "pilot on your own
data" and "install it in your environment today". "production-ready" stays banned. The current
word lists are in `../WoWyrd-bussiness/docs/messaging/POSITIONING_AND_SAFE_WORDS.md`.

The skill is installed locally at `.claude/skills/wowyrd-guardrail-checker/` (added 2026-10-17).
Parent-directory skills are not invocable by name, so before that date this rule could not
actually be followed here. The canonical copy is `../WoWyrd-bussiness/.claude/skills/
wowyrd-guardrail-checker/SKILL.md`; this file is a byte-identical copy (sha1 `5e12e9d` as of
2026-10-17, sibling-relative paths that resolve from this repo root). When the canonical copy
changes, recopy it; never edit this one in place.

**Factual-drift checks specific to this repo** (each one went wrong in `INSTALL.md` on
2026-10-17). Run these too, alongside the skill's word-list and lead-order checks:
- Every version a doc names must exist as a *published* Release a customer can see
  (`gh release list -R chavychaze/wowyrd-pub` / `-R chavychaze/wowyrd-lts`). A git tag is not a release.
- A feature a doc relies on (e.g. `STORAGE_BACKEND=sqlite`, cosign signatures) must be present at
  the minimum version the doc states. Check `git grep <thing> <tag>` in `../WoWyrd/`.
- Every link must be openable by a customer: this repo is public, `wowyrd-lts` and the other
  `chavychaze` repos are private, and so are paths into `../WoWyrd/` (e.g. `specs/...`).

## Git in shared checkouts (added 2026-10-22)

Several Claude sessions may work in this checkout. Commit explicit paths only (`git add <file>`).
Never use `git commit -a` or `git add -A`: they can sweep another session's uncommitted edits into
an unrelated commit.

## Diagrams (founder rule, 2026-10-24, mandatory)

Every spec, ADR, rule, detection pattern, decision flow and architecture change gets a Mermaid
diagram in the same file, next to the text. In this repo that means the flows the public docs
describe (install, upgrade and rollback, uninstall, licence check, vulnerability reporting,
outbound connections). Not needed for typo fixes, one-line config changes or prose-only docs
(CHANGELOG bullets included). The text explains the diagram. In public docs the diagram is public
text: the guardrail applies to its labels too. The full rule is in `~/.claude/CLAUDE.md`
("Diagram rule"; narrowed to match it 2026-10-28).

## Open TODOs

- `SECURITY.md` uses vitaliy@wowyrd.net until security@wowyrd.net exists (founder task, 2026-10-28).
  Switch it then, and delete the HTML TODO at the top of `SECURITY.md`.

## Versioning

No `latest` tag — real releases are pinned explicitly. See `README.md`'s "Versions" section before
changing anything related to `WOWYRD_VERSION`.

## Hooks

Two `PreToolUse(Bash)` hooks. The first, added 2026-10-12, is wired identically across all five
repos in this family (WoWyrd, `wowyrd-wiki`, `WoWyrd-bussiness`, this repo, `ai-assistant`):
`claude-audit-guard.sh` — appends one JSON line per matched `Bash` call to a local, gitignored
`.claude-audit.jsonl`; separately blocks a short list of hard-to-reverse git operations
(force-push, push to `main`/`master`, `--no-verify` commit, `reset --hard`,
`rebase`/`filter-branch`) specifically when the session's own permission mode is auto/bypass —
never in a normal human-reviewed session, never for ordinary edits/commits. Fails open on
internal error. Since 2026-10-15 the push rule is fail-closed: in auto/bypass mode a `git push` is allowed only to an explicit, non-`main`/`master` branch with no force flag (bare `git push` is blocked too). Since 2026-10-17 `AUDIT_GUARD_SKIP=1` (honored only as a real leading prefix on the git command) no longer allows the command — it turns the deny into a human prompt (`permissionDecision: "ask"`) so the founder approves that exact command in the UI, and the deny message tells the agent to ask the user first and, only after a yes, re-run with the prefix to raise that confirmation prompt (guard v2) — the prefix bypasses nothing. An escape hatch an agent can type unaided is not a human approval. Run `bash .claude/hooks/test-claude-audit-guard.sh` after any edit; keep all five copies byte-identical.

The guard only sees Claude's own `Bash` tool calls. A command the user runs with the `!` prefix
does not fire `PreToolUse` hooks: the founder's two `! git push origin main` runs on 2026-10-17 are
absent from `.claude-audit.jsonl`. So the audit trail is a record of agent actions, not of
every push from this machine. That is intended (decided 2026-10-17, master session): a `!` command
is a human action by definition, which is exactly what the guard exists to require. No git
`pre-push` hook is added to log those.

Second `PreToolUse(Bash)` hook, this repo only (added 2026-10-17):
`public-docs-guardrail-check.sh` (+ `public-docs-guardrail-scan.py`). On any `git commit` it scans
the lines the commit adds to public `.md` docs (not `CLAUDE.md`, not `.claude/**`; staged,
unstaged and untracked, so `git add x && git commit` in one call is covered). It denies on any term
in the "Avoid these words" list of `POSITIONING_AND_SAFE_WORDS.md` (read fresh each run), iGaming,
compliance claims, exact latency numbers, or a link into a private `chavychaze` repo.
`GUARDRAIL_SKIP=1` as a leading prefix turns the deny into a human confirmation prompt, never an
allow. It covers the mechanical half only; lead order and factual drift still need the skill and
the checklist above. Fails open. Run `bash .claude/hooks/test-public-docs-guardrail-check.sh`
after any edit.

## How to explain things to the founder (WoWyrd family rule, since 2026-10-18)

Founder decision, after Karpathy's note on reading LLM output. Same rule in every WoWyrd repo.
- **Writing: "80% ASD-STE100" (Simplified Technical English).** One idea per sentence. Short
  sentences (≤20 words in steps, ≤25 in prose). Active voice. Use one word for one meaning, and
  don't use a synonym for variety. Give steps as numbered lists. For Ukrainian, use the same rules.
  STE is for English only, but its principles carry over.
- **Diagram first** when the answer is a flow, an architecture, a decision or a timeline: a Mermaid
  diagram in markdown, or SVG/PNG for decks. Text explains the diagram, not the other way round.
- **HTML page** (an Artifact, private by default) for big explainers, comparisons and anything
  interactive (a strategy map, a benchmark walk-through). The source stays in the repo as markdown.
  The page is a disposable view of it.
- **Explainer video: not now.** Revisit after the first design partner. It needs a TTS key or a
  local TTS and costs time.
- This changes **how** we explain, not **what** we claim. The guardrail and the no-invented-numbers
  rules still apply.
