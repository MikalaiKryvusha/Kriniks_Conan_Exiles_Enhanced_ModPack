"""
make_variant.py — the launcher compiled with another launcher version, for the self-update cases (KUMM plan 54, cases S1/S2).
The same sources and the same compiler call as build-docs.py; only BuildInfo.LauncherVersion differs, and both outputs go to the given folder,
never over _config/launcher/BuildInfo.g.cs or bin/.
    python -I -X utf8 _config/launcher/test/make_variant.py <out dir> <launcher version>
Prints the exe path. [NOT-TESTED]
"""
import importlib.util
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("build_docs", HERE.parents[1] / "release" / "build-docs.py")
bd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bd)

out, version = Path(sys.argv[1]).resolve(), sys.argv[2]
out.mkdir(parents=True, exist_ok=True)
bd.BUILD_INFO = out / "BuildInfo.g.cs"
bd.LAUNCHER_EXE = out / "KrinikConanLauncher.exe"
manifest = json.loads(bd.MANIFEST.read_text(encoding="utf-8"))
launcher = dict(bd.launcher_fields(manifest), version=version)
bd.build_launcher(bd.parse(bd.LINKS_FILE), manifest["packVersion"], manifest["uninstall"]["cmd"], Path(manifest["guide"]).name, launcher)
print(bd.LAUNCHER_EXE)
