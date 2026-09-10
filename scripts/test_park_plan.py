#!/usr/bin/env python3
"""test_park_plan.py — check retire-plan.py's `[parked]` path on a synthetic plan (s116).

A tiny plan.md with a live section, a `[parked]` section (with a subsection and a
fenced block inside), a `[parked]` list item (s117), a struck item, a struck
bold-head paragraph (s117), and one Status. Expected after --apply: the parked
section and item are in plan-parked.md verbatim and gone from plan.md but for
their head lines and pointers; the struck item and paragraph went to log.md, the
paragraph leaving its bold head and a pointer; the live content is untouched;
the report prints the Status cap and the plan budget; a second run moves
nothing. Exit 0 PASS, 1 FAIL.
"""
import io, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "retire-plan.py")

PLAN = """# Plan

## Live section

Live text that must not move.

- **Live item** — stays.
- **~~Struck item~~** — goes to the log.
  Its continuation line.
- **Deferred item; its claim and trigger live in this line. Trigger: X.** [parked]
  Its body, read only when X fires.
  A second body line.

**~~Shipped in s1–s3~~:** history that belongs in the log.
Second line of the paragraph.
Third line, so the block is long enough to leave a stub.

**Live paragraph.** Unmarked, stays.

*Status s9:* newest, kept.

## Deferred thing [parked]

Deferred text, read only when its trigger fires.

### A subsection inside it

```
code with ## inside a fence must ride along
```

Last line of the parked section.

## Another live section

Also stays.
"""
tmp = tempfile.mkdtemp(prefix="park-plan-")
plan, log, parked = (os.path.join(tmp, x) for x in ("plan.md", "log.md", "plan-parked.md"))
io.open(plan, "w", encoding="utf-8").write(PLAN)
io.open(log, "w", encoding="utf-8").write("# Log\n")
def run(*extra):
    return subprocess.check_output([sys.executable, SCRIPT, "--session", "9", "--date", "2026-09-09",
                                    "--plan", plan, "--log", log, "--parked", parked] + list(extra),
                                   text=True)
ok = True
def check(cond, msg):
    global ok
    if not cond: ok = False; print("FAIL:", msg)

dry = run()
check("4 block(s) would move" in dry and "(2 to log, 2 parked)" in dry, "dry run counts: " + dry.strip().splitlines()[-2])
check("newest Status s9: 4 words (cap 150)" in dry and "(budget 3000)" in dry, "figures line: " + dry.strip().splitlines()[-1])
run("--apply")
p, l, k = (io.open(x, encoding="utf-8").read() for x in (plan, log, parked))
section = PLAN[PLAN.index("## Deferred thing [parked]"):PLAN.index("## Another live section")].rstrip("\n")
body = section.split("\n", 1)[1].strip("\n")
check(body in k, "parked body is in plan-parked.md verbatim")
check("## Deferred thing [parked]" in k, "parked head line is in plan-parked.md")
check("Parked from `plan.md` at s9" in k, "provenance line present")
check("## Deferred thing [parked]" in p and "*Parked at s9 → `knowledge/docs/plan-parked.md`.*" in p, "stub in plan.md")
check("Deferred text" not in p and "code with ##" not in p, "parked body gone from plan.md")
check("Deferred text" not in l, "parked body did NOT go to log.md")
check("Its continuation line." in l and "Retired from plan.md at s9" in l, "struck item went to log.md")
check("Live text that must not move." in p and "Also stays." in p and "*Status s9:* newest, kept." in p, "live content untouched")
check("- **Deferred item; its claim and trigger live in this line. Trigger: X.** [parked]\n  *Parked at s9 → `knowledge/docs/plan-parked.md`.*" in p, "parked item: head line + indented pointer stay")
check("Its body, read only when X fires." not in p and "Its body, read only when X fires.\n  A second body line." in k, "parked item body moved to plan-parked.md verbatim")
check("Its body, read only when X fires." not in l, "parked item body did NOT go to log.md")
check("**~~Shipped in s1–s3~~:**\n*Retired from plan.md at s9* in `log.md`." in p, "struck paragraph: bold head + pointer stay")
check("Second line of the paragraph." not in p and "history that belongs in the log.\nSecond line of the paragraph.\nThird line" in l, "struck paragraph body went to log.md verbatim")
check("**Live paragraph.** Unmarked, stays." in p, "unmarked paragraph untouched")
second = run()
check("0 block(s) would move" in second, "second run moves nothing: " + second.strip().splitlines()[-1])
print("PASS" if ok else "FAIL"); sys.exit(0 if ok else 1)
