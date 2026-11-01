"""Swap ONLY the Paths= lines of [Core.System] in the pack Engine.ini with the vanilla 3.0.1 ones.
Everything else in the file (our tuning, written by hand on top of build-engine-ini.py) stays byte-for-byte."""
import sys

pack_ini, vanilla_ini = sys.argv[1], sys.argv[2]
raw = open(pack_ini, "rb").read()
eol = "\r\n" if b"\r\n" in raw else "\n"
bom = raw.startswith(b"\xef\xbb\xbf")
old = raw.decode("utf-8-sig").splitlines()
van = open(vanilla_ini, encoding="utf-8-sig").read().splitlines()

start = old.index("[Core.System]")
end = next(i for i in range(start + 1, len(old)) if old[i].startswith("["))
block = old[start + 1:end]
first = next(i for i, l in enumerate(block) if l.startswith("Paths="))
last = max(i for i, l in enumerate(block) if l.startswith("Paths="))
inner = [l for l in block[first:last + 1] if not l.startswith("Paths=")]
if inner:
    sys.exit("non-Paths lines between Paths lines, refusing: %r" % inner)
new_paths = [l for l in van if l.startswith("Paths=")]
out = old[:start + 1] + block[:first] + new_paths + block[last + 1:] + old[end:]

data = (eol.join(out) + eol).encode("utf-8")
if bom:
    data = b"\xef\xbb\xbf" + data
open(pack_ini, "wb").write(data)
print("lines %d -> %d; Paths %d -> %d; eol %r; bom %s" % (
    len(old), len(out), last - first + 1, len(new_paths), eol, bom))
