# -*- coding: utf-8 -*-
"""check-lua-templates.py — a FindAllOf / FindFirstOf of a UMG CHILD widget (TextBlock, Image, Border …) must keep only LIVE instances.

Why (KUMM EXP-0385, EXP-0421 — two strikes): a child widget that lives in another widget's tree has its CLASS TEMPLATE as an object of the same class
(`…W_SmoothHP_C:WidgetTree.TextBlock_TempText`, no «Default__» in the name). FindAllOf returns it too; a section that coloured it left the live field
on screen white («37 °C белая», the owner 2026-11-01 10:10). A live child sits in a numbered tree: `WidgetTree_<n>.` in its full name.

Rule checked: within WINDOW lines after a FindAllOf/FindFirstOf of a child class there must be the live-instance filter `WidgetTree_%d`
(or a `-- templates-ok: <why>` marker on the call line). Exit 0 — clean; 1 — findings printed; 2 — no files.
    python -I -X utf8 _config/devkit/check-lua-templates.py [<file or dir> …]   (default: every _unpacked/*/ue4ss/Scripts and */Scripts Lua file)
[TESTED: 2026-11-01 · red on krinik_hud_outline.lua of pack 2c2ddd6 (the template bug), green on eef2f86 and later · KUMM EXPERIENCE EXP-0421]
"""
import re
import sys
from pathlib import Path

PACK = Path(__file__).resolve().parents[2]
CHILD = ("TextBlock", "RichTextBlock", "Image", "Border", "Button", "SizeBox", "HorizontalBox", "VerticalBox", "CanvasPanel", "Overlay",
         "ScrollBox", "ProgressBar", "Spacer", "WidgetSwitcher", "CheckBox", "Slider", "EditableText")
CALL = re.compile(r"Find(?:All|First)Of\(\s*[\"'](" + "|".join(CHILD) + r")[\"']\s*\)")
LIVE = "WidgetTree_%d"
WINDOW = 8


def files(args):
    if args:
        for a in args:
            p = Path(a)
            yield from (p.rglob("*.lua") if p.is_dir() else [p])
        return
    for base in (PACK / "_unpacked").glob("*"):
        yield from base.rglob("*.lua")


def main():
    found, seen = [], 0
    for f in files(sys.argv[1:]):
        seen += 1
        lines = f.read_text(encoding="utf-8", errors="replace").splitlines()
        for i, line in enumerate(lines):
            m = CALL.search(line)
            if not m or "templates-ok:" in line:
                continue
            if not any(LIVE in l for l in lines[i:i + WINDOW]):
                found.append(f"{f.relative_to(PACK) if PACK in f.parents else f}:{i + 1}: FindAllOf/FindFirstOf('{m.group(1)}') without the live-instance "
                             f"filter `{LIVE}` — the class template is returned too (EXP-0421)")
    if not seen:
        print("no Lua files")
        return 2
    for x in found:
        print(x)
    print(f"checked {seen} Lua files: {len(found)} finding(s)")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
