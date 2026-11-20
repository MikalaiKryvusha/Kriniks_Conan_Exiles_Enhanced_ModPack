"""release_checklist.py — THE RELEASE RITUAL of the build: what to do, update and check for every release (an RC too), where, and with what.

    python -I -X utf8 _config/release/release_checklist.py [--published]

The owner 2026-11-20 21:22–21:24: «У тебя должен быть хук-ритуал-тудулист ЧТО НУЖНО ОБНОВИТЬ И ГДЕ И ЧЕМ ПРИ ВЫПУСКЕ ОЧЕРЕДНОГО РЕЛИЗА» · «НЕ ТОЛЬКО ВЕРСИЯ» ·
«ЭТО ЦЕЛЫЙ РИТУАЛ МНОГО ЧЕГО!!!» — after RC2 was almost built with the menu line «0.9.1-RC1», every Krinik mod at «0.9.1-RC1», and the guide never re-read against
his remarks on the RC1 notes. KUMM HOUSE_RULES 42 is the rule; this script is its executable form, in five stages:
  A. what the release carries · B. versions · C. texts · D. build and install · E. publication (only `--published`, after `gh release create`).
Each line: OK · TODO (code found it undone; the fix command follows) · MANUAL (a reading or a run only the agent's eye can judge — it is done and named in the
run report, never green by itself). make_release.sh runs it as step 0b and stops on a TODO; the hook tools/hooks/release-ritual-gate.mjs (KUMM) refuses
`gh release create` while it has a TODO. Exit 0 — no TODO; 1 — a TODO; 2 — the manifest is unreadable or its packVersion does not start with X.Y.Z.
[NOT-TESTED]
"""
import json, os, re, subprocess, sys

PACK = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KRINIK_PAKS = ["KrinikConanArchery", "KrinikConanGameplay", "KrinikConanGraphics", "KrinikConanUI"]
REPO = "MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack"
PY = sys.executable


def run(cmd, cwd=PACK):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def git(*args):
    return run(["git", "-C", PACK] + list(args))[1].strip()


def read(p):
    return open(p, encoding="utf-8").read() if os.path.isfile(p) else ""


# The judge's verdict on one code commit is the LAST line that STARTS with «review:» — in its git note first (a pushed message cannot change, a later verdict is
# attached as a note: `git notes append -m "review: …" <hash>`, pushed by `git push origin refs/notes/commits`), then in its message. The canonical forms
# (KUMM AGENT_GUIDE, the independent judge): «review: <R> rounds — <N> findings, fixed <K>, refuted <M>» · «review: skipped — <why>» for a typo or a comment.
# Judge 2026-11-20 22:2x: a bare substring test took «review: skipped … owed in the next chat» (dc79053) and «… the push waits for its verdict» (e1c0691) for done reviews.
# Judge round 2, 22:3x: the verdict is the whole PARAGRAPH from that line (a long one wraps — 29a612b), «0 rounds» or «2 rounds planned» is no review, a skip
# on a feat commit (new code) is owed, and a code commit is found by its FILES — a «docs(…)» commit that edits make_release.sh is code too (4d1d867).
REVIEW_LINE = re.compile(r"(?i)^review:")
REVIEW_OWED = re.compile(r"\b(owed|pending|waits?|planned|later|next chat|at the judge|in progress|running)\b", re.I)
REVIEW_DONE = re.compile(r"(?i)^review:\s*[1-9]\d*\s+rounds?\b")
REVIEW_SKIP = re.compile(r"(?i)^review:\s*skipped\b")
CODE_FILE = re.compile(r"\.(py|lua|sh|ps1|psm1|cs|mjs|js|cmd|bat)$", re.I)


def review_paragraph(text):
    """The last «review:» line and the lines that continue it, up to a blank line or the co-author trailer; None when there is no such line."""
    lines = text.splitlines()
    starts = [i for i, l in enumerate(lines) if REVIEW_LINE.match(l)]
    if not starts:
        return None
    para = []
    for l in lines[starts[-1]:]:
        if not l.strip() or l.lower().startswith("co-authored-by:"):
            break
        para.append(l.strip())
    return " ".join(para)


def review_verdict(h, kind):
    """'done' · 'skipped' · 'owed' (promised for later, unclear, a skip on a feat commit, or no «review:» line at all) for one commit; kind — its type word."""
    for text in (git("notes", "show", h), git("log", "-1", "--format=%B", h)):
        para = review_paragraph(text)
        if para is None:
            continue
        if REVIEW_OWED.search(para):
            return "owed"
        if REVIEW_SKIP.match(para):
            return "owed" if kind.lower() == "feat" else "skipped"
        return "done" if REVIEW_DONE.match(para) else "owed"
    return "owed"


