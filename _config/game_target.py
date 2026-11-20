# game_target.py — папка игры для приборов сборки: первая включённая цель targets.json.
#
# Зачем (2026-10-25 вечер): после переезда на 3.0.1 и удаления 2.2.3 с диска 21 прибор `_config/` смотрел в зашитый путь
# «D:\Games\Conan Exiles 2.2.3\Conan Exiles» — who-overwrites-table.py ответил «журнала игры нет», close-game.ps1 ждал
# освобождения чужого UE4SS.dll. Первый такой случай (deploy-localization.py, шаг 19 плана 33) починили одним файлом, и класс
# остался. Теперь путь игры живёт в одном месте — targets.json, как у движка KUMM.
#
# 2026-11-13 (переезд на 3.1.0, KUMM план 53): тот же класс у папки-представления контейнеров игры — patch-mod-asset.py смотрел в
# зашитое `_paksview-3.0.1`, build-level-mod.py — в `_paksview-2.2.3`. Имя цели (`name` в targets.json) даёт и имя представления.
#
#   from game_target import GAME_DIR, GAME_NAME, PAKS_VIEW, sandbox   # sandbox('Saved', 'Logs', 'ConanSandbox.log')
# [NOT-TESTED]
import json
import os

PACK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIEWS_ROOT = r"D:\work\ai_sandbox"   # представления — жёсткие ссылки на контейнеры игры: тот же том D:, вне папки игры


def target():
    data = json.load(open(os.path.join(PACK, 'targets.json'), encoding='utf-8'))
    for t in data.get('targets', []):
        if t.get('enabled', True):
            return t
    raise SystemExit('В targets.json нет включённых целей')


def game_dir():
    return target()['path']


_T = target()
GAME_DIR = _T['path']
GAME_NAME = _T['name']
PAKS_VIEW = os.path.join(VIEWS_ROOT, '_paksview-' + GAME_NAME)


def sandbox(*parts):
    return os.path.join(GAME_DIR, 'ConanSandbox', *parts)
