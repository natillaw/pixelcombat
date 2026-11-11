#!/usr/bin/env python3
"""Tactical Summoners multi-agent sync tool. Python 3.8+, stdlib only.
Run from the repo root: python tools/sync/ts_sync.py <command> --help"""
import argparse, datetime, hashlib, re, subprocess, sys
from pathlib import Path

def find_root():
    p = Path(__file__).resolve()
    for d in [p.parent] + list(p.parents):
        if (d / "docs" / "ai-context").is_dir():
            return d
    sys.exit("docs/ai-context not found. Run from the repo root.")

ROOT = find_root()
CTX = ROOT / "docs" / "ai-context"
BOARD = CTX / "TASK_BOARD.md"
LOG = CTX / "HANDOFF_LOG.md"
BUNDLE = ROOT / "CONTEXT_BUNDLE.md"
LITE = ROOT / "CONTEXT_LITE.md"
VERSION = "1.7"

ORDER = ["PROJECT_BIBLE", "CURRENT_STATE", "TASK_BOARD", "HANDOFF_LOG", "DECISIONS",
         "ROADMAP", "CONTROL_AND_REALTIME_MISSIONS", "SUMMONS_AND_HERO_GENERATION",
         "COMBAT_AND_STATS", "REFERENCE_SYSTEMS", "DESIGN_GAPS", "AGENT_SYNC", "ASSET_MANIFEST", "CHANGELOG"]

def now():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

def doc_files():
    files = {f.stem: f for f in CTX.glob("*.md")}
    out = [files.pop(n) for n in ORDER if n in files]
    out += sorted(files.values())
    art = ROOT / "docs" / "art" / "ART_DIRECTION.md"
    if art.exists():
        out.append(art)
    for f in (ROOT / "AGENTS.md",):
        if f.exists():
            out.insert(0, f)
    return out

def state_hash():
    h = hashlib.sha256()
    for f in sorted(CTX.glob("*.md")):
        h.update(f.name.encode())
        h.update(f.read_bytes())
    return h.hexdigest()[:12]

def git(*a):
    try:
        r = subprocess.run(["git", *a], cwd=ROOT, capture_output=True, text=True, timeout=15)
        return r.stdout.strip() if r.returncode == 0 else None
    except Exception:
        return None

# ---------- task board ----------
def read_board():
    s = BOARD.read_text(encoding="utf-8")
    m = re.search(r"(<!-- TASKS:BEGIN -->\n)(.*?)(<!-- TASKS:END -->)", s, re.S)
    if not m:
        sys.exit("TASK_BOARD.md markers missing")
    lines = m.group(2).strip().splitlines()
    header, rows = lines[:2], []
    for l in lines[2:]:
        c = [x.strip() for x in l.strip().strip("|").split("|")]
        if len(c) == 7:
            rows.append(c)
    return s, m, header, rows

def write_board(s, m, header, rows):
    body = "\n".join(header + ["| " + " | ".join(r) + " |" for r in rows]) + "\n"
    BOARD.write_text(s[:m.start(2)] + body + s[m.start(3):], encoding="utf-8")

def cmd_start(a):
    print(f"Tactical Summoners pack v{VERSION}  STATE_HASH={state_hash()}")
    _, _, _, rows = read_board()
    print("\nClaims:")
    active = [r for r in rows if r[3] in ("claimed", "blocked")]
    for r in active:
        print(f"  {r[0]} [{r[3]}] {r[4]} - {r[1]} (files: {r[5]}, {r[6]})")
    if not active:
        print("  none")
    print("\nOpen tasks:", ", ".join(r[0] for r in rows if r[3] == "open") or "none")
    s = LOG.read_text(encoding="utf-8")
    entries = re.findall(r"(## .*?)(?=\n## |\n<!-- LOG:END)", s, re.S)
    print("\nLast log entry:\n" + (entries[-1].strip() if entries else "  none"))
    br = git("rev-parse", "--abbrev-ref", "HEAD")
    if br:
        print(f"\nGit branch: {br}\n{git('status', '--short') or 'clean'}")
    else:
        print("\nGit: not a repository (or git missing). Initialize it: git init")