def code_commits_since(since):
    """[(hash, type word)] of the commits since `since` that change a code file — one git call for the whole window; None when git fails.
    core.quotepath=off: a path with Cyrillic letters is printed as is, never as a quoted octal string that no extension pattern matches (judge round 3)."""
    rc, text = run(["git", "-C", PACK, "-c", "core.quotepath=off", "log", "--since", since, "--format=%x1e%h %s", "--name-only"])
    if rc != 0:
        return None
    out = []
    for rec in text.split("\x1e"):
        lines = [l for l in rec.strip().splitlines() if l.strip()]
        if lines and any(CODE_FILE.search(f) for f in lines[1:]):
            m = re.match(r"^(\w+) (\w+)", lines[0])
            out.append((lines[0].split()[0], m.group(2) if m else ""))
    return out


def main(argv):
    try:
        m = json.load(open(os.path.join(PACK, "modpack.json"), encoding="utf-8"))
    except (OSError, ValueError) as e:
        print("cannot read modpack.json: %s" % e)
        return 2
    v = m.get("packVersion")
    # pyright 2026-11-20 22:2x: a packVersion without X.Y.Z at its head crashed here with AttributeError instead of saying what is wrong
    mv = re.match(r"^(\d+\.\d+\.\d+)", v) if isinstance(v, str) else None
    if not mv:
        print("modpack.json packVersion %r does not start with X.Y.Z" % v)
        return 2
    xyz = mv.group(1)
    xyz_ = xyz.replace(".", "_")
    rc = re.search(r"-(RC\d+)$", v)
    gv = (m.get("launcher") or {}).get("gameVersion", "?")
    items = []

    def add(stage, state, what, where, how):
        items.append((stage, state, what, where, how))

    # ---------- A. what the release carries ----------
    # The previous BUILD release: the newest published «v*» tag other than this version's. «Latest» is not it — a launcher release (launcher-vX.Y.Z, the
    # same repository) would become Latest and move the window past the pack's commits (judge round 4, 2026-11-20 22:5x).
    rc_, rels = run(["gh", "release", "list", "--repo", REPO, "--limit", "50", "--json", "tagName,publishedAt,isDraft"])
    prev_tag, prev_at = "?", "?"
    if rc_ == 0:
        try:
            builds = sorted((x for x in json.loads(rels) if x["tagName"].startswith("v") and x["tagName"] != "v" + v
                             and not x["isDraft"] and x["publishedAt"]), key=lambda x: x["publishedAt"], reverse=True)
            if builds:
                prev_tag, prev_at = builds[0]["tagName"], builds[0]["publishedAt"]
        except (ValueError, KeyError, TypeError):
            pass
    if prev_at == "?":
        # judge 2026-11-20 22:2x: without the previous release the window was empty, zero code commits, and the review line read OK
        add("A", "TODO", "the previous release is read from GitHub (the window of this release's commits)", "gh release view --repo %s" % REPO,
            "gh auth status; the network — every line of stage A below is blind without it")
    log = git("log", "--format=%h %s", "--since", prev_at) if prev_at != "?" else ""
    code_commits = code_commits_since(prev_at) if prev_at != "?" else None
    verdicts = {"owed": [], "skipped": []}
    for h, kind in code_commits or []:
        verdict = review_verdict(h, kind)
        if verdict != "done":
            verdicts["skipped" if verdict == "skipped" else "owed"].append(h)
    add("A", "MANUAL", "every player-visible change since %s is in the notes (%d commits since it)" % (prev_tag, len(log.splitlines())),
        "git log --since %s" % prev_at, "read the list; each fix / feature → a line of the notes, the guide, the change notes")
    owed, skipped = verdicts["owed"], verdicts["skipped"]
    # a window that could not be read (no previous release, git failed) is blind: TODO, never a green line over zero commits (judge round 3)
    add("A", "TODO" if (owed or code_commits is None) else ("MANUAL" if skipped else "OK"),
        "every code commit since %s went to the judge («review: N rounds» in its git note or its message)" % prev_tag,
        "pack commits" + (" · the window could not be read (gh or git failed)" if code_commits is None else "")
        + (" · review owed or unclear: %s" % ", ".join(owed) if owed else "") + (" · skipped: %s" % ", ".join(skipped) if skipped else ""),
        "owed → a judge round on the diff, then `git notes append -m \"review: N rounds — …\" <hash>` + `git push origin refs/notes/commits` "
        "(a fresh clone first: `git fetch origin refs/notes/*:refs/notes/*`); skipped → confirm each was a typo, a comment or a mechanical edit "
        "(AGENT_GUIDE, the independent judge)")
    add("A", "MANUAL", "every issue fixed by this release was retested by MY play on the player's path and commented",
        "github.com/%s/issues" % REPO, "gh issue view <n>; the retest is my game (HOUSE_RULES 44.4); critical open issues → «known issues» of the notes")
    play = [f for f in os.listdir(os.path.join(os.path.dirname(PACK), "KUMM", "testcases", "reports")) if f.endswith("_conan-play-%s.md" % v)] \
        if os.path.isdir(os.path.join(os.path.dirname(PACK), "KUMM", "testcases", "reports")) else []
    add("A", "OK" if play else "MANUAL", "an hour of my play on this build (or the owner's waiver in KRINIK_PLAY_GATE_WAIVER)",
        "KUMM/testcases/reports/<date>_conan-play-%s.md" % v, "play by the matrix, then check_play_report.py; the waiver only by his words")
    # ---------- B. versions ----------
    # only the SHIPPED Krinik mods: an "export": false mod (KrinikConanMusic, KrinikConanHarness — the agent's instruments) never reaches a player
    stale = [x["name"] for x in m["mods"] if (x.get("name") or "").startswith("Krinik") and x.get("export", True) is not False
             and x.get("version") not in (None, v)]
    add("B", "OK" if not stale else "TODO", "every shipped Krinik mod's «version» = %s" % v,
        "modpack.json mods[].version" + (" (stale: %s)" % ", ".join(stale) if stale else ""), "edit each, with its $comment_version line")
    set_at = git("log", "-1", "--format=%ct", "-S", '"packVersion": "%s"' % v, "--", "modpack.json")
    pak = os.path.join(PACK, "_unpacked", "KrinikConanUI", "KrinikConanUI.pak")
    ok = bool(set_at) and os.path.isfile(pak) and os.path.getmtime(pak) > int(set_at)
    add("B", "OK" if ok else "TODO", "the menu line «%s» under our logo (baked into the KrinikConanUI kit pak at the KIT build)" % v,
        "_unpacked/KrinikConanUI/KrinikConanUI.pak" + ("" if ok else " — older than the commit that set packVersion (or packVersion not committed)"),
        "commit modpack.json → kit-conanui-edit.py → kit-krinik-modsettings.py ×2 → kit-krinik-click-events.py ×2 → kit-buildmod.py KrinikConanUI → copy into "
        "_unpacked → Deploy -Only KrinikConanUI → set-pak-modinfo.py (KUMM games/ConanExiles/mods/KrinikConanUI.md)")
    add("B", "MANUAL", "the launcher: its packVersion line (BuildInfo.g.cs by build-docs.py) and, if the launcher changed, its own version and tag launcher-vX.Y.Z",
        "_config/launcher/", "python -I -X utf8 _config/release/build-docs.py; the launcher's self-update rule (Feed.Newer)")
    # ---------- C. texts (the owner's portrait, rules 33 / 35 / 35.5) ----------
    notes = os.path.join(PACK, "_config", "release", "draft_%s" % xyz_, "github_release_notes_%s%s.md" % (xyz_, "_" + rc.group(1) if rc else ""))
    nt = read(notes)
    add("C", "OK" if nt.startswith("<!-- krinik-game: %s CL-" % gv) and v in nt else "TODO", "the release notes RU + EN (the game marker first; an RC: only its changes + a link to the previous RC)",
        os.path.relpath(notes, PACK), "write by the portrait: node KUMM/.kaif/tools/kaif-voice-lint.mjs load / check; «был баг — исправлен» for fixes (the owner 2026-11-20 21:12)")
    cn = json.load(open(os.path.join(PACK, "_config", "release", "krinik_change_notes.json"), encoding="utf-8")).get(xyz, {})
    miss = [p for p in KRINIK_PAKS if not cn.get(p)]
    add("C", "OK" if not miss else "TODO", "the mods' change notes of %s (the game's mod list) carry this release's changes" % xyz,
        "_config/release/krinik_change_notes.json" + (" (missing: %s)" % ", ".join(miss) if miss else ""), "add the lines → set-pak-modinfo.py <game Mods>")
    guide = os.path.join(PACK, "docs", "guide", "guide-%s.html" % gv)
    add("C", "OK" if v in read(guide) else "TODO", "the user guide names %s" % v, os.path.relpath(guide, PACK), "edit the version lines → build-docs.py (the PDF)")
    add("C", "MANUAL", "the user guide READ against the notes and every remark the owner made on the previous release page (what's new, known issues, fixes)",
        os.path.relpath(guide, PACK), "open and read it whole; the owner's remarks — KUMM PROJECT_HISTORY entries of his reading (e.g. 2026-11-20 16:19–16:34)")
    add("C", "MANUAL", "«what's new» and «what's fixed» of THIS release stand in every text the player reads — the notes, the guide, the README, the mods' change notes",
        "notes · docs/guide · README · krinik_change_notes.json", "one fact written once and fed to every place (HOUSE_RULES 20, 42); read each after the edit")
    add("C", "MANUAL", "the mods' DESCRIPTIONS match what each mod does in this release — the game's mod list (modinfo), the README and guide mod tables, KRINIK MODIFIED marks",
        "kit/modinfo.json · _config/public_release/mods-table.mjs · modpack.json", "set-pak-modinfo.py <game Mods>; node _config/public_release/mods-table.mjs (it refuses a mark that differs from the manifest)")
    rd = os.path.join(PACK, "_config", "public_release", "README.draft.md")
    add("C", "OK" if v in read(rd) else "TODO", "the public README (version, mods table, known issues) rendered for %s" % v,
        "_config/public_release/README.draft.md", "node _config/public_release/mods-table.mjs → make_public_tree.py → a commit on top of the public history")
    add("C", "MANUAL", "the Nexus description — only when this release goes to Nexus (the owner's word)", "_config/release/build_nexus_description.py",
        "build it, then KUMM tools/nexus-desc.mjs write / verify")
    rcd, outd = run([PY, "-I", "-X", "utf8", os.path.join(PACK, "_config", "release", "dash_lint.py"), notes]) if nt else (1, "")
    add("C", "MANUAL", "the dash lint and the voice lint over every text above, and a clean-instance read of the notes", "dash_lint.py · kaif-voice-lint.mjs check",
        "python -I -X utf8 _config/release/dash_lint.py; node KUMM/.kaif/tools/kaif-voice-lint.mjs check <files> --genre document")
    # ---------- D. build and install ----------
    add("D", "MANUAL", "the working game deployed and verified with this build", "D:/Games/Conan Exiles %s" % gv,
        "powershell -File KUMM/Deploy-ModPack.ps1 -PackDir ConanExiles -Deploy, then -Verify; set-pak-modinfo.py")
    add("D", "MANUAL", "make_release.sh into an EMPTY work dir (parts, launcher, guide PDF, SHA256SUMS, 7z t)", "_config/release/make_release.sh",
        "bash _config/release/make_release.sh <empty dir> <notes>")
    add("D", "MANUAL", "the install from the parts on a fresh copy of the clean game, and the UPDATE from the previous release through the launcher", "a copy under KUMM/.work",
        "the launcher's player path, real input, a run report")
    # ---------- E. publication (after the owner's word) ----------
    if "--published" in argv:
        r1, rel = run(["gh", "release", "view", "v" + v, "--repo", REPO, "--json", "assets", "--jq", "[.assets[].name]|join(\" \")"])
        names = rel.split() if r1 == 0 else []
        latest = prev_tag == "v" + v
        ok = r1 == 0 and latest and any(n.endswith(".exe") for n in names) and any(n.endswith(".pdf") for n in names) and any("SHA256" in n for n in names) \
            and any(".zip.001" in n for n in names)
        add("E", "OK" if ok else "TODO", "the GitHub release v%s is Latest with parts, launcher, guide PDF, checksums" % v, REPO,
            "gh release create v%s --latest --title … --notes-file <notes> <assets> (HOUSE_RULES 25.2, 42.1)" % v)
        r2, tags = run(["gh", "api", "repos/%s/tags" % REPO, "--jq", ".[].name"])
        add("E", "OK" if ("v" + v) in tags.split() else "TODO", "the tag v%s in the public repository (and launcher-vX.Y.Z when the launcher changed)" % v, REPO,
            "gh release create makes the tag on the public tree's commit; a launcher release has its own tag")
        pub = os.path.join(PACK, "_config", "release", "published_%s" % v.replace(".", "_"))
        add("E", "OK" if os.path.isdir(pub) else "TODO", "the published texts kept in the pack", os.path.relpath(pub, PACK), "copy the notes and texts (HOUSE_RULES 25.2)")
        add("E", "MANUAL", "the release page, the README and the guide PDF read back in their medium; the fixed issues commented «fixed in v%s»" % v,
            "github.com/" + REPO, "open each; gh issue comment <n>")
        add("E", "MANUAL", "the shipment and work dirs removed once shipped", "KUMM/.work/<release dirs>", "node _config/rm-tree.mjs <dir> (HOUSE_RULES 25.2)")
    todo = 0
    for stage, state, what, where, how in items:
        print("%s %-6s %s — %s" % (stage, state, what, where))
        if state != "OK":
            print("         → %s" % how)
        todo += state == "TODO"
    print("release ritual of %s: %d TODO, %d MANUAL, %d OK" % (v, todo, sum(1 for i in items if i[1] == "MANUAL"), sum(1 for i in items if i[1] == "OK")))
    return 1 if todo else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
