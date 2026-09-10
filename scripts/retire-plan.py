#!/usr/bin/env python3
"""retire-plan.py — move closed blocks out of allostatik/plan.md into log.md, verbatim (s114).

plan.md is the living plan; log.md is the record of what happened. A block whose
head line carries a CLOSE MARKER is finished narrative and belongs in the log:

  *Status sNNN:*     a status paragraph, every one except the NEWEST in the file
  ~~struck~~         a list item or heading with strike-through in its head line
  - [x]              a checked list item
  DONE               the word, upper-case, in a list item's or heading's head line
  **bold head.**     a paragraph opening with a bold head whose first line carries ~~ or
                     DONE (s117): history written into a section, e.g. "what shipped"

A heading -- or, since s117, a list item -- whose head line carries the PARK
MARKER `[parked]` is not finished: it is deferred with a trigger, and it is read
only when the trigger fires. So it moves whole into
allostatik/knowledge/docs/plan-parked.md (read on demand, never auto-loaded),
leaving its head line and a one-line pointer (s116). A parked item's first line
is what stays, so write the claim and the trigger into it before marking. To
un-park, move the block back by hand and drop the marker.

Two figures the report prints (s117), each a WARN line when over, never a halt:
the newest Status block against STATUS_CAP words -- the log entry carries the
record; the Status says what changed in the plan's terms and points at the entry
-- and plan.md against PLAN_BUDGET words. Both are scaffolds keyed to today's
context window; re-derive them when it moves.

Marking is the session's judgment at close (it already strikes rows and writes
the Status); this script is the mechanical half. It selects nothing, summarises
nothing and misses nothing that is marked: every marked block moves whole, in file
order, under one dated heading at the end of log.md, and leaves its head line plus
a one-line pointer in plan.md. A block of one or two lines has nothing to withhold
-- its head IS its content -- so it moves whole and leaves nothing (a struck
one-liner is not narrative the plan needs). Blocks already carrying a pointer are
skipped, so running it twice moves nothing the second time. The first run was done by hand at
s113 (log.md § "Retired from plan.md at s113"); scripts/test_retire_plan.py checks
this script against that move.

Blocks:  a heading section runs to the next heading of the same or higher level;
a list item runs through its indented continuation lines; a Status paragraph runs
to the next blank line. Fenced code is never a block boundary.

Usage:  retire-plan.py --session 114              dry run: print what would move
        retire-plan.py --session 114 --apply      move it (plan.md and log.md rewritten)
        --date YYYY-MM-DD (default today)  --root <project> (default: this repo)
Exit 0 ok (also when nothing is marked), 2 usage.
"""
import argparse, datetime, io, os, re, sys

ap = argparse.ArgumentParser(prog="retire-plan.py",
    description="Move close-marked blocks from plan.md to log.md, verbatim.")
ap.add_argument("--session", type=int, required=True, help="session number, e.g. 114")
ap.add_argument("--date", default=datetime.date.today().isoformat())
ap.add_argument("--apply", action="store_true", help="write; without it, dry-run only")
ap.add_argument("--root", metavar="DIR", help="project root holding allostatik/")
ap.add_argument("--plan", help=argparse.SUPPRESS)   # test hook: explicit file paths
ap.add_argument("--log", help=argparse.SUPPRESS)
ap.add_argument("--parked", help=argparse.SUPPRESS)
args = ap.parse_args()

root = os.path.abspath(args.root) if args.root else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAN = args.plan or os.path.join(root, "allostatik", "plan.md")
LOG = args.log or os.path.join(root, "allostatik", "log.md")
PARKED = args.parked or os.path.join(root, "allostatik", "knowledge", "docs", "plan-parked.md")
PARKED_REL = "knowledge/docs/plan-parked.md"
for p in (PLAN, LOG):
    if not os.path.isfile(p):
        sys.stderr.write("not a file: %s -- pass --root <project>\n" % p); sys.exit(2)

HEAD = re.compile(r"^(#{1,6})\s")
ITEM = re.compile(r"^- ")
STATUS = re.compile(r"^\*Status s(\d+)")
MARK = re.compile(r"~~|^- \[x\]|\bDONE\b")
PARK = re.compile(r"\[parked\]")
PARA = re.compile(r"^\*\*")           # a paragraph opening with a bold head (s117)
STATUS_CAP = 150                        # words, newest Status block (s117)
PLAN_BUDGET = 3000                      # words, plan.md whole (s117); both keyed to today's window
STUB = re.compile(r"Body under \*Retired from plan\.md at s\d+\*|^\*Retired from plan\.md at s\d+\* in `log\.md`"
                  r"|retired verbatim to `log\.md`|retired to `log\.md` \(s\d+\)|Body retired s\d+"
                  r"|^\s*\*Parked at s\d+ ", re.M)
