# crash-forensics.py [N] [--game <dir>] — one line per crash folder of the game (newest N, default 10): time, the exception, the stack's depth and hash,
# and the agent remote's commands found in the minidump.
# Зачем (KUMM bugs/118, EXP-0613, 2026-11-22): семь падений UE4SS день искали делением модов пополам, а причиной была команда самого агента (проба
# esc_listen.lua). Её видно за минуту: одинаковый хеш стека у всех падений = одно место вызова; строки минидампа хранят команду пульта, что шла в этом сеансе.
# Перед любым делением пополам — этот разбор. Строки минидампа — память стека, не журнал: команда в нём значит «была в памяти», время даёт повтор.
# [TESTED: 2026-11-22 19:4x · 11 папок падений Conan 3.1.1: 7 падений бага 118 и 2 повтора дают стек 47 кадров с одним хешем 1a8468a7 и команду
# esc_listen.lua; падение 10:44 — другой хеш и команда list_teleports.lua; падение D3D12 20.11 — 0 кадров UE4SS · KUMM bugs/118]
# [TESTED: 2026-11-22 20:2x · правки судьи, круг 1: команда с string.format('… %s') остаётся, «funcs %s: %d» отсеян (искусственный дамп); пустой стек даёт «-»;
# `--game` без значения и N не числом печатают подсказку, код 2]
import hashlib
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

REMOTE_CMD = re.compile(rb"(?:^|[^\x20-\x7e])((?:lua|call|exec|dump|find|props|funcs|hide|collapse) [\x20-\x7e]{4,400})")
FRAME = re.compile(r"^\s*(\S+) 0x[0-9a-fA-F]+ \+ ([0-9a-fA-F]+)\s*$")
FORMAT_CONST = re.compile(r"\w+ %[sd]")


def stack_of(xml_text):
    """The <PCallStack> as a list of «module+offset» — module base addresses change per run, offsets do not."""
    m = re.search(r"<PCallStack>(.*?)</PCallStack>", xml_text, re.S)
    if not m:
        return []
    out = []
    for line in m.group(1).splitlines():
        f = FRAME.match(line)
        if f:
            out.append(f.group(1) + "+" + f.group(2))
    return out


def exception_of(xml_text):
    m = re.search(r"<ErrorMessage>(.*?)</ErrorMessage>", xml_text, re.S)
    return (m.group(1).strip().splitlines() or [""])[0][:90] if m else "?"


def remote_commands(dmp_path):
    try:
        data = open(dmp_path, "rb").read()
    except OSError:
        return []
    seen = []
    for m in REMOTE_CMD.finditer(data):
        s = m.group(1).decode("ascii", "replace")
        # the remote's own format strings sit in its code memory: a verb followed at once by a format spec («funcs %s: %d», «call %s %s»); a real command
        # may hold %s / %d further on (string.format, Lua patterns — 175 of 1413 commands in done.txt), so only this exact shape is dropped (judge 2026-11-22)
        if FORMAT_CONST.match(s):
            continue
        if s not in seen:
            seen.append(s)
    return seen


def main():
    args = sys.argv[1:]
    game = None
    usage = "usage: crash-forensics.py [N >= 1] [--game <game dir>]"
    if "--game" in args:
        i = args.index("--game")
        if i + 1 >= len(args):
            print(usage)
            return 2
        game = args[i + 1]
        del args[i:i + 2]
    try:
        n = int(args[0]) if args else 10
    except ValueError:
        print(usage)
        return 2
    if n < 1:
        print(usage)
        return 2
    if not game:
        import game_target
        game = game_target.GAME_DIR
    root = os.path.join(game, "ConanSandbox", "Saved", "Crashes")
    if not os.path.isdir(root):
        print("нет папки падений: " + root)
        return 2
    dirs = [os.path.join(root, d) for d in os.listdir(root) if d.startswith("UECC-")]
    dirs.sort(key=os.path.getmtime, reverse=True)
    for d in dirs[:n]:
        xml = os.path.join(d, "CrashContext.runtime-xml")
        if not os.path.isfile(xml):
            continue
        text = open(xml, encoding="utf-8", errors="replace").read()
        st = stack_of(text)
        h = hashlib.md5(" ".join(st).encode()).hexdigest()[:8] if st else "-"   # no frames read → no hash (md5 of "" would join unrelated crashes)
        ue4ss = sum(1 for f in st if f.lower().startswith("ue4ss+"))
        import time
        t = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(os.path.getmtime(xml)))
        print("%s  %s  стек %d кадров (UE4SS %d) хеш %s  %s" % (t, os.path.basename(d)[:22], len(st), ue4ss, h, exception_of(text)))
        for c in remote_commands(os.path.join(d, "UEMinidump.dmp"))[:4]:
            print("    команда пульта в памяти: " + c[:220])
    return 0


if __name__ == "__main__":
    sys.exit(main())
