# repak_tool.py -- the one place that says which pak-writing commands of the build run on ONE thread, so the same folder packs into the same bytes.
#
#   import repak_tool
#   subprocess.run(args, ..., env=repak_tool.env_for(args))   # the `run()` of every devkit script that writes a pak
#
# WHY (2026-11-21 10:2x, KUMM researches/conan-launcher-delta-update/README.md §1 and its step 0). repak_cli 0.2.3 `pack` reads and hashes the entries on
# rayon threads and writes them in the order the threads finish (repak_cli main.rs: par_bridge + sync_channel): one unpacked folder (Emberlight, 370 MB,
# 11 entries) packed three times gave three different SHA-256, while RAYON_NUM_THREADS=1 gave three equal ones at the same speed (0.55 s both ways). Every
# release export rewrites the wrapper of every third-party pak (set-pak-modinfo.py), so RC1 -> RC2 changed 62 paks / 13.56 GB byte-wise with no change of
# content, and a per-file update would have downloaded the whole build again. `retoc to-zen` writes its chunks the same way (the judge 2026-11-21, retoc_cli
# main.rs), so it gets one thread too. `retoc pack-raw` keeps its order on many threads (byte-equal outputs, 2.8 s vs 11.3 s on one thread — the judge
# 2026-11-21), and to-legacy, unpack, get and list write no pak: they keep the default threads.
# Guard: devkit/t_repak_one_thread.py — every devkit script that names `"pack"` of repak or `"to-zen"` imports this module. The release-level check is
# make_manifest.py's «changed vs the previous release» line in make_release.sh step 4c (KUMM plan 57 phase 6).
# [TESTED: 2026-11-21 · Emberlight.pak unpacked, packed 3x default -> 3 hashes, 3x RAYON_NUM_THREADS=1 -> 1 hash; set-pak-modinfo.py A/B on 4 paks equal · KUMM testcases/reports/2026-11-21_conan-reproducible-export.md]
import os

ONE_THREAD = dict(os.environ, RAYON_NUM_THREADS="1")


def env_for(args):
    """The environment for one tool call: one rayon thread for `repak pack` and `retoc to-zen`, None (the parent's own) for everything else."""
    tool = os.path.basename(str(args[0])).lower() if args else ""
    if (tool == "repak.exe" and "pack" in args[1:2]) or (tool.startswith("retoc") and "to-zen" in args):
        return ONE_THREAD
    return None