POINTER = "Retired from plan.md at s%d"

lines = io.open(PLAN, encoding="utf-8").read().split("\n")
n = len(lines)

# --- block boundaries -------------------------------------------------------
fence = [False] * n          # fence[i]: line i is inside a ``` fence
inside = False
for i, l in enumerate(lines):
    if l.startswith("```"):
        inside = not inside; fence[i] = True
    else:
        fence[i] = inside

def heading_end(i, level):
    j = i + 1
    while j < n:
        m = HEAD.match(lines[j])
        if m and not fence[j] and len(m.group(1)) <= level:
            break
        j += 1
    return j

def item_end(i):
    j = i + 1
    while j < n:
        l = lines[j]
        if fence[j] or l.startswith((" ", "\t")):
            j += 1; continue
        if l.strip() == "":
            k = j
            while k < n and lines[k].strip() == "": k += 1
            if k < n and lines[k].startswith((" ", "\t")) and not HEAD.match(lines[k]):
                j = k; continue
        break
    return j

def status_end(i):
    j = i + 1
    while j < n and lines[j].strip() != "" and not (HEAD.match(lines[j]) and not fence[j]):
        j += 1
    return j

def trim(j):                 # exclusive end, trailing blank lines left in place
    while j > 0 and lines[j - 1].strip() == "": j -= 1
    return j

newest = max([int(STATUS.match(l).group(1)) for l in lines if STATUS.match(l)] or [0])

blocks = []                  # (start, end_exclusive, kind, why)
i = 0
while i < n:
    l = lines[i]
    if fence[i]:
        i += 1; continue
    m = HEAD.match(l)
    if m:
        level = len(m.group(1)); end = heading_end(i, level)
        if PARK.search(l):
            blocks.append((i, trim(end), "parked", "[parked]"))
            i = end; continue
        if MARK.search(l):
            blocks.append((i, trim(end), "heading", "~~" if "~~" in l else "DONE"))
            i = end; continue
        i += 1; continue     # an unmarked heading is transparent: its children are scanned
    if ITEM.match(l):
        end = item_end(i)
        if PARK.search(l):
            blocks.append((i, trim(end), "parked-item", "[parked]"))
        elif MARK.search(l):
            blocks.append((i, trim(end), "item", "[x]" if l.startswith("- [x]") else ("~~" if "~~" in l else "DONE")))
        i = end; continue
    if PARA.match(l) and MARK.search(l):
        end = status_end(i)          # a paragraph runs to the next blank line
        blocks.append((i, trim(end), "para", "~~" if "~~" in l else "DONE"))
        i = end; continue
    s = STATUS.match(l)
    if s:
        end = status_end(i)
        if int(s.group(1)) != newest:
            blocks.append((i, trim(end), "status", "older than s%d" % newest))
        i = end; continue
    i += 1

def is_stub(b):              # already retired: short, and carries a pointer at the log
    body = [x for x in lines[b[0]:b[1]] if x.strip()]
    return len(body) <= 3 and bool(STUB.search("\n".join(body)))
def is_short(b):             # nothing to withhold: the stub would be as long as the block
    return sum(1 for x in lines[b[0]:b[1]] if x.strip()) <= 2

moved = [b for b in blocks if not is_stub(b)]
skipped = [b for b in blocks if is_stub(b)]

def section_of(i):           # nearest ENCLOSING heading (a moved heading's parent), short title
    own = HEAD.match(lines[i]); lvl = len(own.group(1)) if own else 7
    for j in range(i - 1, -1, -1):
        m = HEAD.match(lines[j])
        if m and not fence[j] and len(m.group(1)) < lvl:
            t = lines[j][m.end():].strip()
            return re.split(r" \(| — | -- ", t)[0]
    return "top"

# --- report ------------------------------------------------------------------
words = 0
for s, e, kind, why in moved:
    w = len(" ".join(lines[s:e]).split()); words += w
    print("%4d-%-4d %-7s %-14s %3d lines %5dw  %s%s" % (s + 1, e, kind, why, e - s, w, lines[s][:70],
          "  [whole, no stub]" if is_short((s, e)) else ""))
parked = [b for b in moved if b[2] in ("parked", "parked-item")]
retired = [b for b in moved if b[2] not in ("parked", "parked-item")]
print("newest Status kept: s%d | %d block(s) would move, %d words (%d to log, %d parked) | %d already-retired stub(s) skipped"
      % (newest, len(moved), words, len(retired), len(parked), len(skipped)))

