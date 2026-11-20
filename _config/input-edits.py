#!/usr/bin/env python3
"""
Правки владельца в привязках клавиш Конана: живой Input.ini против заводского DefaultInput.ini игры.

[TESTED: 2026-11-14 · on the owner's 3.0.1 Input.ini vs the DefaultInput.ini of 3.0.1 and 3.1.0 (byte-identical): exactly six
rows of his — crouch, dodge, heavy attack, three chats; the control run on the default against itself prints 0; the empty file the
game writes on the defaults prints 0. Report KUMM testcases/reports/2026-11-14_conan-owner-keybinds-310.md]

ЗАЧЕМ. При переезде на новую версию игры (KUMM plans/53, шаг 14) нужно знать, какие строки привязок — правки владельца,
а какие — заводские. Сравнение по набору клавиш одного действия ошиблось 2026-11-14: «HideGUI» и «HideGui», «SkipGUI» и
«SKipGUI» выглядели новыми действиями 3.1.0, а это одно имя. Имена действий и клавиш в Unreal — FName, регистр не различают;
игра пишет имя в том регистре, в каком FName родился первым. Поэтому строки сравниваются ЦЕЛИКОМ (действие или ось, клавиша,
Shift/Ctrl/Alt/Cmd, долгое нажатие, у осей Scale) и без учёта регистра: имена, клавиши и True/False — в нижнем регистре,
числа — как числа (-1.0 = -1.000000).

Что сравнивается: только строки ActionMappings / AxisMappings секции [/Script/Engine.InputSettings] (имя секции — без учёта
регистра). ConsoleKeys и прочие ключи не сравниваются (у владельца ConsoleKeys = Insert, Tilde, F10 — едут с файлом целиком).
Игра пишет полный массив строк без префикса; файл с командами «-ActionMappings» / «!ActionMappings» (разностный вид) прибор
не разбирает — отказ с кодом 2, а не тихая неверная разница (находка судьи 2026-11-14).

Запуск:
    python -I -X utf8 _config/input-edits.py <Input.ini игры> <DefaultInput.ini из pakchunk0>
        DefaultInput.ini достаётся так: repak get <игра>/ConanSandbox/Content/Paks/pakchunk0-Windows.pak
        ConanSandbox/Config/DefaultInput.ini > <файл>
Выход: 0 — сравнение напечатано; 2 — файл не прочитан или в нём команды «-» / «!».
"""
import re
import sys
from collections import Counter

SECTION = '[/script/engine.inputsettings]'
ROW = re.compile(r'^([+.]?)(ActionMappings|AxisMappings)=\((.*)\)\s*$', re.IGNORECASE)
COMMAND = re.compile(r'^[-!](ActionMappings|AxisMappings)=', re.IGNORECASE)
FIELD = re.compile(r'(\w+)=("[^"]*"|[^,]*)')
KIND = {'actionmappings': 'ActionMappings', 'axismappings': 'AxisMappings'}
KIND_RU = {'ActionMappings': 'действие', 'AxisMappings': 'ось'}


def norm(value):
    """Значение поля для сравнения: число — как число, остальное (FName клавиши, True/False) — в нижнем регистре."""
    v = value.strip().strip('"')
    try:
        return repr(round(float(v), 6))
    except ValueError:
        return v.lower()


# Поля, которых нет в строке, Unreal берёт по умолчанию — короткая строка (ActionName="Crouch",Key=C) равна полной (судья, раунд 2)
FIELD_DEFAULTS = {'ActionMappings': {'bShift': 'False', 'bCtrl': 'False', 'bAlt': 'False', 'bCmd': 'False', 'bLongPress': 'False'},
                  'AxisMappings': {'Scale': '1.0'}}


