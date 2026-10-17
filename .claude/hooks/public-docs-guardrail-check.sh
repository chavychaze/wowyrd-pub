#!/bin/bash
# PreToolUse(Bash) guard: refuse a `git commit` whose new public-doc text (README*.md, INSTALL.md,
# any non-CLAUDE .md) contains a guardrail red flag from
# ../WoWyrd-bussiness/docs/messaging/POSITIONING_AND_SAFE_WORDS.md.
#
# WHY THIS IS A CHECK AND NOT AN INSTRUCTION
# -------------------------------------------
# CLAUDE.md says to run wowyrd-guardrail-checker before changing wording here, but on 2026-10-17
# that skill was not even installed in this repo, and README/INSTALL edits went in with nothing
# prompting a check. The same day, INSTALL.md shipped a link into the private wowyrd-lts repo that
# every customer would hit as a 404. A deterministic scan of the added lines catches the
# mechanical part (banned words, private links) every time; the skill still owns the judgment
# part (lead order, factual drift), and the deny message says so.
#
# GUARDRAIL_SKIP=1 as a leading prefix turns the deny into a human confirmation prompt ("ask"),
# never a silent allow: an escape hatch an agent can type unaided is not a review.
#
# Fails OPEN on any internal error: a broken guard must never block committing.

set -uo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$COMMAND" ] && exit 0

printf '%s' "$COMMAND" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+([^;&|]*[[:space:]])?commit([[:space:]]|$)' || exit 0

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="${PUBLIC_DOCS_GUARD_REPO:-$(cd "$HOOK_DIR/../.." && pwd)}"
POSITIONING="${PUBLIC_DOCS_GUARD_POSITIONING:-$REPO/../WoWyrd-bussiness/docs/messaging/POSITIONING_AND_SAFE_WORDS.md}"
command -v python3 >/dev/null 2>&1 || exit 0
[ -f "$POSITIONING" ] || exit 0

FINDINGS="$(python3 -I "$HOOK_DIR/public-docs-guardrail-scan.py" "$REPO" "$POSITIONING" 2>/dev/null || true)"
[ -z "$FINDINGS" ] && exit 0

DETAIL="This commit adds public-facing text (this repo is public) with guardrail red flags:

$(printf '%s\n' "$FINDINGS" | sed 's/^/    /')

Fix the wording, or run the wowyrd-guardrail-checker skill against
../WoWyrd-bussiness/docs/messaging/POSITIONING_AND_SAFE_WORDS.md to confirm it is fine."

if printf '%s' "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)GUARDRAIL_SKIP=1[[:space:]]+git[[:space:]]'; then
  jq -n --arg reason "Human approval required. $DETAIL Approve only if you reviewed these lines." '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
fi

jq -n --arg reason "$DETAIL If the user confirms it is a genuine false positive, re-run the commit with GUARDRAIL_SKIP=1 as a leading prefix: that bypasses nothing, it shows the user a confirmation prompt for this exact commit." '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 2
