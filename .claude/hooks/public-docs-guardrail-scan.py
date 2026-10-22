#!/usr/bin/env python3
"""Scan the text a commit would add to wowyrd-pub's public docs for guardrail red flags.

Called by public-docs-guardrail-check.sh. Prints one finding per line ("file: term: line") and
nothing when clean. Never raises: any internal error prints nothing, so the hook fails open.

Usage: public-docs-guardrail-scan.py <repo_root> <positioning_doc>
"""
import re
import subprocess
import sys

# Always-on red flags not phrased as a literal term in POSITIONING_AND_SAFE_WORDS.md's avoid list.
# Each was named explicitly by the master session's guardrail rules (2026-10-17) or the doc's
# own prose: iGaming is reactive-only, compliance claims are never made, and no latency numbers.
EXTRA_PATTERNS = [
    ("iGaming (reactive-only, never proactive)", re.compile(r"i-?gaming", re.I)),
    ("compliance claim", re.compile(r"\bcompliant\b|NBU-compliant|відповідає вимогам НБУ", re.I)),
    ("exact latency number", re.compile(r"\b\d+(?:[.,]\d+)?\s?(?:µs|us|ns|мкс)\b|\b\d[\d,]*\s?×\s?faster", re.I)),
    # wowyrd-pub is public; every other chavychaze repo is private, so a customer gets a 404.
    # A repo name starts with a word character, so the cosign identity regexp
    # "github.com/chavychaze/.*$" in INSTALL.md is not mistaken for a link.
    ("link into a private repo", re.compile(r"github\.com/chavychaze/(?!wowyrd-pub\b)\w[\w.-]*", re.I)),
]

PUBLIC_DOC = re.compile(r"\.md$", re.I)
NOT_PUBLIC = re.compile(r"(^|/)CLAUDE\.md$|^\.claude/", re.I)


def avoid_terms(positioning_doc):
    """Literal terms from the doc's '## Avoid these words' section, read fresh every run."""
    with open(positioning_doc, encoding="utf-8") as f:
        text = f.read()
    section = text.split("## Avoid these words", 1)[1].split("\n## ", 1)[0]
    terms = []
    for item in section.replace("\n", " ").split("·"):
        item = re.sub(r"\*\*[^*]*:\*\*", "", item)  # a bold label such as "**Since <date>:**"
        item = re.sub(r"\([^)]*\)", "", item)
        item = item.split(" — ")[0]  # a rationale after an em dash is prose, not a term
        item = item.split(" or any ")[0]
        item = re.sub(r"\bas the headline\b", "", item)
        for part in item.split(" / "):
            term = part.strip().strip("\"“”.").strip()
            if term:
                terms.append(term)
    return terms


def git(repo, *args):
    return subprocess.run(
        ["git", "-c", "core.quotepath=false", "-C", repo, *args],
        capture_output=True, text=True, check=True,
    ).stdout


def added_lines(repo):
    """(file, line) pairs for text new relative to HEAD: staged + unstaged + untracked, so a
    `git add x && git commit` in one Bash call is covered even though the add hasn't run yet."""
    pairs = []
    current = None
    for raw in git(repo, "diff", "HEAD", "-U0", "--no-color").splitlines():
        if raw.startswith("+++ "):
            current = raw[6:] if raw.startswith("+++ b/") else None
        elif raw.startswith("+") and current:
            pairs.append((current, raw[1:]))
    for path in git(repo, "ls-files", "--others", "--exclude-standard").splitlines():
        try:
            with open(f"{repo}/{path}", encoding="utf-8") as f:
                pairs.extend((path, line.rstrip("\n")) for line in f)
        except (OSError, UnicodeDecodeError):
            continue
    return [(p, l) for p, l in pairs if PUBLIC_DOC.search(p) and not NOT_PUBLIC.search(p)]


def term_pattern(term):
    """Case-insensitive literal match, bounded at word edges so "PoC" does not match "epoch"."""
    start = r"\b" if re.match(r"\w", term) else ""
    end = r"\b" if re.search(r"\w$", term) else ""
    return re.compile(start + re.escape(term) + end, re.I)


def scan(lines, terms):
    patterns = [(t, term_pattern(t)) for t in terms] + EXTRA_PATTERNS
    findings = []
    for path, line in lines:
        for label, pattern in patterns:
            if pattern.search(line):
                findings.append(f"{path}: {label}: {line.strip()}")
    return findings


def main(argv):
    try:
        repo, positioning_doc = argv[1], argv[2]
        findings = scan(added_lines(repo), avoid_terms(positioning_doc))
    except Exception:  # fail open: a broken scanner must never block a commit
        return 0
    print("\n".join(findings))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
