#!/usr/bin/env bash
# Hermetic, standalone test suite for claude-audit-guard.sh — no real Claude Code session needed.
# Usage: bash .claude/hooks/test-claude-audit-guard.sh   (from anywhere; locates its sibling hook
# via $(dirname "$0"), so this file is copy-pasteable verbatim into any of the 5 WoWyrd-family repos).
#
# Runs the hook against a throwaway temp git repo, never the real one — so repeated runs never
# pollute the real .claude-audit.jsonl and never risk tripping the hook's own circuit breaker on
# this machine's real git state. Exit 0 = every case behaved as expected.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
GUARD_SRC="$HERE/claude-audit-guard.sh"

if [ ! -f "$GUARD_SRC" ]; then
  echo "test-claude-audit-guard: claude-audit-guard.sh not found next to this script, nothing to test." >&2
  exit 1
fi

TMP_REPO="$(mktemp -d)"
trap 'rm -rf "$TMP_REPO"' EXIT

mkdir -p "$TMP_REPO/.claude/hooks"
cp "$GUARD_SRC" "$TMP_REPO/.claude/hooks/claude-audit-guard.sh"
chmod +x "$TMP_REPO/.claude/hooks/claude-audit-guard.sh"
(
  cd "$TMP_REPO"
  git init -q
  git config user.email test@example.com
  git config user.name test
)
GUARD="$TMP_REPO/.claude/hooks/claude-audit-guard.sh"
AUDIT_FILE="$TMP_REPO/.claude-audit.jsonl"

fail=0

payload() {  # payload <mode> <command>
  jq -nc --arg mode "$1" --arg cmd "$2" '{tool_input:{command:$cmd}, permission_mode:$mode}'
}

run() {  # run <expected-exit> <label> <json>
  local want="$1" label="$2" json="$3" got
  printf '%s' "$json" | bash "$GUARD" >/tmp/audit-guard-test-out.$$ 2>/tmp/audit-guard-test-err.$$
  got=$?
  if [ "$got" = "$want" ]; then
    printf 'ok    %-55s exit %s\n' "$label" "$got"
  else
    printf 'FAIL  %-55s exit %s (want %s)\n' "$label" "$got" "$want"
    sed 's/^/        stderr: /' /tmp/audit-guard-test-err.$$
    sed 's/^/        stdout: /' /tmp/audit-guard-test-out.$$
    fail=1
  fi
  rm -f /tmp/audit-guard-test-out.$$ /tmp/audit-guard-test-err.$$
}

echo "== auto/bypass mode: risky git ops blocked =="
run 2 "bypass: git push --force blocked"          "$(payload bypassPermissions 'git push --force origin main')"
run 2 "auto: git push -f main blocked"            "$(payload auto 'git push -f origin main')"
run 2 "bypass: push to main (no force) blocked"   "$(payload bypassPermissions 'git push origin main')"
run 2 "auto: git reset --hard blocked"            "$(payload auto 'git reset --hard HEAD~3')"
run 2 "bypass: --no-verify commit blocked"        "$(payload bypassPermissions 'git commit -m x --no-verify')"
run 2 "auto: git rebase blocked"                  "$(payload auto 'git rebase main')"
run 2 "bypass: git filter-branch blocked"         "$(payload bypassPermissions 'git filter-branch --tree-filter x')"

echo "== auto/bypass mode: shapes the old regex missed (code review 2026-10-15) =="
run 2 "auto: bare git push (upstream may be main)" "$(payload auto 'git push')"
run 2 "auto: git push origin (no refspec)"        "$(payload auto 'git push origin')"
run 2 "auto: HEAD:main refspec"                   "$(payload auto 'git push origin HEAD:main')"
run 2 "auto: main:main refspec"                   "$(payload auto 'git push origin main:main')"
run 2 "auto: refs/heads/master refspec"           "$(payload auto 'git push origin feature:refs/heads/master')"
run 2 "auto: +refspec force-push"                 "$(payload auto 'git push origin +feature/x')"
run 2 "auto: --force-with-lease"                  "$(payload auto 'git push --force-with-lease origin feature/x')"
run 2 "auto: combined short flags -fu"            "$(payload auto 'git push -fu origin feature/x')"
run 2 "auto: global opts before push"             "$(payload auto 'git -C . push --force origin feature/x')"
run 2 "auto: -c opt before rebase"                "$(payload auto 'git -c core.editor=true rebase main')"
run 2 "auto: reset X --hard"                      "$(payload auto 'git reset HEAD~1 --hard')"
run 2 "auto: commit -n (short --no-verify)"       "$(payload auto 'git commit -nm x')"
run 2 "auto: push after && chain"                 "$(payload auto 'git add -A && git commit -m x && git push')"
run 2 "auto: push with 2>&1 redirect"             "$(payload auto 'git push origin 2>&1')"
run 2 "auto: push to main with >/dev/null"        "$(payload auto 'git push origin main >/dev/null')"
run 2 "auto: push inside bash -c"                 "$(payload auto "bash -c 'git push --force origin x'")"
run 2 "auto: skip token only in commit message"   "$(payload auto 'git commit --no-verify -m "AUDIT_GUARD_SKIP=1 docs"')"
run 2 "auto: unbalanced quotes still caught"      "$(payload auto "git push --force origin main 'oops")"

