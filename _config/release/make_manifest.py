# make_manifest.py -- the per-file manifest of a build release, so the launcher downloads only the files that changed (KUMM plan 57, phase 6, step 1).
#
#   python -I -X utf8 make_manifest.py <export folder> --tag <tag> --version <packVersion> --out <release dir>
#          [--previous <manifest.json> | --previous-from <folder with published_*/manifest.json>] [--allow-changed <file>] [--check-only]
#
# What it writes into <release dir>:
#   manifest.json           {format, version, tag, root, files[{path, size, sha256, asset | group | parts[]}], groups[{asset, size, sha256, files}]}
#   <hash16>-<name>         one asset per file of 1 MiB and more, below the part size — a HARDLINK of the export's file (the release dir must be on the
#                           export's volume: no second 13.7 GB on disk)
#   <hash16>-<name>.pN      the parts of a file of PART bytes and more (PART = the volume part size of make_release.sh, below GitHub's 2 GiB per asset)
#                           — real copies, each read back and hashed after writing; the joined parts must give the file's SHA-256
#   small-<hash16>.zip      every file under 1 MiB in one stored zip: sorted entries, fixed time, attributes and system — the same files give the same bytes
# THE CONTRACT for the launcher: every manifest path and every group entry is relative to the bundle root `<GameDir>/<root>` (no root prefix, «/» as the
# separator, no «./»); paths compare case-insensitively (OrdinalIgnoreCase — NTFS); an asset name is the first 16 hex of the file's SHA-256 + its basename
# reduced to [A-Za-z0-9._-] (GitHub renames other characters); the full SHA-256 in the manifest is the truth. Two files with the same bytes and basename
# share one asset.
#
# The previous release: --previous names its manifest; --previous-from picks, among <folder>/published_*/manifest.json, the one with the highest version
# BELOW this one in release order (X.Y.Z-RCn before X.Y.Z; the file's date plays no part). The «changed vs <version>» line and its list follow, and the
# download an update from it would cost (per distinct asset, the small-files group once). THE REPRODUCIBILITY GUARD: a third-party pak (a .pak outside
# pack/src/Krinik*) that is added or changed vs the previous release must be named in --allow-changed (lines «<path or fnmatch pattern>  # <why>»; no
# file — nothing is allowed); otherwise exit 1. RC1 -> RC2 changed 62 such paks / 13.56 GB with equal content (KUMM researches/conan-launcher-delta-update §1).
# --check-only writes nothing into <release dir>: the hashes, the group's size (built in a temp folder) and the comparison are printed.
#
# Six answers (KUMM researches/efficient-code/EFFICIENT_CODE.md): trigger — one run per release; inputs — the export's files; N — every file once
# (≈ 190 files, 13.7 GB); static vs volatile — none, a one-shot tool; budget — one read of every byte, plus a write and a read-back of the split parts
# (≈ 2.4 GB); measurement — the elapsed time and MB/s are printed (8–15 s for 13.7 GB on 2026-11-21).
#
# Exit: 0 written (or checked) · 1 a check failed (an unexpected third-party change, a hash clash, two paths differing only in case, a part or the group
# zip did not read back, the release dir on another volume) · 2 bad arguments (an unparsable version with --previous-from, an allow line with no reason).
# PART is the default; make_release.sh passes its RELEASE_PART by --part-size, so the volumes and the parts are cut by one number.
# [TESTED: 2026-11-21 · the RC1 and RC2 bundles: two runs byte-equal, RC1 vs RC2 = the recon's 74 files · KUMM testcases/reports/2026-11-21_conan-reproducible-export.md]
import argparse, fnmatch, glob, hashlib, json, os, re, sys, tempfile, time, zipfile

SMALL = 1024 * 1024                 # files under 1 MiB go into the group zip: 118 files / 10.6 MB in RC2 — one asset instead of 118 (recon §5)
PART = 1992294400                   # the volume part size of make_release.sh (RELEASE_PART), below GitHub's 2 GiB per asset
ZIP_TIME = (1980, 1, 1, 0, 0, 0)    # the zip format's earliest date: a fixed time keeps the group's bytes equal from build to build
ZIP_ATTR = 0o644 << 16              # set explicitly: Python 3.14 replaces a zero external_attr by 0o600 << 16, another Python might not (the judge 2026-11-21)
STALE = re.compile(r"^(?:[0-9a-f]{16}-.+|small-[0-9a-f]{16}\.zip)$")
KRINIK = "pack/src/krinik"           # our own mods: their paks change with every release by design (the change note)
FORMAT = 1


