# -*- coding: utf-8 -*-
"""kismet-graft.py — пересадить правку одного мода в функцию блюпринта ДРУГОГО мода, когда оба везут один и тот же ванильный ассет целиком.

Зачем (2026-11-06, KUMM план 45 шаг 8a, интервью #034 Q2): Bosses My New Besties и Less Building Placement Restrictions оба везут
`/Game/Systems/Thrall/BP_ThrallSystemComponent`; игра берёт файл LBPR (он ниже в списке), и правка BMNB в `ShowThrallPlaceable` (призрак
мини-босса и мирового босса — в росте 1.2) пропадает. `[OWNER]` «если получится, то в LBPR нужно затянуть модельки из Bosses My New Besties»
· 2026-11-06 13:34. Пересадка нативная (HOUSE_RULES правило 8): байткод функции копии LBPR получает операторы BMNB, ничего больше.

Как (три версии одной функции — игра V, донор D, приёмник R):
  1. Операторы верхнего уровня каждой версии сравниваются ПО СМЫСЛУ: имена, ссылки на объекты и на свойства в байтах заменены их строками
     (индексы у трёх ассетов разные). D против V даёт правку донора (вставки и замены операторов), R против V — где те же операторы у
     приёмника. Правка ложится только туда, где приёмник равен игре; иначе — остановка.
  2. Операторы донора переписываются под таблицы приёмника: имена (недостающие — в конец таблицы имён), объекты (недостающие импорты —
     цепочкой в конец), владелец ссылки на свойство (функция донора → функция приёмника).
  3. Абсолютные адреса переходов приёмника (EX_Jump, JumpIfNot, PushExecutionFlow, SkipOffsetConst, SwitchValue) сдвигаются на длину вставок
     в памяти ДО адреса. Переход ровно на место вставки — остановка (неясно, куда он должен вести).
  4. Локальные переменные донора, которых нет у приёмника, дописываются в конец списка свойств функции (формат UE 5.8 — по байтам:
     тип, имя, 27 байт полей, хвост по типу), счётчик растёт.
  5. Файлы: <out>/BP_….bin (новые байты экспорта) и <out>/rawput.tsv для `uaj rawput`; самопроверка — новый байткод разбирается целиком,
     его размер в памяти = старый + сумма вставок, и операторы результата по смыслу = операторы приёмника с правкой донора.

    python -I -X utf8 kismet-graft.py <V.uasset> <D.uasset> <R.uasset> <функция> <out-папка>
Рядом с каждым .uasset — .uexp, <имя>.exports.tsv (`uaj exports`) и <имя>.json (UAssetGUI tojson), их пути — тот же стем.
[NOT-TESTED]
"""
import difflib
import json
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kismet  # noqa: E402

FFIELD_BASE = 43          # тип(8) + имя(8) + 27 байт полей FProperty в UE 5.8 (замер 2026-11-06 по 45 свойствам ShowThrallPlaceable)
REPNOTIFY_AT = 34         # смещение имени RepNotifyFunc внутри записи
FFIELD_TAIL = {'BoolProperty': 6, 'StructProperty': 4, 'ObjectProperty': 4, 'InterfaceProperty': 4,
               'FloatProperty': 0, 'DoubleProperty': 0, 'IntProperty': 0}
TAIL_HAS_INDEX = {'StructProperty', 'ObjectProperty', 'InterfaceProperty'}


class Stop(Exception):
    pass


class Rec(kismet.Walker):
    """Walker, который помнит места имён, объектов и ссылок на свойства и границы операторов верхнего уровня."""

    def __init__(self, data):
        super().__init__(data)
        self.f_names, self.f_objs, self.f_props = [], [], []
        self.stmts = []            # (disk_start, mem_start, disk_end, mem_end)

    def name(self):
        self.f_names.append(self.p)
        super().name()

    def obj(self):
        self.f_objs.append(self.p)
        super().obj()

    def prop(self):
        self.f_props.append(self.p)
        return super().prop()

    def run(self):
        while self.p < len(self.d):
            p0, m0 = self.p, self.m
            self.tops.append(self.m)
            t = self.expr()
            self.stmts.append((p0, m0, self.p, self.m))
            if t == 0x53 and self.p == len(self.d):
                return
        raise kismet.Bad("нет EX_EndOfScript в конце")


