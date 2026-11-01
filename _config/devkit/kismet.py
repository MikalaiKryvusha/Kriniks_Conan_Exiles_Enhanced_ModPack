# -*- coding: utf-8 -*-
"""kismet.py — разбор байткода блюпринтов UE 5.8 (Kismet) в обычном ассете (.uexp) и удлинение строковых литералов со сдвигом адресов.

Зачем (2026-10-26, KUMM bugs/64 п. 7, план 35 Б0): панель Exiles Fishing держит 9 английских строк прямо в байткоде (`EX_StringConst`,
«Fishing Power: », «Min FP » …). `.locres` их не видит, а русский длиннее английского: строка удлиняется — сдвигаются абсолютные адреса
переходов функции. Выбор владельца из трёх путей: `[OWNER]` «Свой пересчёт байткода» · 2026-10-26.

Как устроено (UE 5.x, `ScriptSerialization.h`): в файле функция хранит два числа — размер байткода В ПАМЯТИ и размер НА ДИСКЕ, затем сам
байткод. Ссылки на объекты в памяти 8 байт, на диске 4 (индекс пакета); имя FName в памяти 12 байт (FScriptName), на диске 8; ссылка на
свойство в памяти 8 байт, на диске — путь FFieldPath (число имён, имена, владелец). Адреса переходов — смещения В ПАМЯТИ.
Самопроверка разбора: подсчитанный размер в памяти обязан совпасть с числом из заголовка, а разбор — кончиться ровно на EX_EndOfScript.

    python -I -X utf8 kismet.py check  <ассет.uasset> <exports.tsv>            # разобрать все функции, сверить размеры
    python -I -X utf8 kismet.py lits   <ассет.uasset> <exports.tsv>            # литералы EX_StringConst по функциям
Строки `lit:<английский>\t<русский>` в таблице `patch-mod-asset.py build` идут сюда (русское — в кавычках, если кончается пробелом).
[TESTED: 2026-10-26 · разбор: 190 функций 7 ассетов (рыбалка, Hosav, EAA, включая графы событий) — размер в памяти = заголовку у всех;
 замена: 12 строк Exiles Fishing, все функции после замены снова сходятся; в игре панель по-русски, без падения, кадр 13:13 —
 KUMM/testcases/reports/2026-10-26_conan-fishing-bytecode-literals.md]
"""
import struct
import sys

NAME_DISK, NAME_MEM = 8, 12
PTR_DISK, PTR_MEM = 4, 8


class Bad(Exception):
    pass