def sha256_file(path):
    with open(path, "rb") as fh:
        return hashlib.file_digest(fh, "sha256").hexdigest()


def safe(name):
    return re.sub(r"[^A-Za-z0-9._-]", "_", name)


def release_key(v):
    """X.Y.Z-RCn before X.Y.Z: (x, y, z, 0, n) for a candidate, (x, y, z, 1, 0) for the release; None — not a build version."""
    m = re.match(r"^(\d+)\.(\d+)\.(\d+)(?:-RC(\d+))?$", v or "", re.I)
    if not m:
        return None
    x, y, z, rc = m.groups()
    return (int(x), int(y), int(z), 0 if rc else 1, int(rc or 0))


def load(path):
    with open(path, encoding="utf-8-sig") as fh:          # a BOM from a PowerShell edit is accepted (the judge 2026-11-21)
        return json.load(fh)


def pick_previous(folder, version):
    """An unparsable version — this one or a kept one — stops the run (exit 2): a skipped manifest would switch the guard off silently (the judge
    2026-11-21, round 2)."""
    me, best = release_key(version), None
    if me is None:
        print("[fail] --version «%s» is not X.Y.Z or X.Y.Z-RCn: the previous release cannot be chosen" % version)
        raise SystemExit(2)
    for p in sorted(glob.glob(os.path.join(folder, "published_*", "manifest.json"))):
        v = load(p).get("version")
        k = release_key(v if isinstance(v, str) else None)
        if k is None:
            print("[fail] %s: version «%s» is not X.Y.Z or X.Y.Z-RCn" % (p, v))
            raise SystemExit(2)
        if k < me and (best is None or k > best[0]):
            best = (k, p)
    return best[1] if best else None


def walk(root):
    out = []
    for d, dirs, files in os.walk(root):
        dirs.sort()
        for n in sorted(files):
            p = os.path.join(d, n)
            out.append((os.path.relpath(p, root).replace(os.sep, "/"), p))
    out.sort(key=lambda t: t[0])
    return out


def link(src, dst, existed):
    """A hardlink of the export's file; an asset already there with the same size is kept. Returns 'link', 'kept' (there before this run) or 'same'
    (written earlier in this run for another path with the same bytes and name)."""
    if os.path.exists(dst):
        if os.path.getsize(dst) != os.path.getsize(src):
            raise SystemExit("asset %s exists with another size" % dst)
        return "kept" if dst in existed else "same"
    try:
        os.link(src, dst)
    except OSError as e:
        raise SystemExit("cannot hardlink %s into %s (%s) — the release dir must be on the export's NTFS volume" % (src, os.path.dirname(dst), e))
    return "link"


def write_parts(src, stem, out, size, sha):
    parts, n, done, whole = [], 1, 0, hashlib.sha256()
    with open(src, "rb") as fh:
        while done < size:
            name = "%s.p%d" % (stem, n)
            h, left = hashlib.sha256(), min(PART, size - done)
            dst = os.path.join(out, name)
            with open(dst + ".tmp", "wb") as w:
                while left:
                    b = fh.read(min(8 << 20, left))
                    if not b:
                        raise SystemExit("short read of %s" % src)
                    h.update(b)
                    whole.update(b)
                    w.write(b)
                    left -= len(b)
            os.replace(dst + ".tmp", dst)
            if sha256_file(dst) != h.hexdigest():                    # re-read through the file system (often from its cache): the write is checked, not the platter
                raise SystemExit("part %s did not read back" % name)
            psize = os.path.getsize(dst)
            parts.append({"asset": name, "size": psize, "sha256": h.hexdigest()})
            done += psize
            n += 1
    if whole.hexdigest() != sha:
        raise SystemExit("the parts of %s join to another SHA-256 than the file's — the file changed during the run" % src)
    return parts


