# ini-temp.py add <Engine.ini> <метка> <имя=значение>… | revert <Engine.ini> <метка> | list <Engine.ini>
# Временные переменные в разделе [SystemSettings] развёрнутого Engine.ini игры — для замеров, которые игра читает только при старте
# (s.AsyncPostLoadEnabled, p.Chaos.EnableAsyncInitBody, LevelStreaming.Profiling.*).
# Зачем: 2026-10-26 профайлер подгрузки ставился одноразовым скриптом в черновике и откатывался копией руками; очередь владельца
# («Замеры ручек подгрузки … Ветка появления NPC») — ещё три таких запуска. Прибор держит копию до правки (<ini>.bak-<метка>),
# помечает свои строки комментарием «; KUMM-TEMP <метка>» и на revert возвращает файл из копии побайтно, сверяя, что кроме своих строк
# в файле ничего не менялось (иначе отказ — игра могла переписать ini, и слепой откат потерял бы её правку).
# Переводы строк файла сохраняются (CRLF у игры).
# [TESTED: 2026-11-09 · копия Engine.ini игры в черновике: откат по метке — sha256 тот же; метка выкинута (как делает игра на выходе) —
#  откат по своим строкам, sha256 тот же; метка выкинута + чужая строка — отказ, код 1. На игре 2026-11-09 19:29: после запуска L4 игра
#  выкинула метку — «откат … по своим строкам», sha256 E337D3FD… = до добавления.]
import os, sys

def nl_of(raw):
    return "\r\n" if b"\r\n" in raw else "\n"

def add(path, tag, pairs):
    raw = open(path, "rb").read()
    bak = path + ".bak-" + tag
    if os.path.exists(bak):
        sys.exit("уже есть копия %s — сначала revert" % bak)
    open(bak, "wb").write(raw)
    nl = nl_of(raw)
    s = raw.decode("utf-8-sig")
    head = "[SystemSettings]" + nl
    if head not in s:
        sys.exit("нет раздела [SystemSettings]")
    # число своих строк — в метке: откат пропускает ровно их (иначе спутает со следующей настоящей строкой «имя=значение»)
    block = "; KUMM-TEMP %s %d" % (tag, len(pairs)) + nl + "".join(p + nl for p in pairs)
    s = s.replace(head, head + block, 1)
    open(path, "wb").write(s.encode("utf-8"))
    # Свои строки — ещё и в файле рядом с копией: игра на выходе ВЫКИДЫВАЕТ комментарий-метку, а строку «имя=значение» оставляет
    # (KUMM, серия quick wins 2026-11-09 19:17 — revert отказал, diff показал ровно одну нашу строку без метки)
    open(bak + ".pairs", "w", encoding="utf-8").write("\n".join(pairs))
    print("добавлено %d строк, копия %s" % (len(pairs), bak))

def revert(path, tag):
    bak = path + ".bak-" + tag
    if not os.path.exists(bak):
        sys.exit("нет копии %s" % bak)
    cur = open(path, "rb").read()
    orig = open(bak, "rb").read()
    nl = nl_of(orig)
    lines = cur.decode("utf-8-sig").split(nl)
    out, skip = [], 0
    for ln in lines:
        if skip > 0:
            skip -= 1; continue
        if ln.startswith("; KUMM-TEMP " + tag + " "):
            skip = int(ln.rsplit(" ", 1)[1]); continue
        out.append(ln)
    want = orig.decode("utf-8-sig").encode("utf-8")
    how = "по метке"
    if nl.join(out).encode("utf-8") != want and os.path.exists(bak + ".pairs"):
        # метку игра выкинула — убираем по одному вхождению каждой своей строки из файла-спутника
        pairs = [p for p in open(bak + ".pairs", encoding="utf-8").read().split("\n") if p]
        out = list(out)
        for p in pairs:
            if p in out:
                out.remove(p)
        how = "по своим строкам (метку игра выкинула)"
    if nl.join(out).encode("utf-8") != want:
        sys.exit("кроме своих строк файл изменился (игра переписала ini?) — откат вслепую не делаю; сравни %s и %s" % (path, bak))
    open(path, "wb").write(orig)
    os.remove(bak)
    if os.path.exists(bak + ".pairs"):
        os.remove(bak + ".pairs")
    print("откат из копии %s, копия удалена" % how)

def list_(path):
    for i, ln in enumerate(open(path, encoding="utf-8-sig").read().splitlines(), 1):
        if "KUMM-TEMP" in ln:
            print(i, ln)

if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "add" and len(a) >= 4: add(a[1], a[2], a[3:])
    elif a and a[0] == "revert" and len(a) == 3: revert(a[1], a[2])
    elif a and a[0] == "list" and len(a) == 2: list_(a[1])
    else: sys.exit(__doc__ or "usage: add|revert|list")