class Asset:
    def __init__(self, ua, fn):
        stem = ua[:-7]
        self.ua = ua
        self.blob = open(stem + '.uexp', 'rb').read()
        self.rows = [l.rstrip('\n').split('\t') for l in open(stem + '.exports.tsv', encoding='utf-8') if l.strip()]
        js = json.load(open(stem + '.json', encoding='utf-8'))
        self.names = list(js['NameMap'])
        self.imports = js['Imports']
        self.export_names = [r[3] for r in self.rows]
        hits = [i for i, r in enumerate(self.rows) if r[3] == fn]
        if len(hits) != 1:
            raise Stop(f"{ua}: функций «{fn}» {len(hits)}")
        self.fidx = hits[0] + 1                              # индекс пакета экспорта функции
        self.off, self.size = int(self.rows[hits[0]][0]), int(self.rows[hits[0]][1])
        sc = kismet.find_scripts(self.blob, self.off, self.off + self.size)
        if len(sc) != 1:
            raise Stop(f"{ua}: байткодов в функции {len(sc)}")
        self.hdr, self.mem, self.disk, _ = sc[0]
        self.data = self.blob[self.off:self.off + self.size]
        self.hrel = self.hdr - self.off
        self.script = self.blob[self.hdr + 8:self.hdr + 8 + self.disk]
        self.w = Rec(self.script)
        self.w.run()
        self.read_ffields()

    # ── имена и объекты ──
    def fname(self, buf, p):
        i, n = struct.unpack_from('<II', buf, p)
        return (self.names[i], n)

    def obj_path(self, idx):
        if idx == 0:
            return ('null',)
        if idx > 0:
            return ('export', self.export_names[idx - 1])
        out = []
        i = idx
        while i < 0:
            e = self.imports[-i - 1]
            out.append((e['ClassPackage'], e['ClassName'], e['ObjectName']))
            i = e['OuterIndex']
        return ('import',) + tuple(reversed(out))

    # ── свойства функции (FField, UE 5.8) ──
    def read_ffields(self):
        d = self.data
        # Счётчик стоит перед первой записью; первая запись — имя типа «…Property». Ищем с начала данных экспорта.
        for p in range(0, self.hrel - 20):
            cnt = struct.unpack_from('<i', d, p)[0]
            if not 0 < cnt < 500:
                continue
            try:
                t, n = self.fname(d, p + 4)
            except IndexError:
                continue
            if n == 0 and t.endswith('Property'):
                q, fields = p + 4, []
                ok = True
                for _ in range(cnt):
                    q2 = self.ffield_end(q)
                    if q2 is None:
                        ok = False
                        break
                    fields.append((q, q2))
                    q = q2
                if ok and q == self.hrel:
                    self.cnt_pos, self.ffields = p, fields
                    return
        raise Stop(f"{self.ua}: список свойств функции не найден")

    def ffield_end(self, q):
        d = self.data
        if q + 16 > self.hrel:
            return None
        try:
            t, n = self.fname(d, q)
        except IndexError:
            return None
        if n != 0 or not t.endswith('Property'):
            return None
        if t == 'ArrayProperty':
            return self.ffield_end(q + FFIELD_BASE)
        if t not in FFIELD_TAIL:
            raise Stop(f"{self.ua}: тип свойства {t} — хвост не знаю")
        return q + FFIELD_BASE + FFIELD_TAIL[t]

    def ffield_name(self, q):
        return self.fname(self.data, q + 8)