echo "== auto/bypass mode: ordinary ops allowed =="
run 0 "bypass: ordinary git commit allowed"       "$(payload bypassPermissions 'git commit -m x')"
run 0 "auto: commit message mentioning -n allowed" "$(payload auto 'git commit -m "-n flag docs"')"
run 0 "auto: git add explicit path allowed"       "$(payload auto 'git add docs/a.md docs/b.md')"
run 0 "auto: commit --only paths allowed"         "$(payload auto 'git commit --only docs/a.md -m x')"
run 0 "auto: commit -qm allowed"                  "$(payload auto 'git commit -qm "add all the things"')"
run 0 "default: commit -am allowed (human mode)"  "$(payload default 'git commit -am x')"
run 2 "auto: commit -am blocked"                  "$(payload auto 'git commit -am x')"
run 2 "auto: commit -qam blocked"                 "$(payload auto 'git commit -qam x')"
run 2 "bypass: commit --all blocked"              "$(payload bypassPermissions 'git commit --all -m x')"
run 2 "auto: git add -A blocked"                  "$(payload auto 'git add -A')"
run 2 "auto: git add --all blocked"               "$(payload auto 'git add --all docs')"
run 2 "auto: git add . blocked"                   "$(payload auto 'git add .')"
run 2 "auto: git add -u blocked"                  "$(payload auto 'git add -u')"
run 2 "auto: git -C other add -A blocked"         "$(payload auto 'git -C ../WoWyrd add -A')"
run 2 "auto: chained add -A && commit blocked"    "$(payload auto 'cd x && git add -A && git commit -m y')"
run 0 "auto: push to feature branch allowed"      "$(payload auto 'git push origin feature/x')"
run 0 "auto: push -u feature branch allowed"      "$(payload auto 'git push -u origin feature/x 2>&1')"
run 0 "auto: push HEAD:feature allowed"           "$(payload auto 'git push origin HEAD:feature/x')"
run 0 "auto: soft reset allowed"                  "$(payload auto 'git reset --soft HEAD~1')"
run 0 "auto: grep for 'git push' allowed"         "$(payload auto 'grep -rn "git push" docs/')"
run 0 "bypass: git status allowed"                "$(payload bypassPermissions 'git status --short')"

echo "== default (human-reviewed) mode: nothing blocked, even the risky ops =="
run 0 "default: git push --force allowed"         "$(payload default 'git push --force origin main')"
run 0 "default: git reset --hard allowed"         "$(payload default 'git reset --hard HEAD~3')"
run 0 "default: --no-verify commit allowed"       "$(payload default 'git commit -m x --no-verify')"
run 0 "default: git rebase allowed"               "$(payload default 'git rebase main')"

echo "== escape hatch: AUDIT_GUARD_SKIP=1 earns a human prompt (ask), never a silent allow =="
run_ask() {  # run_ask <label> <json>: exit 0 AND stdout carries permissionDecision "ask"
  local label="$1" json="$2" out got
  out="$(printf '%s' "$json" | bash "$GUARD" 2>/dev/null)"; got=$?
  if [ "$got" = 0 ] && printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null 2>&1; then
    printf 'ok    %-55s ask\n' "$label"
  else
    printf 'FAIL  %-55s exit %s, not ask\n' "$label" "$got"; printf '        stdout: %s\n' "$out"; fail=1
  fi
}
run_ask "bypass: force-push with skip -> ask"      "$(payload bypassPermissions 'AUDIT_GUARD_SKIP=1 git push --force origin main')"
run_ask "auto: push main with skip -> ask"         "$(payload auto 'AUDIT_GUARD_SKIP=1 git push origin main 2>&1')"
run_ask "auto: skip inside bash -c -> ask"         "$(payload auto "bash -c 'AUDIT_GUARD_SKIP=1 git push origin main'")"
run_ask "auto: unparseable with skip -> ask"       "$(payload auto "AUDIT_GUARD_SKIP=1 git push origin main 'oops")"
run 2 "auto: skip on one segment, not the other"   "$(payload auto 'AUDIT_GUARD_SKIP=1 git push origin main && git reset --hard HEAD~1')"
run 0 "auto: skip on harmless command is a no-op"  "$(payload auto 'AUDIT_GUARD_SKIP=1 git status')"
deny_out="$(printf '%s' "$(payload auto 'git push origin main')" | bash "$GUARD" 2>/dev/null)"
if printf '%s' "$deny_out" | grep -q 'confirmation prompt'; then
  echo "ok    deny message frames the skip as a human confirmation prompt"
else
  echo "FAIL  deny message must say the skip only asks the user for confirmation"; fail=1
fi

echo "== fails open =="
run 0 "empty stdin"                               ""
run 0 "malformed JSON"                            "not json at all"
run 0 "no tool_input.command field"               '{"permission_mode":"bypassPermissions"}'

echo "== audit trail actually grows =="
LINES_BEFORE=0
[ -f "$AUDIT_FILE" ] && LINES_BEFORE="$(wc -l < "$AUDIT_FILE" | tr -d ' ')"
printf '%s' "$(payload default 'git status')" | bash "$GUARD" >/dev/null 2>&1
LINES_AFTER="$(wc -l < "$AUDIT_FILE" | tr -d ' ')"
if [ "$LINES_AFTER" -gt "$LINES_BEFORE" ]; then
  echo "ok    audit file grew ($LINES_BEFORE -> $LINES_AFTER lines)"
else
  echo "FAIL  audit file did not grow ($LINES_BEFORE -> $LINES_AFTER)"
  fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "ALL CHECKS PASS"
else
  echo "SOME CHECKS FAILED"
fi
exit "$fail"