class Walker:
    """Один проход по байткоду функции: позиции на диске и в памяти, места полей со смещениями кода, литералы."""

    def __init__(self, data):
        self.d = data
        self.p = 0          # позиция на диске (в data)
        self.m = 0          # позиция в памяти
        self.jumps = []     # (disk_pos поля u32, вид) — абсолютные адреса в памяти
        self.skips = []     # (disk_pos поля u32, mem_start, mem_end) — относительные размеры (EX_Context, EX_Skip)
        self.lits = []      # (disk_pos, mem_pos, текст, disk_len) — EX_StringConst
        self.dbls = []      # (disk_pos значения, число) — EX_DoubleConst
        self.flts = []      # (disk_pos значения, число) — EX_FloatConst
        self.ints = []      # (disk_pos значения, число) — EX_IntConst (правка `int:`, 2026-10-30: делитель «k» Hosav, план 36 W5c)
        self.bools = []     # (disk_pos токена, True|False) — EX_True / EX_False по порядку в функции (правка `bool:`, 2026-10-29)
        self.ops = 0

    # ── примитивы ──
    def take(self, n_disk, n_mem=None):
        if self.p + n_disk > len(self.d):
            raise Bad(f"конец данных на {self.p}")
        self.p += n_disk
        self.m += n_disk if n_mem is None else n_mem

    def u8(self):
        v = self.d[self.p]
        self.take(1)
        return v

    def u16(self):
        v = struct.unpack_from('<H', self.d, self.p)[0]
        self.take(2)
        return v

    def u32(self):
        v = struct.unpack_from('<I', self.d, self.p)[0]
        self.take(4)
        return v

    def i32(self):
        v = struct.unpack_from('<i', self.d, self.p)[0]
        self.take(4)
        return v

    def name(self):
        self.take(NAME_DISK, NAME_MEM)

    def obj(self):
        self.take(PTR_DISK, PTR_MEM)

    def prop(self):
        # FFieldPath: TArray<FName> + владелец (индекс пакета); в памяти — указатель FField*
        p0 = self.p
        n = struct.unpack_from('<i', self.d, self.p)[0]
        if n < 0 or n > 16:
            raise Bad(f"FFieldPath: число имён {n} на {self.p}")
        self.p += 4 + n * NAME_DISK + 4
        if self.p > len(self.d):
            raise Bad("FFieldPath за концом")
        self.m += PTR_MEM
        return p0

    def code_offset(self, kind):
        self.jumps.append((self.p, kind))
        return self.u32()

    def zstr(self):
        e = self.d.index(b'\x00', self.p)
        s = self.d[self.p:e]
        self.take(e - self.p + 1)
        return s

    def wstr(self):
        q = self.p
        while True:
            if q + 2 > len(self.d):
                raise Bad("UTF-16 строка за концом")
            if self.d[q] == 0 and self.d[q + 1] == 0:
                break
            q += 2
        s = self.d[self.p:q]
        self.take(q - self.p + 2)
        return s

    def until(self, end_tok):
        while True:
            if self.expr() == end_tok:
                return

    # ── выражение ──
    def expr(self):
        start_p, start_m = self.p, self.m
        t = self.u8()
        self.ops += 1
        if t in (0x00, 0x01, 0x02, 0x48, 0x33, 0x6C):          # Local/Instance/Default/LocalOut variable, PropertyConst, ClassSparseData
            self.prop()
        elif t == 0x04:                                         # Return
            self.expr()
        elif t == 0x06:                                         # Jump
            self.code_offset('Jump')
        elif t == 0x07:                                         # JumpIfNot
            self.code_offset('JumpIfNot'); self.expr()
        elif t == 0x09:                                         # Assert
            self.u16(); self.u8(); self.expr()
        elif t in (0x27, 0x28):                                 # True, False — место токена для правки `bool:` (кнопка Hosav закрывала хаб)
            self.bools.append((start_p, t == 0x27))
        elif t in (0x0B, 0x15, 0x16, 0x17, 0x25, 0x26, 0x2A, 0x2D, 0x30, 0x32, 0x3A, 0x3C, 0x3E, 0x40, 0x4D,
                   0x50, 0x53, 0x5A, 0x5E, 0x66):
            pass                                                # без данных
        elif t == 0x0C:                                         # NothingInt32
            self.i32()
        elif t == 0x0F:                                         # Let
            self.prop(); self.expr(); self.expr()
        elif t == 0x11:                                         # BitFieldConst
            self.prop(); self.u8()
        elif t in (0x13, 0x2E, 0x52, 0x54, 0x55):               # MetaCast, DynamicCast, ObjToInterface, CrossInterface, InterfaceToObj
            self.obj(); self.expr()
        elif t in (0x14, 0x43, 0x44, 0x5C, 0x5F, 0x60, 0x62, 0x6B):   # LetBool, LetMulticast, LetDelegate, AddMulticast, LetObj, LetWeak, Remove, ArrayGetByRef
            self.expr(); self.expr()
        elif t == 0x18:                                         # Skip
            pos = self.p; self.u32()
            s = self.m; self.expr(); self.skips.append((pos, s, self.m))
        elif t in (0x12, 0x19, 0x1A):                           # ClassContext, Context, Context_FailSilent
            self.expr()
            pos = self.p; self.u32()
            self.prop()
            s = self.m; self.expr(); self.skips.append((pos, s, self.m))
        elif t in (0x1B, 0x45):                                 # VirtualFunction, LocalVirtualFunction
            self.name(); self.until(0x16)
        elif t in (0x1C, 0x46, 0x63, 0x68):                     # FinalFunction, LocalFinalFunction, CallMulticastDelegate, CallMath
            self.obj(); self.until(0x16)
        elif t == 0x1D:                                         # IntConst — место значения для правки `int:`
            self.ints.append((self.p, struct.unpack_from('<i', self.d, self.p)[0]))
            self.i32()
        elif t == 0x1E:                                         # FloatConst — место значения для правки `flt:` (таймер Hosav, bugs/64 п. 16)
            self.flts.append((self.p, struct.unpack_from('<f', self.d, self.p)[0]))
            self.take(4)
        elif t == 0x1F:                                         # StringConst
            s = self.zstr()
            self.lits.append((start_p, start_m, s.decode('latin1'), self.p - start_p))
        elif t == 0x20:
            self.obj()
        elif t == 0x21:
            self.name()
        elif t in (0x22, 0x23):                                 # Rotation, Vector — 3 double
            self.take(24)
        elif t in (0x24, 0x2C):                                 # ByteConst, IntConstByte
            self.u8()
        elif t == 0x29:                                         # TextConst
            k = self.u8()
            if k == 0:
                pass
            elif k == 1:
                self.expr(); self.expr(); self.expr()
            elif k in (2, 3):
                self.expr()
            elif k == 4 and self.d[self.p] in (0x1F, 0x34):
                # В 5.8 вид 4 встречается с одной строкой следом (BPC_EFT_Tuning.ProfSlotText: «— empty —», 2026-10-26); прочтение
                # «таблица строк + две строки» там не сходится по размеру. Какой вид верен — решает сверка размера с заголовком.
                self.expr()
            elif k == 4:
                self.obj(); self.expr(); self.expr()
            else:
                raise Bad(f"TextConst вид {k} на {start_p}")
        elif t == 0x2B:                                         # TransformConst — кватернион 4 double + 2 × 3 double
            self.take(80)
        elif t == 0x2F:                                         # StructConst
            self.obj(); self.i32(); self.until(0x30)
        elif t == 0x31:                                         # SetArray
            self.expr(); self.until(0x32)
        elif t == 0x34:                                         # UnicodeStringConst (« — empty — » профилей рыбалки)
            s = self.wstr()
            self.lits.append((start_p, start_m, s.decode('utf-16-le'), self.p - start_p))
        elif t in (0x35, 0x36, 0x37):
            if t == 0x37:                                       # DoubleConst — место значения для правки `dbl:` (миникарта, bugs/64 п. 19)
                self.dbls.append((self.p, struct.unpack_from('<d', self.d, self.p)[0]))
            self.take(8)
        elif t == 0x38:                                         # Cast
            self.u8(); self.expr()
        elif t == 0x39:                                         # SetSet
            self.expr(); self.i32(); self.until(0x3A)
        elif t == 0x3B:                                         # SetMap
            self.expr(); self.i32(); self.until(0x3C)
        elif t == 0x3D:                                         # SetConst
            self.prop(); self.i32(); self.until(0x3E)
        elif t == 0x3F:                                         # MapConst
            self.prop(); self.prop(); self.i32(); self.until(0x40)
        elif t == 0x41:                                         # Vector3fConst
            self.take(12)
        elif t in (0x42, 0x64):                                 # StructMemberContext, LetValueOnPersistentFrame
            self.prop(); self.expr()
        elif t == 0x4B:                                         # InstanceDelegate
            self.name()
        elif t == 0x4C:                                         # PushExecutionFlow
            self.code_offset('PushExecutionFlow')
        elif t in (0x4E, 0x4F, 0x51, 0x5D, 0x67, 0x6D):         # ComputedJump, PopIfNot, InterfaceContext, ClearMulticast, SoftObject, FieldPath
            self.expr()
        elif t == 0x5B:                                         # SkipOffsetConst
            self.code_offset('SkipOffsetConst')
        elif t == 0x61:                                         # BindDelegate
            self.name(); self.expr(); self.expr()
        elif t == 0x65:                                         # ArrayConst
            self.prop(); self.i32(); self.until(0x66)
        elif t == 0x69:                                         # SwitchValue
            n = self.u16()
            self.code_offset('SwitchEnd')
            self.expr()
            for _ in range(n):
                self.expr(); self.code_offset('SwitchNext'); self.expr()
            self.expr()
        elif t == 0x6A:                                         # InstrumentationEvent
            k = self.u8()
            if k == 4:
                self.name()
        else:
            raise Bad(f"неизвестный код 0x{t:02X} на {start_p}")
        return t

    def run(self):
        while self.p < len(self.d):
            if self.expr() == 0x53 and self.p == len(self.d):
                return
        raise Bad("нет EX_EndOfScript в конце")


