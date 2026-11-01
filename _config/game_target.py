# game_target.py — папка игры для приборов сборки: первая включённая цель targets.json.
#
# Зачем (2026-10-25 вечер): после переезда на 3.0.1 и удаления 2.2.3 с диска 21 прибор `_config/` смотрел в зашитый путь
# «D:\Games\Conan Exiles 2.2.3\Conan Exiles» — who-overwrites-table.py ответил «журнала игры нет», close-game.ps1 ждал
# освобождения чужого UE4SS.dll. Первый такой случай (deploy-localization.py, шаг 19 плана 33) починили одним файлом, и класс
# остался. Теперь путь игры живёт в одном месте — targets.json, как у движка KUMM.
#
#   from game_target import GAME_DIR, sandbox   # sandbox('Saved', 'Logs', 'ConanSandbox.log')
# [NOT-TESTED]
import json
import os

PACK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def game_dir():
    data = json.load(open(os.path.join(PACK, 'targets.json'), encoding='utf-8'))
    for t in data.get('targets', []):
        if t.get('enabled', True):
            return t['path']
    raise SystemExit('В targets.json нет включённых целей')


GAME_DIR = game_dir()


def sandbox(*parts):
    return os.path.join(GAME_DIR, 'ConanSandbox', *parts)