def write_group(entries, out):
    """The stored zip of the small files in sorted order, fixed time, attributes and system; named by its own SHA-256, checked by reading it back."""
    tmp = os.path.join(out, "small.zip.tmp")
    with zipfile.ZipFile(tmp, "w", compression=zipfile.ZIP_STORED) as z:
        for rel, p, _ in entries:
            zi = zipfile.ZipInfo(rel, date_time=ZIP_TIME)
            zi.create_system = 0
            zi.external_attr = ZIP_ATTR
            zi.compress_type = zipfile.ZIP_STORED
            with open(p, "rb") as fh:
                z.writestr(zi, fh.read())
    digest = sha256_file(tmp)
    name = "small-%s.zip" % digest[:16]
    with zipfile.ZipFile(tmp) as z:
        got = {i.filename: hashlib.sha256(z.read(i.filename)).hexdigest() for i in z.infolist()}
    want = {rel: sha for rel, _, sha in entries}
    if got != want:
        os.remove(tmp)
        raise SystemExit("the group zip did not read back: %d of %d entries differ" % (sum(1 for k in want if got.get(k) != want[k]), len(want)))
    dst = os.path.join(out, name)
    if os.path.exists(dst):
        os.remove(dst)
    os.replace(tmp, dst)
    return {"asset": name, "size": os.path.getsize(dst), "sha256": digest, "files": len(entries)}


def asset_sizes(man):
    """asset name -> size of every downloadable unit a file entry points to (an asset, its parts, its group)."""
    groups = {g["asset"]: g["size"] for g in man["groups"]}
    def units(f):
        if "asset" in f:
            return [(f["asset"], f["size"])]
        if isinstance(f.get("parts"), list):
            return [(p["asset"], p["size"]) for p in f["parts"]]
        g = f.get("group")
        return [(g, groups.get(g, 0))] if isinstance(g, str) else []
    return units


def diff(prev, cur):
    """Keys are lower-cased paths (NTFS): a case-only rename is a change, not «add + remove» (the judge 2026-11-21)."""
    pf = {f["path"].lower(): f for f in prev["files"]}
    cf = {f["path"].lower(): f for f in cur["files"]}
    added = sorted(cf[k]["path"] for k in cf if k not in pf)
    removed = sorted(pf[k]["path"] for k in pf if k not in cf)
    changed = sorted(cf[k]["path"] for k in cf if k in pf and cf[k]["sha256"] != pf[k]["sha256"])
    units, need = asset_sizes(cur), {}
    for p in added + changed:
        for name, size in units(cf[p.lower()]):
            need[name] = size                                   # per distinct asset: three paths sharing one asset download it once
    return added, removed, changed, sum(need.values())


def allowed(path, rules):
    return next((why for pat, why in rules if fnmatch.fnmatchcase(path.lower(), pat.lower())), None)


