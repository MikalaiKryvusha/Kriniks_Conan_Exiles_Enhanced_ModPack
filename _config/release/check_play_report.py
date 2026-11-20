"""check_play_report.py — the release gate of KUMM plan 59 remedy 1: no build release without an hour of play on that build, walked by the player's path.

    python -I -X utf8 _config/release/check_play_report.py <packVersion> [--reports <dir>] [--matrix <TC file>] [--pack <pack repo>]

Reads the newest `<reports>/<YYYY-MM-DD>_conan-play-<packVersion>.md` (template — KUMM testcases/_play-report-template.md) and refuses when:
  · no such report exists, or the matrix yields no row IDs;
  · a «- Name:» field is missing, empty, or still a template placeholder «<…>»;
  · «- Build:» is not the version; «- Played:» is under 60 min; «- Video:» is not an existing .mkv / .mp4 of at least 10 MB;
  · «- God mode off at the end:» is not exactly the line «god off: ok (bCanBeDamaged=true)» (KUMM issue #6: the save keeps god mode);
  · «- Pack commit:» is not a hex commit of the pack, or a later commit (or an uncommitted change) touched what the build ships — `_unpacked/`, `modpack.json`,
    the translation `_config/localization/`, the etalon `_config/Game.ini` / `GameUserSettings.ini`, the launcher's source `_config/launcher/`, and the
    manifest's `guide` and `extras` paths — the report must be of THIS build;
  · the table under «| Row | Status | Observation |» lacks a matrix row, repeats one, has a status other than pass / fail / blocked / skipped, or an empty or
    placeholder observation;
  · a skipped or blocked row is not named in «- Not covered:», or more than a quarter of the rows are skipped or blocked.
Rows with status fail are listed for the release notes' known issues (not enforced here). Exit 0 — the report holds; 1 — refused; 2 — usage.
GAP: the mod library `_library/` is git-ignored — a mod pak replaced there after the play is not seen by this gate.
Why (the owner 2026-11-20 18:3x — twelve bugs in 30 min of his play of RC1; plans 32 and 47 ordered play and were never executed): a remedy that no step of the
release reads does nothing (KUMM EXP-0582). Judge rounds 1–2 (2026-11-20) found the holes closed here: a field regex across the newline, the template's own
example passing, rows from any table, duplicates, an empty matrix, a report of an earlier build («HEAD» as the commit, the translation not watched), any file as
the video, all rows skipped.
[NOT-TESTED] — round 3 of `_config/release/t_play_report.py` owed
"""
import json, os, re, subprocess, sys

KUMM = r"D:\work\ai_sandbox\KUMM"
MIN_MINUTES = 60
MIN_VIDEO_BYTES = 10 * 1024 * 1024
VIDEO_EXT = (".mkv", ".mp4")
MAX_NOT_WALKED_SHARE = 0.25     # [AI] 2026-11-20: a play report walks the matrix; a quarter left out is a partial walk, not a release's report
STATUSES = {"pass", "fail", "blocked", "skipped"}
GOD_OFF = "god off: ok (bCanBeDamaged=true)"
TABLE_HEAD = re.compile(r"^\|\s*Row\s*\|\s*Status\s*\|\s*Observation\s*\|")
ROW_ID = re.compile(r"^\|\s*([PR]\d+)\s*\|")
HEX = re.compile(r"^[0-9a-f]{7,40}$")
BUILD_BASE = ["_unpacked", "modpack.json", "_config/localization", "_config/Game.ini", "_config/GameUserSettings.ini", "_config/launcher"]
OPTIONS = ("--reports", "--matrix", "--pack")


def field(text, name):
    m = re.search(r"^- " + re.escape(name) + r":[ \t]*(.*)$", text, re.M)
    return m.group(1).strip() if m else None


def placeholder(value):
    v = (value or "").strip()
    return not v or (v.startswith("<") and v.endswith(">"))


def matrix_ids(path):
    ids = []
    for line in open(path, encoding="utf-8"):
        m = ROW_ID.match(line)
        if m and m.group(1) not in ids:
            ids.append(m.group(1))
    return ids


def report_rows(text):
    """Rows of the ONE table under «| Row | Status | Observation |»; a repeated row ID is returned in `dups`."""
    rows, dups, inside = {}, [], False
    for line in text.splitlines():
        if TABLE_HEAD.match(line):
            inside = True
            continue
        if inside and not line.startswith("|"):
            break
        m = ROW_ID.match(line) if inside else None
        if m:
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if m.group(1) in rows:
                dups.append(m.group(1))
            rows[m.group(1)] = cells[1:]
    return rows, dups


def git(pack, *args):
    r = subprocess.run(["git", "-C", pack] + list(args), capture_output=True, text=True, encoding="utf-8")
    return r.returncode, r.stdout.strip()


def build_paths(pack):
    paths = list(BUILD_BASE)
    try:
        m = json.load(open(os.path.join(pack, "modpack.json"), encoding="utf-8"))
        for p in [m.get("guide")] + list(m.get("extras") or []):
            if isinstance(p, str) and p:
                paths.append(p)
    except (OSError, ValueError):
        pass
    return [p for p in paths if os.path.exists(os.path.join(pack, p))]