def sig(a, s):
    """Смысл оператора: байты с именами, объектами и ссылками на свойства, заменёнными строками."""
    p0, _, p1, _ = s
    out, p = [], p0
    # адреса переходов абсолютные и у трёх версий разные — в смысл не входят (их соответствие проверяет main по операторам)
    marks = sorted([(x, 'n') for x in a.w.f_names if p0 <= x < p1] + [(x, 'o') for x in a.w.f_objs if p0 <= x < p1]
                   + [(x, 'p') for x in a.w.f_props if p0 <= x < p1] + [(x, 'j') for x, _ in a.w.jumps if p0 <= x < p1])
    for x, k in marks:
        out.append(a.script[p:x])
        if k == 'j':
            out.append(b'<J>'); p = x + 4
        elif k == 'n':
            out.append(repr(a.fname(a.script, x)).encode()); p = x + 8
        elif k == 'o':
            out.append(repr(a.obj_path(struct.unpack_from('<i', a.script, x)[0])).encode()); p = x + 4
        else:
            n = struct.unpack_from('<i', a.script, x)[0]
            nm = [a.fname(a.script, x + 4 + 8 * i) for i in range(n)]
            own = struct.unpack_from('<i', a.script, x + 4 + 8 * n)[0]
            own_s = 'SELF' if own == a.fidx else a.obj_path(own)
            out.append(repr((nm, own_s)).encode()); p = x + 4 + 8 * n + 4
    out.append(a.script[p:p1])
    return b''.join(out)


class Remap:
    """Таблицы приёмника и то, что в них надо дописать."""

    def __init__(self, r):
        self.r = r
        self.names = list(r.names)
        self.name_idx = {}
        for i, s in enumerate(self.names):
            self.name_idx.setdefault(s, i)
        self.new_names = []
        self.imports = list(r.imports)
        self.new_imports = []

    def name(self, s):
        if s not in self.name_idx:
            self.name_idx[s] = len(self.names)
            self.names.append(s)
            self.new_names.append(s)
        return self.name_idx[s]

    def import_of(self, chain):
        """chain — ((ClassPackage, ClassName, ObjectName) от внешнего к внутреннему); вернуть индекс пакета приёмника, дописав недостающее."""
        outer = 0
        for cp, cn, on in chain:
            found = None
            for i, e in enumerate(self.imports):
                if e['ObjectName'] == on and e['OuterIndex'] == outer and e['ClassName'] == cn and e['ClassPackage'] == cp:
                    found = -(i + 1)
                    break
            if found is None:
                for s in (cp, cn, on):
                    self.name(s)
                self.imports.append({'ObjectName': on, 'OuterIndex': outer, 'ClassPackage': cp, 'ClassName': cn})
                self.new_imports.append((cp, cn, outer, on))
                found = -len(self.imports)
            outer = found
        return outer

    def obj(self, d, idx):
        path = d.obj_path(idx)
        if path[0] == 'null':
            return 0
        if path[0] == 'export':
            hits = [i for i, n in enumerate(self.r.export_names) if n == path[1]]
            if len(hits) != 1:
                raise Stop(f"экспорт донора «{path[1]}» у приёмника найден {len(hits)} раз")
            return hits[0] + 1
        return self.import_of(path[1:])


def rewrite(d, s, rm, buf_from=None):
    """Байты оператора донора s под таблицы приёмника."""
    p0, _, p1, _ = s
    seg = bytearray(d.script[p0:p1])
    for x in d.w.f_names:
        if p0 <= x < p1:
            nm, n = d.fname(d.script, x)
            struct.pack_into('<II', seg, x - p0, rm.name(nm), n)
    for x in d.w.f_objs:
        if p0 <= x < p1:
            struct.pack_into('<i', seg, x - p0, rm.obj(d, struct.unpack_from('<i', d.script, x)[0]))
    for x in d.w.f_props:
        if p0 <= x < p1:
            n = struct.unpack_from('<i', d.script, x)[0]
            for i in range(n):
                nm, num = d.fname(d.script, x + 4 + 8 * i)
                struct.pack_into('<II', seg, x - p0 + 4 + 8 * i, rm.name(nm), num)
            own = struct.unpack_from('<i', d.script, x + 4 + 8 * n)[0]
            struct.pack_into('<i', seg, x - p0 + 4 + 8 * n, rm.r.fidx if own == d.fidx else rm.obj(d, own))
    for x, _k in d.w.jumps:
        if p0 <= x < p1:
            raise Stop(f"в пересаживаемом операторе донора есть переход (диск {x}) — пересчёт адресов внутри вставки не написан")
    return bytes(seg)


