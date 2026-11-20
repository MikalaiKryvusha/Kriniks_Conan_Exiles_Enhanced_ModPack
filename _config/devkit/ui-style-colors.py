# ui-style-colors.py — every colour of Funcom's UI style system (Conan Exiles /Game/UI/Styling/**/FS_*): walks the uaj JSON of each style asset, collects every
# LinearColor (SlateColor's SpecifiedColor included) with its property path, writes a TSV: style · path · linear RGBA · sRGB hex · alpha. Plus the font of each
# text style (FontObject, Size, TypefaceFontName). For the owner's word 2026-11-10 13:19 «у конана есть конкретная цветовая дизайн схемма» — the palette is
# READ from the game (KUMM researches/conan-ui-color-scheme/).
#   1. retoc-5.8 to-legacy --version UE5_7 --no-shaders --filter FS_ "<game>/ConanSandbox/Content/Paks" <work>
#   2. uaj tojson <work>/…/FS_X.uasset <work>/…/FS_X.json VER_UE5_8   (each)
#   3. python -I -X utf8 ui-style-colors.py <work> <out.tsv>
# [NOT-TESTED]
import json
import os
import sys


def srgb(c):
    c = max(0.0, min(1.0, float(c)))
    return round(255 * (12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055))


def walk(node, path, out):
    if isinstance(node, dict):
        t = node.get("$type", "")
        name = node.get("Name")
        here = path + ("/" + name if isinstance(name, str) and name else "")
        if "LinearColorPropertyData" in t and isinstance(node.get("Value"), dict):
            v = node["Value"]
            out.append((here, v.get("R"), v.get("G"), v.get("B"), v.get("A")))
        for k, v in node.items():
            if k not in ("$type",):
                walk(v, here, out)
    elif isinstance(node, list):
        for v in node:
            walk(v, path, out)


def fonts(node, out):
    if isinstance(node, dict):
        if node.get("Name") == "FontObject":
            out.setdefault("font", node.get("Value"))
        if node.get("Name") == "Size" and isinstance(node.get("Value"), (int, float)):
            out.setdefault("size", node.get("Value"))
        if node.get("Name") == "TypefaceFontName":
            out.setdefault("face", node.get("Value"))
        for v in node.values():
            fonts(v, out)
    elif isinstance(node, list):
        for v in node:
            fonts(v, out)


def main(root, out_tsv):
    rows = []
    for dp, _, fs in os.walk(root):
        for f in fs:
            if not (f.startswith("FS_") and f.endswith(".json")):
                continue
            d = json.load(open(os.path.join(dp, f), encoding="utf-8"))
            style = os.path.relpath(os.path.join(dp, f[:-5]), root).replace("\\", "/").split("UI/Styling/")[-1]
            cols = []
            walk(d.get("Exports", []), "", cols)
            fo = {}
            fonts(d.get("Exports", []), fo)
            names = {i: x.get("ObjectName") for i, x in enumerate(d.get("Imports", []))}
            font = fo.get("font")
            if isinstance(font, int) and font < 0:
                font = names.get(-font - 1)
            for path, r, g, b, a in cols:
                try:   # uaj writes the floats as strings («+0.5» / «1E-05») — numbers here
                    r, g, b = float(r), float(g), float(b)
                    a = float(a) if a is not None else 1.0
                except (TypeError, ValueError):
                    continue
                hexs = "#%02X%02X%02X" % (srgb(r), srgb(g), srgb(b))
                rows.append((style, path.strip("/"), "%.4f %.4f %.4f" % (r, g, b), hexs, "%.2f" % (a if a is not None else 1), font or "", fo.get("size", ""), fo.get("face", "")))
    rows.sort()
    with open(out_tsv, "w", encoding="utf-8", newline="\n") as f:
        f.write("style\tpath\tlinear_rgb\tsrgb_hex\talpha\tfont\tsize\tface\n")
        for r in rows:
            f.write("\t".join(str(x) for x in r) + "\n")
    print("rows %d -> %s" % (len(rows), out_tsv))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