def find_scripts(blob, start, end):
    """Байткоды внутри экспорта [start, end): (поз. заголовка, размер в памяти, размер на диске, Walker). Признак — два int32
    (память, диск), за ними ровно «диск» байт, последний — EX_EndOfScript, разбор сходится и размер в памяти совпал."""
    out = []
    i = start
    while i + 8 <= end:
        mem, disk = struct.unpack_from('<ii', blob, i)
        if 0 < disk <= end - i - 8 and mem > 0 and blob[i + 8 + disk - 1] == 0x53:
            w = Walker(blob[i + 8:i + 8 + disk])
            try:
                w.run()
                if w.m == mem:
                    out.append((i, mem, disk, w))
                    i += 8 + disk
                    continue
            except (Bad, ValueError, IndexError, struct.error):
                pass
        i += 1
    return out


def patch_script(script, mem, repl):
    """Заменить строковые литералы по таблице {английский str: русский str} на EX_UnicodeStringConst.
    Возвращает (новый байткод, новый размер в памяти, список замен). Строка в байткоде лежит целиком и в памяти, и на диске, поэтому
    сдвиг одинаков: абсолютные адреса переходов дальше замены растут на сумму сдвигов до них, относительные пропуски (EX_Context,
    EX_Skip) — на сдвиги внутри своего выражения."""
    w = Walker(script)
    w.run()
    edits, done = [], []                        # edits: (disk_pos, mem_pos, old_len, new_bytes)
    for p, m, s, n in w.lits:
        if s in repl:
            nb = b'\x34' + repl[s].encode('utf-16-le') + b'\x00\x00'
            edits.append((p, m, n, nb))
            done.append((m, s, repl[s]))
    if not edits:
        return script, mem, []
    buf = bytearray(script)
    for pos, _kind in w.jumps:
        old = struct.unpack_from('<I', buf, pos)[0]
        struct.pack_into('<I', buf, pos, old + sum(len(nb) - n for _, m, n, nb in edits if m < old))
    for pos, s, e in w.skips:
        old = struct.unpack_from('<I', buf, pos)[0]
        struct.pack_into('<I', buf, pos, old + sum(len(nb) - n for _, m, n, nb in edits if s <= m < e))
    for p, m, n, nb in sorted(edits, reverse=True):
        buf[p:p + n] = nb
    delta = sum(len(nb) - n for _, _, n, nb in edits)
    out = bytes(buf)
    # Самопроверка: новый байткод разбирается целиком, размер в памяти = старый + сдвиг, литералов-оригиналов не осталось
    w2 = Walker(out)
    w2.run()
    if w2.m != mem + delta:
        raise Bad(f"после замены размер в памяти {w2.m} ≠ {mem + delta}")
    if any(s in repl for _, _, s, _ in w2.lits):
        raise Bad("после замены остался английский литерал")
    return out, mem + delta, done