def read_rules(path):
    """Lines «<path or fnmatch pattern>  # <why>»; a line without its reason stops the run (exit 2): the allow file is the record of why a mod changed."""
    rules = []
    if path and os.path.exists(path):
        for n, line in enumerate(open(path, encoding="utf-8-sig").read().splitlines(), 1):
            pat, _, why = line.partition("#")
            if pat.strip() and not why.strip():
                print("[fail] %s:%d: «%s» carries no reason after «#»" % (path, n, pat.strip()))
                raise SystemExit(2)
            if pat.strip():
                rules.append((pat.strip(), why.strip()))
    return rules


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("export")
    ap.add_argument("--tag", required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("--out")
    ap.add_argument("--previous")
    ap.add_argument("--previous-from")
    ap.add_argument("--allow-changed")
    ap.add_argument("--check-only", action="store_true")
    ap.add_argument("--part-size", type=int, help="make_release.sh passes RELEASE_PART; the launcher's stand cuts a 5 MB file into 2 MiB parts")
    a = ap.parse_args()
    if a.part_size:
        global PART
        PART = a.part_size
    if not os.path.isdir(a.export) or (not a.check_only and not a.out) or (a.previous and a.previous_from):
        print("usage: make_manifest.py <export folder> --tag <tag> --version <v> --out <release dir> [--previous <manifest.json> | --previous-from <folder>]"
              " [--allow-changed <file>] [--check-only]")
        return 2
    t0 = time.time()
    files, small, names, total, lower = [], [], {}, 0, {}
    for rel, p in walk(a.export):
        if rel.lower() in lower:
            print("[fail] two paths differ only in case: %s and %s" % (lower[rel.lower()], rel))
            return 1
        lower[rel.lower()] = rel
        size, sha = os.path.getsize(p), sha256_file(p)
        total += size
        e = {"path": rel, "size": size, "sha256": sha}
        if size < SMALL:
            small.append((rel, p, sha))
            e["group"] = None
        else:
            stem = "%s-%s" % (sha[:16], safe(os.path.basename(rel)))
            # Keyed case-insensitively: «Same.pak» and «same.pak» with the same bytes would be two names of ONE file on NTFS — the first spelling is
            # reused (the judge 2026-11-21, round 2); different bytes behind one name is a clash.
            first = names.get(stem.lower())
            if first and first[1] != sha:
                print("[fail] asset name clash: %s for %s and another file" % (stem, rel))
                return 1
            stem = first[0] if first else stem
            names[stem.lower()] = (stem, sha)
            e["asset" if size < PART else "parts"] = stem
        e["_src"] = p
        files.append(e)
    took = time.time() - t0
    print("hashed %d files, %.1f MB in %.0f s (%.0f MB/s)" % (len(files), total / 1e6, took, total / 1e6 / max(took, 0.001)))
    out = a.out if not a.check_only else None
    tmpdir = tempfile.TemporaryDirectory() if a.check_only else None
    target = out or tmpdir.name
    os.makedirs(target, exist_ok=True)
    existed = {os.path.join(target, n) for n in os.listdir(target)}
    counts, written_parts, groups = {"link": 0, "kept": 0, "same": 0}, {}, []
    for e in files:
        if "asset" in e and out:
            counts[link(e["_src"], os.path.join(out, e["asset"]), existed)] += 1
        elif "parts" in e:
            stem = e["parts"]
            if out:
                if stem not in written_parts:                      # two files with the same bytes and name: their parts are written once
                    written_parts[stem] = write_parts(e["_src"], stem, out, e["size"], e["sha256"])
                e["parts"] = written_parts[stem]
            else:
                e["parts"] = [{"asset": "%s.p%d" % (stem, i + 1), "size": min(PART, e["size"] - i * PART), "sha256": ""} for i in range(-(-e["size"] // PART))]
    if small:
        g = write_group(small, target)                              # in --check-only into the temp folder: its real size for the estimate
        groups.append(g)
        for e in files:
            if "group" in e:
                e["group"] = g["asset"]
    for e in files:
        e.pop("_src")
    man = {"format": FORMAT, "version": a.version, "tag": a.tag, "root": os.path.basename(os.path.normpath(a.export)), "files": files, "groups": groups}
    units = asset_sizes(man)
    every = {n for f in files for n, _ in units(f)}
    if out:
        removed = 0
        for n in sorted(os.listdir(out)):                           # assets of an earlier run into this dir that this manifest does not name
            if STALE.match(n) and n not in every:
                os.remove(os.path.join(out, n))
                removed += 1
                print("removed stale asset %s" % n)
        print("assets: %d files (%d hardlinks, %d kept from before, %d split files in %d parts, the group %s of %d small files)%s" % (
            len(every), counts["link"], counts["kept"], len(written_parts), sum(len(v) for v in written_parts.values()),
            groups[0]["asset"] if groups else "-", len(small), ", %d stale removed" % removed if removed else ""))
    prev_path = a.previous or (pick_previous(a.previous_from, a.version) if a.previous_from else None)
    if a.previous_from:
        print("previous manifest: %s" % (prev_path or "none (no kept release below %s)" % a.version))
    bad = []
    if prev_path:
        prev = load(prev_path)
        added, removed, changed, dl = diff(prev, man)
        print("changed vs %s: %d files, %.1f MB to download (%d B; added %d, changed %d, removed %d)" % (
            prev.get("version", "?"), len(added) + len(changed), dl / 1e6, dl, len(added), len(changed), len(removed)))
        rules = read_rules(a.allow_changed)
        for tag, lst in (("+", added), ("*", changed), ("-", removed)):
            for p in lst:
                why = None
                if tag != "-" and p.lower().endswith(".pak") and not p.lower().startswith(KRINIK):
                    why = allowed(p, rules)
                    if why is None:
                        bad.append(p)
                print("  %s %s%s" % (tag, p, ("   [allowed: %s]" % why) if why else ("   [NOT EXPECTED]" if p in bad else "")))
        if bad:
            print("[fail] %d third-party pak(s) changed vs %s without a line in %s — a mod updated since that release is named there with its reason;"
                  " a pak whose mod did not change means the export is not reproducible again" % (len(bad), prev.get("version", "?"), a.allow_changed or "--allow-changed"))
    if out:
        text = json.dumps(man, ensure_ascii=False, indent=1) + "\n"
        with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        print("manifest.json: %d files, %d assets + the manifest, %d bytes" % (len(files), len(every), len(text.encode("utf-8"))))
    if tmpdir:
        tmpdir.cleanup()
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
