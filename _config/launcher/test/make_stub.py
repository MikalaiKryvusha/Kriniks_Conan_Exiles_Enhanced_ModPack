"""
make_stub.py — tiny Windows programs for the launcher's cases (KUMM epic 55 B7, plans/57): `hang` waits 120 s without a window (a new launcher that
hangs before its window; a «running game» named ConanSandbox.exe), `exit` ends at once (a new launcher that dies at start — replaces whoami.exe, whose
console window flashed on the owner's screen), `game <CL>` — a stand-in for the game's ConanSandbox-Win64-Shipping.exe whose ProductVersion is
«++exiles+release-CL-<CL>» exactly as Funcom's exe reports it (probe 2026-11-18 10:10), `scan <CL>` — the same string only inside the file (UTF-16, the
launcher's fallback read when ProductVersion has no «-CL-»). Compiled by the same csc as the launcher with -target:winexe: no window of any kind.
    python -I -X utf8 _config/launcher/test/make_stub.py <out exe> hang|exit|ghost|game <CL>|scan <CL>
Prints the exe path. [NOT-TESTED]
"""
import importlib.util
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("build_docs", HERE.parents[1] / "release" / "build-docs.py")
bd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bd)

out, kind = Path(sys.argv[1]).resolve(), sys.argv[2]
cl = sys.argv[3] if len(sys.argv) > 3 else ""
if kind in ("game", "scan") and not cl.isdigit():
    print("usage: make_stub.py <out exe> game|scan <CL digits>")
    sys.exit(2)
MARK = "++exiles+release-CL-" + cl
SOURCES = {
    "hang": "static class Stub { static void Main() { System.Threading.Thread.Sleep(120000); } }\n",
    "exit": "static class Stub { static void Main() { } }\n",
    # AssemblyInformationalVersion becomes the Win32 ProductVersion of the exe (the C# compiler writes the version resource from the attributes).
    "game": f'[assembly: System.Reflection.AssemblyInformationalVersion("{MARK}")]\nstatic class Stub {{ static void Main() {{ }} }}\n',
    # A string literal lives in the #US heap as UTF-16LE — the bytes the launcher's fallback scan looks for; ProductVersion stays without «-CL-».
    "scan": f'static class Stub {{ static readonly string Mark = "{MARK}"; static void Main() {{ System.GC.KeepAlive(Mark); }} }}\n',
    # The red test of offscreen.ps1: a 1x1 fully transparent tool window at the primary screen's corner for 6 s — "on screen" to the watcher, invisible
    # to the owner (no taskbar button, alpha 0).
    "ghost": "using System.Windows.Forms; static class Stub { static void Main() { var f = new Form { FormBorderStyle = FormBorderStyle.None, "
             "ShowInTaskbar = false, StartPosition = FormStartPosition.Manual, Location = new System.Drawing.Point(0, 0), Size = new System.Drawing.Size(1, 1), "
             "Opacity = 0.0 }; var t = new Timer { Interval = 6000 }; t.Tick += (s, e) => f.Close(); t.Start(); Application.Run(f); } }\n",
}
out.parent.mkdir(parents=True, exist_ok=True)
src = out.with_suffix(".stub.cs")
src.write_text(SOURCES[kind], encoding="utf-8")
# judge B7 round 2 C4: the source goes even when csc times out
try:
    r = subprocess.run([str(bd.find_csc()), "-nologo", "-target:winexe", "-r:System.Windows.Forms.dll", "-r:System.Drawing.dll", f"-out:{out}", str(src)], capture_output=True, text=True, timeout=120)
finally:
    src.unlink(missing_ok=True)
if r.returncode != 0:
    print(r.stdout + r.stderr)
    sys.exit(1)
print(out)