def patch_uexp(blob, rows, repl):
    """Все функции ассета: rows — [(смещение, размер, вид, имя)] в порядке экспортов. Возвращает (новый .uexp, новые rows, отчёт).
    Граф событий (ExecuteUbergraph_*) не правится: на его адреса ссылаются другие функции (точки входа)."""
    out = bytearray()
    new_rows, report = [], []
    cur = 0
    for off, size, kind, name in sorted(rows, key=lambda r: r[0]):
        out += blob[cur:off]
        chunk = blob[off:off + size]
        if kind == 'RawExport':
            parts, last = [], 0
            for hdr, mem, disk, w in find_scripts(blob, off, off + size):
                if not any(s in repl for _, _, s, _ in w.lits):
                    continue
                if name.startswith('ExecuteUbergraph'):
                    raise Bad(f"{name}: литерал в графе событий — правка не поддержана")
                script = blob[hdr + 8:hdr + 8 + disk]
                new, new_mem, done = patch_script(script, mem, repl)
                d = len(new) - disk
                rel = hdr - off
                parts.append(chunk[last:rel] + struct.pack('<ii', new_mem, disk + d) + new)
                last = rel + 8 + disk
                report += [(name, m, en, ru) for m, en, ru in done]
            if parts:
                chunk = b''.join(parts) + chunk[last:]
        new_rows.append((len(out), len(chunk), kind, name))
        out += chunk
        cur = off + size
    out += blob[cur:]
    by_old = dict(zip([r[0] for r in sorted(rows, key=lambda r: r[0])], new_rows))
    return bytes(out), [by_old[r[0]] for r in rows], report


def load(ua, exports_tsv):
    blob = open(ua[:-7] + '.uexp', 'rb').read()
    rows = []
    for line in open(exports_tsv, encoding='utf-8'):
        if line.strip():
            off, size, kind, name = line.rstrip('\n').split('\t', 3)
            rows.append((int(off), int(size), kind, name))
    return blob, rows


def main():
    cmd, ua, ex = sys.argv[1:4]
    blob, rows = load(ua, ex)
    found = total = 0
    for off, size, kind, name in rows:
        if kind != 'RawExport':
            continue
        sc = find_scripts(blob, off, off + size)
        total += 1
        if sc:
            found += 1
        for hdr, mem, disk, w in sc:
            if cmd == 'check':
                print(f"{name}\tкод на диске {disk}, в памяти {mem} = разбор {w.m}\tвыражений {w.ops}\tпереходов {len(w.jumps)}\tпропусков {len(w.skips)}")
            elif cmd == 'lits':
                for p, m, s, n in w.lits:
                    print(f"{name}\t{m}\t{s.decode('latin1')!r}")
    print(f"экспортов-структур {total}, с найденным байткодом {found}", file=sys.stderr)


if __name__ == '__main__':
    main()
