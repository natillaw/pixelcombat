"""Tiny patch helper for this session's edits: exact replace that keeps each file's line endings."""
import sys


def patch(p, old, new, count=1):
    raw = open(p, encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw
    s = raw.replace("\r\n", "\n")
    if new in s and old not in s:
        return
    assert s.count(old) == count, (p, old[:70], s.count(old))
    s = s.replace(old, new)
    open(p, "w", encoding="utf-8", newline="").write(s.replace("\n", "\r\n") if crlf else s)
