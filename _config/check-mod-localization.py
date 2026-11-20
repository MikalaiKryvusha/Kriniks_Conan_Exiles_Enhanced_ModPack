#!/usr/bin/env python3
"""
Проверяет, есть ли у модов РУССКАЯ локализация — не запуская игру.

[TESTED: 2026-09-09 · прогон по 36 пакам сборки.]

ЗАЧЕМ. Заказ владельца: «по ходу как моды ставишь, проверяй, чтобы у них была
руссификация. Если нет - будем сами руками пробовать переводить потом». Общего
переключателя языка у модов нет: язык есть только у тех, чей автор его сделал.
Проверять это по описанию на Мастерской нельзя - авторы про язык обычно молчат.

КАК УСТРОЕНО. Unreal хранит переводы файлами `.locres`, разложенными по папкам
языков, и ПУТИ К НИМ лежат в индексе .pak открытым текстом:

    <Мод>/Content/Localization/<Пространство>/ru/<Пространство>.locres
                                              ^^ вот это и ищем

Скрипт читает пак кусками, находит все вхождения `.locres`, отматывает назад до
границ пути и достаёт предпоследний элемент - код языка. Ничего не распаковывает
и ничего не пишет.

ЧТО ЗНАЧИТ РЕЗУЛЬТАТ:
  * «ru» в списке        - русский перевод внутри пака ЕСТЬ;
  * список без «ru»      - мод переведён на другие языки, но не на русский:
                           значит место для перевода готово, и наш перевод туда
                           ляжет тем же способом, каким автор кладёт свои;
  * «локализации нет»    - в паке нет .locres вообще. Строки зашиты в ассеты, и
                           перевод потребует правки самих ассетов, то есть на
                           порядок дороже.

⚠️ ОГОВОРКА. Отсутствие .locres не всегда значит отсутствие перевода: часть
модов кладёт переводы ОТДЕЛЬНЫМ файлом или раздаёт их в своём Discord (так
делает Exiles Fishing). Скрипт отвечает на вопрос «есть ли перевод В ПАКЕ», а не
«существует ли он в природе».

Запуск:
    python _config/check-mod-localization.py                 - по всем модам игры
    python _config/check-mod-localization.py --lib           - по библиотеке пака
    python _config/check-mod-localization.py <файл.pak> ...  - по конкретным
"""

import argparse
import os
import re
import sys

import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from game_target import GAME_DIR, sandbox   # путь игры — из targets.json (2026-10-25: 2.2.3 удалена)
GAME_MODS = sandbox('Mods')
LIB_WORKSHOP = r"D:\work\ai_sandbox\ConanExiles\_library\mods\_workshop"

CHUNK = 8 << 20          # 8 МБ за раз
TAIL = 512               # нахлёст, чтобы не разрезать путь на границе кусков
PATH_RE = re.compile(rb"[ -~]{4,200}\.locres")


def languages_in(path: str):
    """Коды языков, найденные в путях .locres внутри пака."""
    langs, seen = set(), 0
    with open(path, "rb") as f:
        prev = b""
        while True:
            chunk = f.read(CHUNK)
            if not chunk:
                break
            seen += len(chunk)
            for m in PATH_RE.finditer(prev + chunk):
                parts = m.group(0).replace(b"\\", b"/").split(b"/")
                if len(parts) >= 2:
                    lang = parts[-2].decode("ascii", "ignore").strip()
                    # код языка: en, ru, de, pt-BR, zh-Hans...
                    if 2 <= len(lang) <= 7 and re.fullmatch(r"[A-Za-z]{2,3}(-[A-Za-z]+)?", lang):
                        langs.add(lang)
            prev = chunk[-TAIL:]
    return sorted(langs), seen


def main() -> int:
    ap = argparse.ArgumentParser(description="Есть ли у модов русская локализация")
    ap.add_argument("paks", nargs="*")
    ap.add_argument("--lib", action="store_true", help="смотреть библиотеку, а не игру")
    args = ap.parse_args()

    if args.paks:
        files = [p for p in args.paks if p.lower().endswith(".pak")]
    else:
        root = LIB_WORKSHOP if args.lib else GAME_MODS
        files = []
        for dirpath, _, names in os.walk(root):
            files += [os.path.join(dirpath, n) for n in names if n.lower().endswith(".pak")]
    if not files:
        sys.exit("паков не найдено")

    with_ru, other, none = [], [], []
    print(f"Проверяю {len(files)} паков…{chr(10)}")
    for p in sorted(files, key=lambda x: os.path.basename(x).lower()):
        name = os.path.basename(p)
        try:
            langs, _ = languages_in(p)
        except Exception as e:
            print(f"  [ошибка] {name}: {e}")
            continue
        if "ru" in [l.lower() for l in langs]:
            with_ru.append(name)
            mark, note = "✅ RU", ", ".join(langs)
        elif langs:
            other.append(name)
            mark, note = "— нет ru", ", ".join(langs)
        else:
            none.append(name)
            mark, note = "·  нет локализации", "строки зашиты в ассеты"
        print(f"  {mark:<20} {name[:44]:44} {note}")

    print()
    print(f"С русским:            {len(with_ru)}")
    print(f"Переведён, но без ru: {len(other)}   <- сюда наш перевод ляжет штатно")
    print(f"Без локализации:      {len(none)}   <- перевод потребует правки ассетов")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
