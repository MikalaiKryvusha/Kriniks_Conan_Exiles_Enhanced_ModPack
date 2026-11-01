"""Map missing FPackageIds (from game log) to names by hashing every package path of the 2.2 dev kit."""
import importlib.util, os, sys

spec = importlib.util.spec_from_file_location("pid", r"D:\work\ai_sandbox\ConanExiles\_config\devkit\package-id.py")
P = importlib.util.module_from_spec(spec); spec.loader.exec_module(P)

KIT = r"F:\CEUE5Devkit"
ids = {l.strip().upper() for l in open(sys.argv[1]) if l.strip()}
roots = [(os.path.join(KIT, "UE4", "Content"), "/Game"), (os.path.join(KIT, "Engine", "Content"), "/Engine")]
for base in (os.path.join(KIT, "Engine", "Plugins"), os.path.join(KIT, "UE4", "Plugins")):
    for dp, dn, fn in os.walk(base):
        if os.path.basename(dp) == "Content" and os.path.isfile(os.path.join(os.path.dirname(dp), os.path.basename(os.path.dirname(dp)) + ".uplugin")):
            roots.append((dp, "/" + os.path.basename(os.path.dirname(dp))))
            dn[:] = []
total = 0
found = {}
for root, mount in roots:
    for dp, dn, fn in os.walk(root):
        for f in fn:
            if not f.endswith((".uasset", ".umap")):
                continue
            rel = os.path.relpath(os.path.join(dp, f[: f.rfind(".")]), root).replace("\\", "/")
            name = mount + "/" + rel
            total += 1
            h = "%016X" % P.pkgid(name)
            if h in ids:
                found[h] = name
print("kit packages hashed:", total, "roots:", len(roots), file=sys.stderr)
print("matched %d of %d" % (len(found), len(ids)), file=sys.stderr)
for h in sorted(ids):
    print(h + "\t" + found.get(h, "?"))
