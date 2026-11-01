#!/usr/bin/env python
"""deploy-localization.py — раскатать русский перевод интерфейса в папку игры и сверить хэшами.

ЗАЧЕМ ОТДЕЛЬНЫЙ ПРИБОР. Перевод живёт ДВУМЯ файлами внутри `Content/` игры, а не в паке и не в
моде: `deploy-config.py` возит только ini-файлы в `Saved/Config`, и подмешивать сюда чужую задачу
незачем. Переустановка или проверка целостности игры сотрёт эти файлы молча — тогда перевод
пропадёт без единой ошибки, и вернуть его должна одна команда, а не память сессии.

ПОЧЕМУ ИМЕННО ЭТОТ ПУТЬ — разбор в `localization/README.md`. Коротко: `Content/Localization/Game`
входит в список путей локализации движка ПО УМОЛЧАНИЮ, этой цели нет ни в одном паке игры, а
россыпью движок читает `.locres` спокойно (запрет на файлы вне пака касается `uasset/umap/uexp/
ubulk`, не локализации). Ни мод-загрузчик, ни UE4SS в этой дороге не участвуют.

    python deploy-localization.py            # раскатать и сверить
    python deploy-localization.py --check     # только сверить, ничего не писать
    python deploy-localization.py --remove    # снять перевод (вернуть английский интерфейс мода)
"""
import hashlib
import os
import shutil
import sys

import json

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'localization', 'Game')


def first_target():
    """Папка игры первой включённой цели targets.json.
    Оплачено 2026-10-25: путь 2.2.3 был зашит сюда строкой, и при переезде на 3.0.1 перевод HUD Hosav
    просто не поехал - раскатка сборки этот прибор не зовёт, а он сам смотрел в старую игру."""
    data = json.load(open(os.path.join(os.path.dirname(HERE), 'targets.json'), encoding='utf-8'))
    for t in data.get('targets', []):
        if t.get('enabled', True):
            return t['path']
    raise SystemExit('В targets.json нет включённых целей')


DST = os.path.join(first_target(), 'ConanSandbox', 'Content', 'Localization', 'Game')

# что именно возим: en/Game.locres НЕ возим — игра берёт английский из самого мода,
# и лишний файл только притворялся бы участником.
FILES = ['Game.locmeta', os.path.join('ru', 'Game.locres')]


def sha256(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def main(argv):
    check = '--check' in argv
    remove = '--remove' in argv

    if remove:
        gone = 0
        for rel in FILES:
            p = os.path.join(DST, rel)
            if os.path.exists(p):
                os.remove(p)
                gone += 1
                print('снят  ', p)
        for d in (os.path.join(DST, 'ru'), DST):
            if os.path.isdir(d) and not os.listdir(d):
                os.rmdir(d)
                print('пусто ', d)
        print('снято файлов:', gone)
        return 0

    bad = 0
    for rel in FILES:
        s, d = os.path.join(SRC, rel), os.path.join(DST, rel)
        if not os.path.exists(s):
            print('НЕТ ИСТОЧНИКА:', s)
            bad += 1
            continue
        same = os.path.exists(d) and sha256(s) == sha256(d)
        if same:
            print('совпадает', rel, sha256(s)[:16])
            continue
        if check:
            print('РАСХОЖДЕНИЕ', rel, '(в игре нет или другой)')
            bad += 1
            continue
        os.makedirs(os.path.dirname(d), exist_ok=True)
        shutil.copy2(s, d)
        ok = sha256(s) == sha256(d)
        print('раскатан ' if ok else 'СБОЙ     ', rel, sha256(s)[:16])
        bad += 0 if ok else 1

    print('итог:', 'всё на месте' if bad == 0 else f'проблем: {bad}')
    return 0 if bad == 0 else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
