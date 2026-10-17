#!/bin/bash
# PreToolUse(Bash) guard: (1) appends a local audit-trail line for every matched Bash call,
# (2) blocks a short list of hard-to-reverse git operations specifically when the session's
# permission mode is auto/bypass — never blocks them in a normal human-reviewed session.
#
# WHY THIS IS A CHECK AND NOT AN INSTRUCTION
# -------------------------------------------
# An auto-mode (or --dangerously-skip-permissions) session can self-approve every prompt,
# including a git push/force-push/history-rewrite nobody actually looked at. Ordinary edits,
# ordinary `git add`/`git commit` are NOT blocked — those are fine unattended and are how most
# work in this repo already happens; only the handful of operations that are genuinely hard to
# undo once they leave this machine (push, force-push, history rewrite, a --no-verify commit
# that skips the repo's own other hooks) get stopped, and only in auto/bypass mode.
#
# The audit line is written unconditionally (any mode), independent of the block decision —
# it's a local, gitignored operational log (.claude-audit.jsonl), not a commit artifact.
#
# Fails OPEN on any internal error (missing jq, unreadable input, not a git repo) — a broken
# guard must never block a tool call. Escape hatch for a genuine, deliberate exception:
# AUDIT_GUARD_SKIP=1 prefixed on the command. Since 2026-10-17 it does NOT allow the command: it
# turns the deny into permissionDecision "ask", so a human confirms that exact command in the UI.
# A sub-agent dispatched to write a spec read the old block message ("...prefix the command with
# AUDIT_GUARD_SKIP=1"), then pushed to main on its own. An escape hatch an agent can type alone
# isn't a human approval. Since the skip now only earns a prompt, the deny message names it
# again (2026-10-17 later): without it an agent whose user had said yes had no way to ask.

set -uo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
PERM_MODE="$(printf '%s' "$INPUT" | jq -r '.permission_mode // empty' 2>/dev/null)"
[ -z "$COMMAND" ] && exit 0

REPO_ROOT="$(cd "$(dirname "$0")" >/dev/null 2>&1 && git rev-parse --show-toplevel 2>/dev/null)"
[ -z "$REPO_ROOT" ] && exit 0

# --- 1. Audit trail: always, regardless of mode or what the command is ---
AUDIT_FILE="$REPO_ROOT/.claude-audit.jsonl"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SUMMARY="$(printf '%s' "$COMMAND" | head -c 200)"
jq -nc --arg ts "$TS" --arg mode "${PERM_MODE:-unknown}" --arg cmd "$SUMMARY" \
  '{ts:$ts, tool:"Bash", mode:$mode, command:$cmd}' >> "$AUDIT_FILE" 2>/dev/null || true

# --- 2. Circuit breaker: only in auto/bypass mode, only for the hard-to-reverse git ops ---
case "$PERM_MODE" in
  *bypass*|*auto*|*Auto*|*Bypass*) : ;;
  *) exit 0 ;;
esac

# Classification is done by tokenizing the command (python3 shlex), not by regex over the raw
# string. Regex was tried first and missed real shapes (fixed 2026-10-15 after a code review
# proved each one with the test suite still green): a bare `git push` on main (the target comes
# from the upstream, so "main" never appears in the command), `HEAD:main` / `main:main`
# refspecs, `+main` (a force-push spelled in the refspec), global options between `git` and the
# subcommand (`git -C . push --force`), `git reset X --hard`, and `git commit -n` (short form of
# --no-verify). Push policy is therefore fail-closed: in auto/bypass mode a push is allowed only
# when it names an explicit, non-main/master destination branch and carries no force flag.
#
# AUDIT_GUARD_SKIP=1 is honored only as a real leading env assignment on the git command itself
# (`AUDIT_GUARD_SKIP=1 git push ...`) — not anywhere in the string, where a commit message or
# heredoc mentioning it used to switch the guard off by accident.
REASON_DETAIL="$(GUARD_CMD="$COMMAND" python3 -I - 2>/dev/null <<'PY'
import os, re, shlex

PROTECTED = {"main", "master"}
GIT_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path",
                       "--super-prefix", "--config-env"}
PUSH_OPTS_WITH_VALUE = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
COMMIT_OPTS_WITH_VALUE = {"-m", "-F", "-C", "-c", "-t", "--message", "--file", "--author",
                          "--date", "--template", "--reuse-message", "--reedit-message",
                          "--fixup", "--squash", "--cleanup", "--trailer"}
PREFIX_WORDS = {"(", "{", "!", "then", "do", "else", "elif", "if", "while", "until",
                "env", "command", "nohup", "time", "exec", "sudo"}
SEPARATORS = {";", "&&", "||", "|", "&", "\n", ")", "}", "(", ";;", "|&"}
SHELLS = {"bash", "sh", "zsh", "dash"}


def segments(cmd):
    cmd = re.sub(r"\d*[<>]&\d*-?", " ", cmd)  # fd duplication (`2>&1`, `>&2`) — not a separator
    lex = shlex.shlex(cmd.replace("\n", " ; "), posix=True, punctuation_chars=";&|()")
    lex.whitespace_split = True
    seg, drop_next = [], False
    for tok in lex:
        if drop_next:  # filename after a bare redirection operator (`> out`)
            drop_next = False
            continue
        if re.fullmatch(r"\d*[<>]+", tok):  # `>`, `2>`, `>>` — also the `2>` half of `2>&1`
            drop_next = True
            continue
        if "<" in tok or ">" in tok:  # `>/dev/null`, `2>err.log`
            continue
        if tok in SEPARATORS or set(tok) <= set(";&|()"):
            if seg:
                yield seg
            seg = []
        else:
            seg.append(tok)
    if seg:
        yield seg