def cmd_claim(a):
    s, m, h, rows = read_board()
    for r in rows:
        if r[0] == a.task:
            if r[3] == "claimed" and r[4] != a.agent:
                sys.exit(f"{a.task} already claimed by {r[4]} ({r[6]}). Coordinate or wait.")
            r[3], r[4], r[5], r[6] = "claimed", a.agent, a.files or "-", now()
            write_board(s, m, h, rows)
            print(f"{a.task} claimed by {a.agent}")
            return
    sys.exit("task not found")

def cmd_release(a):
    s, m, h, rows = read_board()
    status = {"done": "done", "blocked": "blocked", "handoff": "open"}[a.status]
    for r in rows:
        if r[0] == a.task:
            r[3], r[6] = status, now()
            if a.status != "blocked":
                r[4] = "-"
            write_board(s, m, h, rows)
            print(f"{a.task} -> {status}")
            return
    sys.exit("task not found")

def cmd_log(a):
    s = LOG.read_text(encoding="utf-8")
    entry = (f"## {now()} — {a.agent}\n- Did: {a.did}\n- Verified: {a.verified}\n"
             f"- Next: {a.next}\n\n")
    if "<!-- LOG:END -->" not in s:
        sys.exit("LOG markers missing")
    LOG.write_text(s.replace("<!-- LOG:END -->", entry + "<!-- LOG:END -->"), encoding="utf-8")
    print("log entry added")

def cmd_bundle(a):
    h = state_hash()
    parts = [f"# TACTICAL SUMMONERS — CONTEXT BUNDLE\nPACK_VERSION: {VERSION}\nSTATE_HASH: {h}\n"
             f"BUILT: {now()}\n\nInstruction for the AI: read everything, obey AGENTS.md, state the "
             f"STATE_HASH you read, and end your session with a SESSION_END_PATCH.\n"]
    for f in doc_files():
        parts.append(f"\n\n{'=' * 70}\nFILE: {f.relative_to(ROOT).as_posix()}\n{'=' * 70}\n\n"
                     + f.read_text(encoding="utf-8"))
    BUNDLE.write_text("".join(parts), encoding="utf-8")
    print(f"{BUNDLE.name} written ({BUNDLE.stat().st_size // 1024} KB) STATE_HASH={h}")

def _last_entries(n):
    s = LOG.read_text(encoding="utf-8")
    entries = re.findall(r"(## .*?)(?=\n## |\n<!-- LOG:END)", s, re.S)
    return "\n".join(e.strip() for e in entries[-n:]) or "none"

def cmd_lite(a):
    """Small bundle (~8-12 KB): rules, state, open tasks, decision index, last log, optional specs."""
    h = state_hash()
    out = [f"# TACTICAL SUMMONERS — LITE CONTEXT\nPACK_VERSION: {VERSION}\nSTATE_HASH: {h}\nBUILT: {now()}\n"
           "\nFor the AI: this is all you need to start. Do NOT ask for other docs unless the task requires "
           "one (name the exact file). State the STATE_HASH, your task and a 5-line plan. "
           "At the end give: 1 log entry (Did/Verified/Next) + only the changed lines of CURRENT_STATE (no full files).\n"]
    rules = CTX / "RULES_LITE.md"
    if rules.exists():
        out.append("\n---\n" + rules.read_text(encoding="utf-8"))
    out.append("\n---\n" + (CTX / "CURRENT_STATE.md").read_text(encoding="utf-8"))
    _, _, _, rows = read_board()
    out.append("\n---\n## Tasks (not done)\n" + "\n".join(
        f"- {r[0]} [{r[3]}{'/' + r[4] if r[4] != '-' else ''}] (phase {r[2]}) {r[1]}" for r in rows if r[3] != "done"))
    dec = (CTX / "DECISIONS.md").read_text(encoding="utf-8")
    idx = re.findall(r"^## (D-\d+ — .*)$", dec, re.M)
    out.append("\n---\n## Decisions index (full text in DECISIONS.md)\n" + "\n".join("- " + i for i in idx))
    out.append("\n---\n## Last handoff entries\n" + _last_entries(2))
    for name in (a.spec or []):
        m = [f for f in doc_files() if f.stem.upper().startswith(name.upper())]
        if not m:
            sys.exit(f"spec '{name}' not found")
        out.append(f"\n---\n## SPEC: {m[0].relative_to(ROOT).as_posix()}\n" + m[0].read_text(encoding="utf-8"))
    LITE.write_text("".join(out), encoding="utf-8")
    print(f"{LITE.name} written ({LITE.stat().st_size / 1024:.1f} KB, ~{LITE.stat().st_size // 4} tokens) STATE_HASH={h}")