def main(argv):
    if not argv or argv[0].startswith("-"):
        print(__doc__.strip().splitlines()[2].strip())
        return 2
    version, rest, opts = argv[0], argv[1:], {}
    while rest:
        if rest[0] not in OPTIONS or len(rest) < 2:
            print("unknown option or no value: %s (known: %s)" % (rest[0], ", ".join(OPTIONS)))
            return 2
        opts[rest[0]], rest = rest[1], rest[2:]
    reports = opts.get("--reports", os.path.join(KUMM, "testcases", "reports"))
    matrix = opts.get("--matrix", os.path.join(KUMM, "testcases", "TC_conan_play_matrix.md"))
    pack = opts.get("--pack", os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    ids = matrix_ids(matrix)
    if not ids:
        print("REFUSED: the matrix %s yields no row IDs (| P1 | … / | R1 | …) — its format drifted" % matrix)
        return 1
    suffix = "_conan-play-%s.md" % version
    found = sorted(f for f in os.listdir(reports) if f.endswith(suffix) and re.match(r"^\d{4}-\d{2}-\d{2}_conan-play-", f))
    if not found:
        print("REFUSED: no play report «<date>%s» in %s — play the build for an hour by the player's path first (KUMM plan 59)" % (suffix, reports))
        return 1
    path = os.path.join(reports, found[-1])
    text = open(path, encoding="utf-8").read()
    bad = []
    for name in ("Build", "Played", "Video", "God mode off at the end", "Pack commit", "Not covered"):
        if placeholder(field(text, name)):
            bad.append("«- %s:» is missing, empty or still the template's placeholder" % name)
    build = field(text, "Build")
    if not placeholder(build) and build != version:
        bad.append("«- Build:» is %r, the release is %r" % (build, version))
    played = re.fullmatch(r"(\d+)\s*min", field(text, "Played") or "")
    if not placeholder(field(text, "Played")) and (not played or int(played.group(1)) < MIN_MINUTES):
        bad.append("«- Played:» must be «<N> min» with N ≥ %d (it reads %r)" % (MIN_MINUTES, field(text, "Played")))
    video = (field(text, "Video") or "").strip("`\"' ")
    if not placeholder(video):
        if not video.lower().endswith(VIDEO_EXT) or not os.path.isfile(video) or os.path.getsize(video) < MIN_VIDEO_BYTES:
            bad.append("«- Video:» must be an existing %s of at least %d MB (%r)" % (" / ".join(VIDEO_EXT), MIN_VIDEO_BYTES // 1048576, video))
    god = field(text, "God mode off at the end")
    if not placeholder(god) and god.strip("«»`\"' ") != GOD_OFF:
        bad.append("«- God mode off at the end:» is not the line %r (it reads %r)" % (GOD_OFF, god))
    commit = (field(text, "Pack commit") or "").strip("`\"' ")
    if not placeholder(commit):
        rc, full = git(pack, "rev-parse", "--verify", "--quiet", commit + "^{commit}")
        if not HEX.match(commit) or rc != 0:
            bad.append("«- Pack commit:» %r is not a hex commit of the pack (a name like HEAD or main is refused)" % commit)
        elif git(pack, "merge-base", "--is-ancestor", full, "HEAD")[0] != 0:
            bad.append("«- Pack commit:» %s is not in the history of the pack's HEAD" % commit)
        else:
            watched = build_paths(pack)
            _, later = git(pack, "log", "--oneline", full + "..HEAD", "--", *watched)
            if later:
                bad.append("the build changed after the played commit %s: %s" % (commit, "; ".join(later.splitlines()[:3])))
            # tracked files only: the guide PDF and the launcher exe are generated by make_release.sh step 2 from the watched sources (untracked artifacts)
            _, dirty = git(pack, "status", "--porcelain", "--untracked-files=no", "--", *watched)
            if dirty:
                bad.append("the build has uncommitted changes the play did not see: %s" % "; ".join(dirty.splitlines()[:3]))
    not_covered = field(text, "Not covered") or ""
    rows, dups = report_rows(text)
    for d in dups:
        bad.append("row %s appears twice in the table" % d)
    fails, not_walked = [], 0
    for rid in ids:
        r = rows.get(rid)
        if r is None:
            bad.append("matrix row %s is not in the table" % rid)
            continue
        status = (r[0] if r else "").lower()
        obs = r[1] if len(r) > 1 else ""
        if status not in STATUSES:
            bad.append("row %s: status %r (pass / fail / blocked / skipped)" % (rid, status))
        elif placeholder(obs) or obs in ("—", "-"):
            bad.append("row %s: %s without an observation" % (rid, status))
        elif status == "fail":
            fails.append(rid)
        elif status in ("skipped", "blocked"):
            not_walked += 1
            if not re.search(r"\b%s\b" % rid, not_covered):
                bad.append("row %s is %s but «- Not covered:» does not name it" % (rid, status))
    if not_walked > MAX_NOT_WALKED_SHARE * len(ids):
        bad.append("%d of %d rows are skipped or blocked — more than a quarter is a partial walk" % (not_walked, len(ids)))
    print("play report %s · matrix rows %d · table rows %d" % (path, len(ids), len(rows)))
    for b in bad:
        print("  ✖ " + b)
    if fails:
        print("  rows with fail (for the release notes' known issues): " + ", ".join(fails))
    if bad:
        print("REFUSED: the play report does not hold (%d problem(s))" % len(bad))
        return 1
    print("OK: the play report holds")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