def short_flags(tok):
    return set(tok[1:]) if re.fullmatch(r"-[A-Za-z]+", tok) else set()


def args_without_values(args, opts_with_value):
    """Option/positional tokens, skipping the value that follows an option taking one."""
    out, skip = [], False
    for tok in args:
        if skip:
            skip = False
            continue
        if tok == "--":
            out.append(tok)
            continue
        if tok in opts_with_value:
            skip = True
            continue
        out.append(tok)
    return out


def classify_push(args):
    toks = args_without_values(args, PUSH_OPTS_WITH_VALUE)
    for tok in toks:
        if tok.startswith("--force") or tok in {"--mirror", "--all", "--delete", "--prune"}:
            return f"a force/mirror/delete push ({tok})"
        if "f" in short_flags(tok) or "d" in short_flags(tok):
            return f"a force/delete push ({tok})"
    positionals = [t for t in toks if not t.startswith("-")]
    if len(positionals) < 2:
        return ("a push with no explicit destination branch (target comes from the current "
                "branch/upstream, which may be main)")
    for ref in positionals[1:]:
        if ref.startswith("+"):
            return f"a force-push via refspec ({ref})"
        dest = ref.split(":", 1)[-1]
        dest = dest[len("refs/heads/"):] if dest.startswith("refs/heads/") else dest
        if dest in PROTECTED or dest == "HEAD":
            return f"a push to {dest} ({ref})"
    return ""


def classify_git(args):
    i = 0
    while i < len(args) and args[i].startswith("-"):
        i += 2 if args[i] in GIT_OPTS_WITH_VALUE else 1
    if i >= len(args):
        return ""
    sub, rest = args[i], args[i + 1:]
    if sub == "push":
        return classify_push(rest)
    if sub == "commit":
        toks = args_without_values(rest, COMMIT_OPTS_WITH_VALUE)
        if "--no-verify" in toks or any("n" in short_flags(t) for t in toks):
            return "a --no-verify commit (skips this repo's own other hooks)"
    if sub == "reset" and "--hard" in rest:
        return "git reset --hard"
    if sub in {"rebase", "filter-branch", "filter-repo"}:
        return f"a history-rewriting git operation ({sub})"
    return ""


def classify(cmd, depth=0, skip_inherited=False):
    """Return (detail, skipped): the first risky op not covered by AUDIT_GUARD_SKIP=1 wins
    (deny); if every risky op carried the skip, return the first one with skipped=True (ask)."""
    skipped_detail = ""
    for seg in segments(cmd):
        skip = skip_inherited
        while seg and (seg[0] in PREFIX_WORDS or re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", seg[0])):
            if seg[0] == "AUDIT_GUARD_SKIP=1":
                skip = True
            seg = seg[1:]
        if not seg:
            continue
        prog = os.path.basename(seg[0])
        found = ""
        if prog in SHELLS and depth < 3 and "-c" in seg[1:-1]:
            inner, inner_skipped = classify(seg[seg.index("-c") + 1], depth + 1, skip)
            if inner and not inner_skipped:
                return inner, False
            if inner:
                skipped_detail = skipped_detail or inner
        if prog == "git":
            found = classify_git(seg[1:])
        if found and not skip:
            return found, False
        if found:
            skipped_detail = skipped_detail or found
    return skipped_detail, bool(skipped_detail)


cmd = os.environ.get("GUARD_CMD", "")
try:
    detail, skipped = classify(cmd)
    if detail:
        print(("ASK:" if skipped else "") + detail)
except ValueError:
    # Unparseable (e.g. unbalanced quotes): fail closed on the obvious shapes rather than open.
    # A skip token here cannot be attributed to a segment, so it only earns a human prompt.
    # (No apostrophes anywhere in this heredoc: macOS bash 3.2 mis-parses them inside $(...).)
    if re.search(r"\bgit\b", cmd) and re.search(
            r"\b(push|rebase|filter-branch|filter-repo)\b|--hard|--no-verify", cmd):
        prefix = "ASK:" if "AUDIT_GUARD_SKIP=1" in cmd else ""
        print(prefix + "an unparseable command containing a hard-to-reverse git operation")
PY
)"

[ -z "$REASON_DETAIL" ] && exit 0

case "$REASON_DETAIL" in
  ASK:*)
    REASON="Human approval required: this session's permission mode is auto/bypass and the
command is ${REASON_DETAIL#ASK:}, a hard-to-reverse operation once it leaves this machine.
Approve only if you asked for exactly this command."
    jq -n --arg reason "$REASON" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: $reason
      }
    }'
    exit 0 ;;
esac

REASON="Blocked: this session's permission mode is auto/bypass (no human reviewing each
prompt), and the command is $REASON_DETAIL, a hard-to-reverse operation once it leaves this
machine. Do not retry it as-is or look for a way around this guard. Ask the user whether they
want exactly this command run. Only if they say yes, re-run it with AUDIT_GUARD_SKIP=1 as a
leading prefix: that bypasses nothing, it shows the user a confirmation prompt for this exact
command, and only their approval in that prompt lets it run."

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 2
