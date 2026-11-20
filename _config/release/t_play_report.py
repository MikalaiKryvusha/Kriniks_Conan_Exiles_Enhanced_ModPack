"""Cases of the play-report gate (KUMM plan 59 step 3): one green fixture built from the REAL matrix and the pack's HEAD, then one mutant per refusal rule.
Run: python -I -X utf8 _config/release/t_play_report.py (exit 0 = every case as expected). Each mutant must be refused (exit 1) WITH the problem text that
names its rule (a refusal for another reason does not count); the green one and the fail-row one must pass. Fixtures go to the KUMM work folder (HOUSE_RULES 15).
Judge round 1 (2026-11-20): cases added for an empty field, the template's placeholders, duplicates, a stale build commit, an unlisted skipped row, no report."""
import os, re, subprocess, sys

HERE = r"D:\work\ai_sandbox\KUMM\.work\play_gate"
MATRIX = r"D:\work\ai_sandbox\KUMM\testcases\TC_conan_play_matrix.md"
PACK = r"D:\work\ai_sandbox\ConanExiles"
GATE = os.path.join(PACK, "_config", "release", "check_play_report.py")
VIDEO = r"D:\work\ai_sandbox\SvarogsDream\_harness\demo21\clips\d1_dialogue_fix.mkv"
VER = "9.9.9-T1"
NL = chr(10)
os.makedirs(HERE, exist_ok=True)
TINY = os.path.join(HERE, "tiny.mkv")                           # an existing .mkv far below the gate's minimum size
open(TINY, "wb").write(b"0" * 1024)

ids = []
for line in open(MATRIX, encoding="utf-8"):
    m = re.match(r"^\|\s*([PR]\d+)\s*\|", line)
    if m and m.group(1) not in ids:
        ids.append(m.group(1))
head = subprocess.run(["git", "-C", PACK, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
old = subprocess.run(["git", "-C", PACK, "rev-parse", "dc79053"], capture_output=True, text=True).stdout.strip()   # before 29a612b changed _unpacked


def report(build=VER, played="75 min", video=VIDEO, god="god off: ok (bCanBeDamaged=true)", commit=None, not_covered="none",
           drop=None, empty=None, first_status="pass", dup=None, extra_table=False, skipped=(), obs_text="seen in the session"):
    lines = ["# Play report", "", "- Build: " + build, "- Played: " + played, "- Video: " + video, "- God mode off at the end: " + god,
             "- Pack commit: " + (commit or head)]
    if not_covered is not None:
        lines.append("- Not covered: " + not_covered)
    lines.append("")
    if extra_table:
        lines += ["| Row | Note |", "|---|---|", "| %s | mentioned in prose only |" % ids[-1], ""]
    lines += ["| Row | Status | Observation |", "|---|---|---|"]
    for i in ids:
        if i == drop:
            continue
        obs = "" if i == empty else obs_text
        status = first_status if i == ids[0] else ("skipped" if i in skipped else "pass")
        lines.append("| %s | %s | %s |" % (i, status, obs))
        if i == dup:
            lines.append("| %s | pass | seen again |" % i)
    return NL.join(lines) + NL


CASES = [   # name, text (None = no report file), expected exit, a word the refusal must contain
    ("green", report(), 0, "OK"),
    ("fail row listed, still passes", report(first_status="fail"), 0, "known issues"),
    ("no report at all", None, 1, "no play report"),
    ("build mismatch", report(build="9.9.8"), 1, "Build"),
    ("short play", report(played="45 min"), 1, "Played"),
    ("no video file", report(video=r"D:\nope\x.mkv"), 1, "Video"),
    ("god mode left on", report(god="god on: ok (bCanBeDamaged=false)"), 1, "God mode"),
    ("god line is the template example", report(god="<the line of god-on.sh off, e.g. «god off: ok (bCanBeDamaged=true)»>"), 1, "God mode"),
    ("god line is the template's current placeholder", report(god="<the exact line `god-on.sh off` printed at the end of the session>"), 1, "God mode"),
    ("59 min", report(played="59 min"), 1, "Played"),
    ("the video is not a video", report(video=MATRIX), 1, "Video"),
    ("the video is too small", report(video=TINY), 1, "Video"),
    ("Pack commit is HEAD", report(commit="HEAD"), 1, "hex commit"),
    ("Pack commit is not in the pack", report(commit="deadbeefdeadbeefdeadbeef"), 1, "hex commit"),
    ("an observation with «<» passes", report(obs_text="fps < 30 near the river, still playable"), 0, "OK"),
    ("a blocked row not in Not covered", report(first_status="blocked"), 1, "does not name it"),
    ("too many skipped rows", report(skipped=ids[1:9], not_covered=" ".join(ids[1:9])), 1, "quarter"),
    ("unknown option", "UNKNOWN_OPTION", 2, "unknown option"),
    ("no Not covered", report(not_covered=None), 1, "Not covered"),
    ("empty Not covered", report(not_covered=""), 1, "Not covered"),
    ("a matrix row missing", report(drop=ids[-1]), 1, ids[-1]),
    ("a row only in another table", report(drop=ids[-1], extra_table=True), 1, "is not in the table"),
    ("a duplicate row", report(dup=ids[2]), 1, "twice"),
    ("an empty observation", report(empty=ids[1]), 1, "without an observation"),
    ("a bad status", report(first_status="ok"), 1, "(pass / fail / blocked / skipped)"),
    ("a skipped row not in Not covered", report(first_status="skipped"), 1, "does not name it"),
    ("a skipped row named in Not covered", report(first_status="skipped", not_covered=ids[0] + " — no NPC of that kind"), 0, "OK"),
    ("a stale build commit", report(commit=old), 1, "changed after"),
]
bad = 0
for name, text, want, word in CASES:
    d = os.path.join(HERE, "reports_" + re.sub(r"\W+", "_", name))
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    extra = []
    if text == "UNKNOWN_OPTION":                                 # a typo of an option must stop the gate, never fall back to a default
        text, extra = report(), ["--pak", PACK]
    if text is not None:
        open(os.path.join(d, "2026-11-20_conan-play-%s.md" % VER), "w", encoding="utf-8").write(text)
    r = subprocess.run([sys.executable, "-I", "-X", "utf8", GATE, VER, "--reports", d] + extra, capture_output=True, text=True, encoding="utf-8")
    ok = r.returncode == want and word in r.stdout
    bad += not ok
    detail = [l for l in r.stdout.splitlines() if word in l][:1] or r.stdout.strip().splitlines()[-1:]
    print("%s %-36s exit %d (want %d) · %s" % ("PASS" if ok else "FAIL", name, r.returncode, want, (detail or ["?"])[0].strip()[:110]))
print("matrix rows: %d · pack HEAD %s · cases failed: %d" % (len(ids), head[:7], bad))
sys.exit(1 if bad or not ids else 0)