SECRET = re.compile(r"(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|api[_-]?key\s*[:=]\s*\S{12,}|BEGIN (RSA|PRIVATE) KEY)", re.I)
STALE = re.compile(r"turn[- ]based|initiative order|front[- ]rank|back[- ]rank", re.I)
OKCTX = re.compile(r"supersed|do not implement|historical|do not|not implement|replace", re.I)

def cmd_check(a):
    errs, warns = [], []
    for f in doc_files():
        t = f.read_text(encoding="utf-8")
        rel = f.relative_to(ROOT).as_posix()
        if SECRET.search(t):
            errs.append(f"{rel}: possible secret")
        for i, l in enumerate(t.splitlines(), 1):
            if STALE.search(l) and not OKCTX.search(l) and f.stem not in ("CHANGELOG", "DECISIONS", "HANDOFF_LOG"):
                warns.append(f"{rel}:{i}: stale combat term -> {l.strip()[:80]}")
        for link in re.findall(r"`((?:docs|tools)/[\w./-]+)`", t):
            if not (ROOT / link).exists():
                warns.append(f"{rel}: missing path {link}")
    _, _, _, rows = read_board()
    for r in rows:
        if r[3] == "claimed":
            try:
                age = datetime.datetime.now() - datetime.datetime.strptime(r[6], "%Y-%m-%d %H:%M")
                if age.total_seconds() > 48 * 3600:
                    warns.append(f"{r[0]}: claim older than 48h ({r[4]}) - stale")
            except ValueError:
                warns.append(f"{r[0]}: bad date '{r[6]}'")
    cl = (CTX / "CHANGELOG.md").read_text(encoding="utf-8")
    if f"v{VERSION}" not in cl:
        errs.append(f"CHANGELOG.md has no v{VERSION} entry")
    for w in warns:
        print("WARN ", w)
    for e in errs:
        print("ERROR", e)
    print(f"check: {len(errs)} errors, {len(warns)} warnings")
    sys.exit(1 if errs else 0)

HOOK = "#!/bin/sh\npython3 tools/sync/ts_sync.py check && python3 tools/sync/ts_sync.py bundle && git add CONTEXT_BUNDLE.md\n"

def cmd_hooks(a):
    d = ROOT / ".git" / "hooks"
    if not d.is_dir():
        sys.exit("No .git/hooks. Run git init first.")
    p = d / "pre-commit"
    p.write_text(HOOK)
    p.chmod(0o755)
    print("pre-commit hook installed")

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sp = ap.add_subparsers(dest="cmd", required=True)
    sp.add_parser("start").set_defaults(f=cmd_start)
    sp.add_parser("bundle").set_defaults(f=cmd_bundle)
    lt = sp.add_parser("lite", help="small context file for chat AIs"); lt.add_argument("--spec", nargs="*", help="e.g. SUMMONS COMBAT CONTROL")
    lt.set_defaults(f=cmd_lite)
    sp.add_parser("check").set_defaults(f=cmd_check)
    sp.add_parser("install-hooks").set_defaults(f=cmd_hooks)
    c = sp.add_parser("claim"); c.add_argument("task"); c.add_argument("--agent", required=True)
    c.add_argument("--files"); c.set_defaults(f=cmd_claim)
    r = sp.add_parser("release"); r.add_argument("task")
    r.add_argument("--status", choices=["done", "blocked", "handoff"], required=True); r.set_defaults(f=cmd_release)
    l = sp.add_parser("log")
    for k in ("agent", "did", "verified", "next"):
        l.add_argument("--" + k, required=True)
    l.set_defaults(f=cmd_log)
    a = ap.parse_args()
    a.f(a)

if __name__ == "__main__":
    main()
