#!/usr/bin/env bash
# Hermetic test suite for public-docs-guardrail-check.sh (+ its scanner). No real Claude Code
# session needed, never touches the real repo: runs against a throwaway git repo and a fixture
# positioning doc, then once more against the real POSITIONING_AND_SAFE_WORDS.md if present.
# Usage: bash .claude/hooks/test-public-docs-guardrail-check.sh   Exit 0 = every case as expected.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
GUARD="$HERE/public-docs-guardrail-check.sh"
SCANNER="$HERE/public-docs-guardrail-scan.py"
REAL_POSITIONING="$HERE/../../../WoWyrd-bussiness/docs/messaging/POSITIONING_AND_SAFE_WORDS.md"

bash -n "$GUARD" || { echo "FAIL  hook does not parse (bash -n)"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
mkdir -p "$REPO"
cat >"$TMP/positioning.md" <<'MD'
# Fixture

## Avoid these words

**Since 2026-10-22 (founder):** "PoC" · "we are building" — it is a built product; offer a pilot. ·
production-ready · patented · "1–5 µs" / "10,000× faster" or any exact latency claim ·
"AI-powered" as the headline · "replaces your fraud/AML/KYC stack".

## Next section
not-a-term
MD
(
  cd "$REPO"
  git init -q
  git config user.email test@example.com
  git config user.name test
  printf '# Readme\n\nShips patented legacy text already in HEAD.\n' >README.md
  git add README.md && git commit -qm init
)

export PUBLIC_DOCS_GUARD_REPO="$REPO"
export PUBLIC_DOCS_GUARD_POSITIONING="$TMP/positioning.md"
fail=0

payload() { jq -nc --arg cmd "$1" '{tool_input:{command:$cmd}, permission_mode:"auto"}'; }

run() {  # run <expected-exit> <label> <command> [expected decision: deny|ask|none]
  local want="$1" label="$2" cmd="$3" decision="${4:-none}" out got seen
  out="$(payload "$cmd" | bash "$GUARD" 2>/dev/null)"; got=$?
  seen="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null || echo none)"
  [ -z "$out" ] && seen=none
  if [ "$got" = "$want" ] && [ "$seen" = "$decision" ]; then
    printf 'ok    %-58s exit %s %s\n' "$label" "$got" "$seen"
  else
    printf 'FAIL  %-58s exit %s %s (want %s %s)\n' "$label" "$got" "$seen" "$want" "$decision"
    printf '        stdout: %s\n' "$out"; fail=1
  fi
}

reset_repo() { git -C "$REPO" reset -q --hard HEAD; git -C "$REPO" clean -qfd; }

echo "== clean / irrelevant commands pass =="
run 0 "non-commit command ignored"                    "git status"
run 0 "commit with no doc changes"                    "git commit -m x"
printf 'Plain, guardrail-clean sentence.\n' >>"$REPO/README.md"
run 0 "commit adding clean text"                      "git commit -am x"
run 0 "pre-existing banned word in HEAD not re-flagged" "git commit -am x"
reset_repo

echo "== red flags in added text are denied =="
printf 'Now production-ready.\n' >>"$REPO/README.md"
run 2 "avoid-list term (unstaged, add && commit shape)" "git add README.md && git commit -m x" deny
git -C "$REPO" add README.md
run 2 "avoid-list term (staged)"                      "git commit -m x" deny
reset_repo
printf 'Fast: 10,000× faster than before.\n' >"$REPO/INSTALL.md"
run 2 "untracked new doc scanned"                     "git add INSTALL.md && git commit -m x" deny
reset_repo
printf 'SBOM: https://github.com/chavychaze/wowyrd-lts/releases\n' >>"$REPO/README.md"
run 2 "link into a private repo"                      "git commit -am x" deny
reset_repo
printf 'Public: https://github.com/chavychaze/wowyrd-pub/releases\n' >>"$REPO/README.md"
run 0 "link into wowyrd-pub itself is fine"           "git commit -am x"
reset_repo
printf '  --certificate-identity-regexp "^https://github.com/chavychaze/.*$" \\\n' >>"$REPO/README.md"
run 0 "cosign identity regexp is not a repo link"     "git commit -am x"
reset_repo
for line in 'Great for iGaming.' 'NBU-compliant out of the box.' 'Decides in 5 µs.'; do
  printf '%s\n' "$line" >>"$REPO/README.md"
  run 2 "extra pattern: $line"                        "git commit -am x" deny
  reset_repo
done
printf 'Detail: the term not-a-term lives outside the avoid section.\n' >>"$REPO/README.md"
run 0 "only the avoid section is parsed"              "git commit -am x"
reset_repo
for line in 'A minimal PoC stack.' 'We are building it.'; do
  printf '%s\n' "$line" >>"$REPO/README.md"
  run 2 "term after a bold label: $line"              "git commit -am x" deny
  reset_repo
done
printf 'The epoch timestamp is a built product feature; offer a pilot.\n' >>"$REPO/README.md"
run 0 "word-bounded term, rationale prose not a term" "git commit -am x"
reset_repo

echo "== non-public files are not scanned =="
printf 'production-ready\n' >>"$REPO/CLAUDE.md"
mkdir -p "$REPO/.claude/skills/x" && printf 'patented\n' >"$REPO/.claude/skills/x/SKILL.md"
printf 'production-ready\n' >"$REPO/notes.txt"
run 0 "CLAUDE.md, .claude/**, non-.md ignored"         "git add -A && git commit -m x"
reset_repo

echo "== GUARDRAIL_SKIP=1 earns a human prompt, never a silent allow =="
printf 'Now production-ready.\n' >>"$REPO/README.md"
run 0 "leading skip prefix -> ask"                    "GUARDRAIL_SKIP=1 git commit -am x" ask
run 0 "skip after && -> ask"                          "git add -A && GUARDRAIL_SKIP=1 git commit -m x" ask
run 2 "skip only inside the message -> still deny"    "git commit -am 'GUARDRAIL_SKIP=1 git x'" deny
out="$(payload 'git commit -am x' | bash "$GUARD" 2>/dev/null)"
if printf '%s' "$out" | grep -q 'confirmation prompt' && printf '%s' "$out" | grep -q 'production-ready'; then
  echo "ok    deny message quotes the finding and frames the skip as a prompt"
else
  echo "FAIL  deny message must quote the finding and frame the skip as a prompt"; fail=1
fi
reset_repo

echo "== fails open =="
out="$(printf '' | bash "$GUARD" 2>/dev/null)"; got=$?
[ "$got" = 0 ] && [ -z "$out" ] && echo "ok    empty stdin" || { echo "FAIL  empty stdin (exit $got)"; fail=1; }
out="$(printf 'not json' | bash "$GUARD" 2>/dev/null)"; got=$?
[ "$got" = 0 ] && echo "ok    malformed JSON" || { echo "FAIL  malformed JSON (exit $got)"; fail=1; }
printf 'Now production-ready.\n' >>"$REPO/README.md"
got=0; PUBLIC_DOCS_GUARD_POSITIONING="$TMP/missing.md" bash "$GUARD" < <(payload 'git commit -am x') >/dev/null 2>&1 || got=$?
[ "$got" = 0 ] && echo "ok    missing positioning doc" || { echo "FAIL  missing positioning doc (exit $got)"; fail=1; }
printf 'no avoid section here\n' >"$TMP/bad.md"
got=0; PUBLIC_DOCS_GUARD_POSITIONING="$TMP/bad.md" bash "$GUARD" < <(payload 'git commit -am x') >/dev/null 2>&1 || got=$?
[ "$got" = 0 ] && echo "ok    positioning doc without avoid section" || { echo "FAIL  bad positioning doc (exit $got)"; fail=1; }
got=0; PUBLIC_DOCS_GUARD_REPO="$TMP/not-a-repo" bash "$GUARD" < <(payload 'git commit -am x') >/dev/null 2>&1 || got=$?
[ "$got" = 0 ] && echo "ok    not a git repo" || { echo "FAIL  not a git repo (exit $got)"; fail=1; }
reset_repo

echo "== real positioning doc parses into a sane term list =="
if [ -f "$REAL_POSITIONING" ]; then
  terms="$(python3 -I -B -c 'import importlib.util,sys
s=importlib.util.spec_from_file_location("scan",sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
print("\n".join(m.avoid_terms(sys.argv[2])))' "$SCANNER" "$REAL_POSITIONING")"
  for want in production-ready patented AI-powered PoC prototype "we are building"; do
    if printf '%s\n' "$terms" | grep -qx "$want"; then echo "ok    real doc yields term: $want"
    else echo "FAIL  real doc missing term: $want"; fail=1; fi
  done
  if printf '%s\n' "$terms" | grep -qE '^.{0,2}$|[()]'; then
    echo "FAIL  real doc yields an empty/parenthetical term"; fail=1
  else echo "ok    real doc terms have no empty/parenthetical fragments"; fi
else
  echo "skip  real positioning doc not found at $REAL_POSITIONING"
fi

echo
[ "$fail" = 0 ] && echo "ALL CHECKS PASS" || echo "SOME CHECKS FAILED"
exit "$fail"