def local_refs(d, s):
    """Имена локальных переменных функции донора, на которые ссылается оператор."""
    p0, _, p1, _ = s
    out = set()
    for x in d.w.f_props:
        if p0 <= x < p1:
            n = struct.unpack_from('<i', d.script, x)[0]
            own = struct.unpack_from('<i', d.script, x + 4 + 8 * n)[0]
            if own == d.fidx and n == 1:
                out.add(d.fname(d.script, x + 4))
    return out


def graft(v_ua, d_ua, r_ua, fn, out):
    """Пересадка; возвращает путь к rawput.tsv (строки для `uaj rawput`). Остановка — исключение Stop / kismet.Bad."""
    V, D, R = Asset(v_ua, fn), Asset(d_ua, fn), Asset(r_ua, fn)
    vs = [sig(V, s) for s in V.w.stmts]
    ds = [sig(D, s) for s in D.w.stmts]
    rs = [sig(R, s) for s in R.w.stmts]
    # где приёмник равен игре: индекс оператора игры → индекс оператора приёмника
    v2r = {}
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, vs, rs, autojunk=False).get_opcodes():
        if tag == 'equal':
            for k in range(i2 - i1):
                v2r[i1 + k] = j1 + k
    edits = []      # (индекс оператора приёмника, сколько заменить, [операторы донора])
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, vs, ds, autojunk=False).get_opcodes():
        if tag == 'equal':
            continue
        if tag == 'delete':
            raise Stop(f"донор УБРАЛ операторы игры {i1}..{i2} — удаление не пересаживаю")
        if any(k not in v2r for k in range(i1, i2)) or (i1 not in v2r):
            raise Stop(f"правка донора у операторов игры {i1}..{i2} ложится туда, где приёмник уже не равен игре")
        r_at = v2r[i1]
        if i2 > i1 and [v2r[k] for k in range(i1, i2)] != list(range(r_at, r_at + i2 - i1)):
            raise Stop("операторы приёмника под заменой идут не подряд")
        edits.append((r_at, i2 - i1, list(range(j1, j2)), tag))
    print(f"операторов: игра {len(vs)}, донор {len(ds)}, приёмник {len(rs)}; правок донора {len(edits)}:",
          ', '.join(f"{t} у оператора приёмника {a} (−{n} +{len(js)})" for a, n, js, t in edits))
    rm = Remap(R)
    # Новый байткод приёмника: операторы приёмника по порядку, правки донора на своих местах. Для каждого СОХРАНЁННОГО оператора
    # приёмника — его новое начало на диске и в памяти; адрес перехода = новое начало оператора, в который он ведёт, + смещение внутри.
    new_code, edit_at = bytearray(), {a: (n, js) for a, n, js, _ in edits}
    starts, mem_pos = {}, 0           # оператор приёмника → (новый диск, новая память)
    after_insert = set()              # операторы приёмника, перед которыми вставлен код донора
    k = 0
    while k <= len(R.w.stmts):
        if k in edit_at:
            n, js = edit_at[k]
            for j in js:
                new_code += rewrite(D, D.w.stmts[j], rm)
                mem_pos += D.w.stmts[j][3] - D.w.stmts[j][1]
            if n == 0:
                after_insert.add(k)
            k += n
            if n:
                continue
        if k == len(R.w.stmts):
            break
        s = R.w.stmts[k]
        starts[k] = (len(new_code), mem_pos)
        new_code += R.script[s[0]:s[2]]
        mem_pos += s[3] - s[1]
        k += 1
    new_mem = mem_pos

    def owner_by_mem(t):
        for i, s in enumerate(R.w.stmts):
            if s[1] <= t < s[3]:
                return i
        raise Stop(f"адрес {t} вне кода приёмника")

    for x, kind in R.w.jumps:
        src = [i for i, s in enumerate(R.w.stmts) if s[0] <= x < s[2]][0]
        if src not in starts:
            raise Stop(f"переход приёмника внутри заменённого оператора {src}")
        t = struct.unpack_from('<I', R.script, x)[0]
        dst = owner_by_mem(t)
        if dst not in starts:
            raise Stop(f"переход приёмника ({kind}) ведёт в заменённый оператор {dst}")
        if dst in after_insert and t == R.w.stmts[dst][1]:
            raise Stop(f"переход приёмника ({kind}) ведёт ровно на место вставки, перед оператор {dst} — неясно, на вставку или мимо")
        nt = starts[dst][1] + (t - R.w.stmts[dst][1])
        struct.pack_into('<I', new_code, starts[src][0] + (x - R.w.stmts[src][0]), nt)
    delta_mem = new_mem - R.mem
    # самопроверка разбора
    w2 = Rec(bytes(new_code))
    w2.run()
    if w2.m != new_mem:
        raise Stop(f"новый байткод: размер в памяти {w2.m} ≠ {new_mem}")
    # новые локальные переменные
    need = set()
    for _, _, js, _ in edits:
        for j in js:
            need |= local_refs(D, D.w.stmts[j])
    have = {R.ffield_name(q) for q, _ in R.ffields}
    add = sorted(need - have, key=lambda nm: [i for i, (q, _) in enumerate(D.ffields) if D.ffield_name(q) == nm][0])
    blobs = []
    for nm in add:
        hit = [(q, e) for q, e in D.ffields if D.ffield_name(q) == nm]
        q, e = hit[0]
        b = bytearray(D.data[q:e])
        t, _ = D.fname(D.data, q)
        for at in (0, 8, REPNOTIFY_AT):
            s, n = D.fname(D.data, q + at)
            struct.pack_into('<II', b, at, rm.name(s), n)
        if t in TAIL_HAS_INDEX:
            struct.pack_into('<i', b, FFIELD_BASE, rm.obj(D, struct.unpack_from('<i', D.data, q + FFIELD_BASE)[0]))
        blobs.append(bytes(b))
        print(f"новая переменная: {t} {nm[0]}{'' if nm[1] == 0 else '_' + str(nm[1] - 1)}")
    cnt = struct.unpack_from('<i', R.data, R.cnt_pos)[0]
    data = bytearray(R.data[:R.hrel])
    struct.pack_into('<i', data, R.cnt_pos, cnt + len(blobs))
    data += b''.join(blobs)
    data += struct.pack('<ii', new_mem, len(new_code)) + new_code
    data += R.data[R.hrel + 8 + R.disk:]
    # смысловая самопроверка: операторы результата = операторы приёмника с правкой донора
    os.makedirs(out, exist_ok=True)
    bin_path = os.path.join(out, fn + '.bin')
    open(bin_path, 'wb').write(bytes(data))
    with open(os.path.join(out, 'rawput.tsv'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(f"# kismet-graft.py: {os.path.basename(d_ua)} → {os.path.basename(r_ua)}, функция {fn}\n")
        for s in rm.new_names:
            f.write(f"name\t{s}\n")
        for cp, cn, outer, on in rm.new_imports:
            f.write(f"import\t{cp}\t{cn}\t{outer}\t{on}\n")
        f.write(f"export\t{fn}\t{bin_path}\n")
    print(f"байткод: в памяти {R.mem} → {new_mem}, на диске {R.disk} → {len(new_code)}; свойств {cnt} → {cnt + len(blobs)}; "
          f"имён +{len(rm.new_names)}, импортов +{len(rm.new_imports)}; переходов сдвинуто {len(R.w.jumps)}")
    print(f"→ {bin_path}\n→ {os.path.join(out, 'rawput.tsv')}")
    return os.path.join(out, 'rawput.tsv')


def main():
    graft(*sys.argv[1:6])


if __name__ == '__main__':
    try:
        main()
    except (Stop, kismet.Bad) as e:
        print("ОСТАНОВКА:", e)
        sys.exit(3)