def rows(path):
    """Многомножество строк привязок: (вид, имя в нижнем регистре, кортеж прочих полей), имя для показа (первое написание) и
    способ записи каждого вида: 'plain' — полный массив (заменяет заводской), 'plus' — строки «+» (дописываются к заводскому, без повторов)."""
    try:
        text = open(path, encoding='utf-8-sig', errors='strict').read()
    except (OSError, UnicodeDecodeError) as e:
        print(f'не прочитан {path}: {e}')
        sys.exit(2)
    out, display, stray, mode = Counter(), {}, 0, {}
    section = ''
    for line in text.splitlines():
        line = line.strip()
        if line.startswith('['):
            section = line.lower()
            continue
        if COMMAND.match(line):
            print(f'{path}: строка с командой «-» / «!» ({line[:60]}…) — разностный вид прибор не разбирает')
            sys.exit(2)
        m = ROW.match(line)
        if not m:
            continue
        if section != SECTION:
            stray += 1
            continue
        pre, kind, body = m.groups()
        kind = KIND[kind.lower()]
        how = {'+': 'plus', '.': 'dot'}.get(pre, 'plain')   # «.» — Add (повторы разрешены), тоже дописывается к заводскому (судья, раунд 3)
        if mode.setdefault(kind, how) != how:
            print(f'{path}: в {kind} смешаны строки «+» и полные — прибор такой файл не разбирает')
            sys.exit(2)
        fields = dict(FIELD_DEFAULTS[kind])
        fields.update((k, v) for k, v in FIELD.findall(body))
        raw = (fields.pop('ActionName', None) or fields.pop('AxisName', '')).strip('"')
        name = raw.lower()
        display.setdefault(name, raw)
        row = (kind, name, tuple(sorted((k, norm(v)) for k, v in fields.items())))
        if how == 'plus' and out[row]:
            continue                                   # «+» — AddUnique: повтор той же строки Unreal не добавляет
        out[row] += 1
    if stray:
        print(f'{path}: {stray} строк привязок вне секции [/Script/Engine.InputSettings] — не сравниваются')
    return out, display, mode


def show(row):
    kind, name, fields = row
    f = dict(fields)
    mods = '+'.join(k[1:] for k in ('bShift', 'bCtrl', 'bAlt', 'bCmd') if f.get(k) == 'true')
    extra = ' долгое' if f.get('bLongPress') == 'true' else ''
    scale = f' Scale {f["Scale"]}' if 'Scale' in f else ''
    return f'{(mods + "+") if mods else ""}{f.get("Key", "?")}{scale}{extra}'


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    (live, disp_live, mode_live), (dflt, disp_dflt, _) = rows(sys.argv[1]), rows(sys.argv[2])
    # Вид, записанный в живом файле строками «+», дописывается к заводскому: живой массив = заводской ∪ эти строки (без повторов)
    for kind, how in mode_live.items():
        if how in ('plus', 'dot'):
            for r, n in dflt.items():
                if r[0] == kind:
                    live[r] = live[r] + n if how == 'dot' else max(live[r], n)
    only_live = live - dflt
    only_dflt = dflt - live
    # Игра пишет массив вида (действия, оси) в живой файл только когда его меняли: нет строк вида — он заводской, это не правка.
    # 2026-11-14 12:16: на заводских привязках игра при выходе записала файл без единой строки (шапка и [CurrentIniVersion]).
    absent = [k for k in ('ActionMappings', 'AxisMappings') if not any(r[0] == k for r in live)]
    only_dflt = Counter({r: n for r, n in only_dflt.items() if r[0] not in absent})
    names_ru = {'ActionMappings': 'действий', 'AxisMappings': 'осей'}
    print(f'строк: живой файл {sum(live.values())}, заводской {sum(dflt.values())}'
          + ''.join(f'; {names_ru[k]} в живом файле нет — они заводские' for k in absent))
    keys = sorted({(r[0], r[1]) for r in only_live} | {(r[0], r[1]) for r in only_dflt})
    print(f'действий и осей с правками: {len(keys)}')
    for kind, name in keys:
        was = ', '.join(show(r) for r in sorted(only_dflt) if (r[0], r[1]) == (kind, name)) or '—'
        now = ', '.join(show(r) for r in sorted(only_live) if (r[0], r[1]) == (kind, name)) or '—'
        print(f'  {KIND_RU[kind]} {disp_dflt.get(name) or disp_live.get(name)}: заводское {was} → у владельца {now}')
    sys.exit(0)


if __name__ == '__main__':
    main()
