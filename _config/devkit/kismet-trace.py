# -*- coding: utf-8 -*-
"""kismet-trace.py — чтение байткода ОДНОЙ функции блюпринта UE 5.8 деревом: вызовы с именами, переменные, числа и их места на диске.

Зачем (2026-10-26, KUMM bugs/64 п. 19, план 35 Г7): место миникарты Simple Minimap считает код мода во время игры, отступ слота в ассете
ничего не двигает (EXP-0343). Чтобы поправить константу в функции места, надо её увидеть; UAssetAPI 1.1.0 функции 5.8 не разбирает
(`uaj func` → RawExport), поэтому — свой обход поверх `kismet.Walker` (его самопроверка размера остаётся в силе).

    python -I -X utf8 kismet-trace.py <ассет.uasset> <exports.tsv> <ассет.json> <функция>
<ассет.json> — выгрузка UAssetGUI (`patch-mod-asset.py extract`), из неё имена: таблица имён, импорты, экспорты.
Печать: «смещение байткода на диске · смещение в памяти · глубина · что». Число печатается со смещением своего значения в .uexp —
по нему его меняет `kismet-trace.py` не умеет (только читает); правка — отдельным шагом с тем же размером значения.
[NOT-TESTED]
"""
import importlib.util
import json
import os
import struct
import sys

spec = importlib.util.spec_from_file_location("kismet", os.path.join(os.path.dirname(os.path.abspath(__file__)), "kismet.py"))
kismet = importlib.util.module_from_spec(spec); spec.loader.exec_module(kismet)

OPS = {0x00: 'Local', 0x01: 'Instance', 0x02: 'Default', 0x04: 'Return', 0x06: 'Jump', 0x07: 'JumpIfNot', 0x0B: 'Nothing',
       0x0F: 'Let', 0x14: 'LetBool', 0x16: 'EndFuncParms', 0x18: 'Skip', 0x19: 'Context', 0x1A: 'Context?', 0x1B: 'VirtualCall',
       0x1C: 'FinalCall', 0x1D: 'Int', 0x1E: 'Float', 0x21: 'Name', 0x22: 'Rotation', 0x23: 'Vector', 0x24: 'Byte', 0x25: 'IntZero',
       0x26: 'IntOne', 0x27: 'True', 0x28: 'False', 0x2C: 'IntByte', 0x2F: 'Struct', 0x30: 'EndStruct', 0x37: 'Double',
       0x38: 'Cast', 0x42: 'StructMember', 0x44: 'LetDelegate', 0x45: 'LocalVirtualCall', 0x46: 'LocalFinalCall', 0x48: 'LocalOut',
       0x4C: 'PushFlow', 0x4F: 'PopIfNot', 0x53: 'EndOfScript', 0x5F: 'LetObj', 0x68: 'CallMath'}


class Tracer(kismet.Walker):
    def __init__(self, data, names, imports, exports, base):
        super().__init__(data)
        self.names, self.imports, self.exports, self.base = names, imports, exports, base
        self.depth = 0
        self.out = []
        self.last = None   # подпись последнего прочитанного объекта/имени/свойства — к строке выражения

    def note(self, s):
        self.last = s if self.last is None else self.last + ' ' + s

    def name(self):
        i = struct.unpack_from('<i', self.d, self.p)[0]
        super().name()
        self.note(self.names[i] if 0 <= i < len(self.names) else f'name#{i}')

    def obj(self):
        i = struct.unpack_from('<i', self.d, self.p)[0]
        super().obj()
        if i < 0 and -i - 1 < len(self.imports):
            self.note(self.imports[-i - 1])
        elif 0 < i <= len(self.exports):
            self.note(self.exports[i - 1])
        else:
            self.note(f'obj#{i}')

    def prop(self):
        p0 = self.p
        n = struct.unpack_from('<i', self.d, p0)[0]
        parts = [self.names[struct.unpack_from('<i', self.d, p0 + 4 + k * 8)[0]] for k in range(n)] if 0 <= n <= 16 else []
        r = super().prop()
        self.note('.'.join(parts) or '?')
        return r

    def expr(self):
        t = self.d[self.p]
        pos, mem = self.p, self.m
        val = ''
        if t == 0x1E:
            val = f'{struct.unpack_from("<f", self.d, pos + 1)[0]!r} @uexp+{self.base + pos + 1}'
        elif t == 0x37:
            val = f'{struct.unpack_from("<d", self.d, pos + 1)[0]!r} @uexp+{self.base + pos + 1}'
        elif t == 0x1D:
            val = f'{struct.unpack_from("<i", self.d, pos + 1)[0]} @uexp+{self.base + pos + 1}'
        elif t in (0x24, 0x2C):
            val = f'{self.d[pos + 1]} @uexp+{self.base + pos + 1}'
        line = len(self.out)
        self.out.append(None)
        self.last = None
        self.depth += 1
        self._head_done = False
        # подпись (имя вызова/свойства) читается в начале выражения; сохраняем её после первого чтения
        r = self._expr_with_label(t, line, pos, mem, val)
        self.depth -= 1
        return r

    def _expr_with_label(self, t, line, pos, mem, val):
        depth = self.depth
        holder = {'label': None}
        orig_note = self.note

        def first_note(s):
            if holder['label'] is None:
                holder['label'] = s
            else:
                orig_note(s)
        self.note = first_note
        try:
            r = kismet.Walker.expr(self)
        finally:
            self.note = orig_note
        self.out[line] = f"{pos:6d} {mem:6d} {'  ' * (depth - 1)}{OPS.get(t, hex(t))} {holder['label'] or ''} {val}".rstrip()
        return r


def main():
    ua, ex, js, fn = sys.argv[1:5]
    blob, rows = kismet.load(ua, ex)
    j = json.load(open(js, encoding='utf-8'))
    names = j['NameMap']
    imports = [i['ObjectName'] for i in j['Imports']]
    exports = [e.get('ObjectName', '?') for e in j['Exports']]
    for off, size, kind, name in rows:
        if name != fn:
            continue
        for hdr, mem, disk, w in kismet.find_scripts(blob, off, off + size):
            t = Tracer(blob[hdr + 8:hdr + 8 + disk], names, imports, exports, hdr + 8)
            while t.p < disk:
                t.expr()
            print(f"# {fn}: на диске {disk}, в памяти {mem} = разбор {t.m}")
            print("\n".join(t.out))
        return
    sys.exit(f"нет функции {fn}")


if __name__ == '__main__':
    main()