def figures(ls):             # the two scaffold figures (s117): WARN when over, never a halt
    sw = 0
    for k, x in enumerate(ls):
        st = STATUS.match(x)
        if st and int(st.group(1)) == newest:
            j = k + 1
            while j < len(ls) and ls[j].strip() != "": j += 1
            sw = len(" ".join(ls[k:j]).split()); break
    pw = len(" ".join(ls).split())
    print("newest Status s%d: %d words (cap %d)%s | plan.md: %d words (budget %d)%s"
          % (newest, sw, STATUS_CAP, " WARN over cap" if sw > STATUS_CAP else "",
             pw, PLAN_BUDGET, " WARN over budget" if pw > PLAN_BUDGET else ""))
if not moved or not args.apply:
    figures(lines); sys.exit(0)

# --- apply -------------------------------------------------------------------
tag = POINTER % args.session
out = ["## Retired from plan.md at s%d (%s) — verbatim, in file order" % (args.session, args.date), "",
       "*Moved by `scripts/retire-plan.py` at the s%d close: every block whose head line carried a "
       "close marker (`*Status sNNN:*` except the newest, `~~`, `[x]`, `DONE`), whole and in file "
       "order, each leaving its head line and a pointer in `plan.md`. %d block(s), %d words.*"
       % (args.session, len(moved), words), ""]
last = None
for s, e, kind, why in retired:
    sec = section_of(s)
    if sec != last:
        out += ["### From § " + sec, ""]; last = sec
    out += lines[s:e] + [""]
out += ["---", ""]
park_out = []
for s, e, kind, why in parked:
    park_out += ["*Parked from `plan.md` at s%d (%s), verbatim; the head line and a pointer stay there.*" % (args.session, args.date), ""]
    park_out += lines[s:e] + [""]

new_plan = []
i = 0
mv = {s: (e, kind) for s, e, kind, why in moved}
status_run = []              # consecutive Status blocks collapse to one pointer line
def flush_status():
    if status_run:
        lo, hi = min(status_run), max(status_run)
        rng = "s%d" % lo if lo == hi else "s%d–s%d" % (lo, hi)
        new_plan.extend(["*Status %s:* retired verbatim to `log.md` § *%s*." % (rng, tag), ""])
        status_run.clear()
while i < n:
    if i in mv:
        e, kind = mv[i]
        if kind == "status":
            status_run.append(int(STATUS.match(lines[i]).group(1)))
            i = e
            while i < n and lines[i].strip() == "": i += 1
            if not (i < n and i in mv and mv[i][1] == "status"):
                flush_status()
            continue
        if is_short((i, e)):                 # moves whole; drop one following blank line too
            i = e
            if i < n and lines[i].strip() == "" and new_plan and new_plan[-1].strip() == "": i += 1
            continue
        if kind == "para":                   # the stub is the bold head alone
            hm = re.match(r"^\*\*.*?\*\*:?", lines[i])
            new_plan.append(hm.group(0) if hm else lines[i])
        else:
            new_plan.append(lines[i])
        if kind == "parked":
            new_plan.extend(["", "*Parked at s%d → `%s`.*" % (args.session, PARKED_REL)])
            i = e; continue
        if kind == "parked-item":
            new_plan.append("  *Parked at s%d → `%s`.*" % (args.session, PARKED_REL))
            i = e; continue
        if kind == "item":
            new_plan.append("  Body under *%s* in `log.md`." % tag)
        elif kind == "para":
            new_plan.append("*%s* in `log.md`." % tag)
        else:
            new_plan.extend(["", "*%s* in `log.md`." % tag])
        i = e; continue
    new_plan.append(lines[i]); i += 1
flush_status()

if retired:
    log = io.open(LOG, encoding="utf-8").read()
    if not log.endswith("\n"): log += "\n"
    if not log.endswith("\n\n"): log += "\n"
    io.open(LOG, "w", encoding="utf-8").write(log + "\n".join(out) + "\n")
if parked:
    if os.path.isfile(PARKED):
        pk = io.open(PARKED, encoding="utf-8").read()
        if not pk.endswith("\n"): pk += "\n"
        if not pk.endswith("\n\n"): pk += "\n"
    else:
        os.makedirs(os.path.dirname(PARKED), exist_ok=True)
        pk = ("# plan.md — parked sections\n\n"
              "Sections and list items of `allostatik/plan.md` whose head line carried `[parked]` at a close, "
              "moved here whole by `scripts/retire-plan.py`. Each is deferred with a trigger named in its own "
              "text; read one when its trigger fires, never at the open. To un-park: move the block back "
              "into `plan.md` by hand and drop the marker.\n\n")
    io.open(PARKED, "w", encoding="utf-8").write(pk + "\n".join(park_out) + "\n")
io.open(PLAN, "w", encoding="utf-8").write("\n".join(new_plan))
print("applied: %d block(s) to %s, %d to %s; %s rewritten (%d -> %d lines)"
      % (len(retired), os.path.basename(LOG), len(parked), os.path.basename(PARKED), os.path.basename(PLAN), n, len(new_plan)))
figures(new_plan)
