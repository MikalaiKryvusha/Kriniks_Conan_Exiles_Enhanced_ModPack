# -*- coding: utf-8 -*-
# Таблица добычи 16 сундуков мода Caverns of Set — ту, которой нет ни в паке автора, ни в игре (KUMM games/ConanExiles/mods/CavernsOfSet.md).
# Сундук BP_PL_CoS_Loot_Chest и его спавнер ссылаются на /Game/Mods/Mines_of_Set/Tables/Caverns_of_Set_Loot_Chest_Table; пакета нет — сундук пуст.
# Мы кладём ассет по ЭТОМУ пути в пак KrinikConanGameplay (build-level-mod.py, шаг 3б): ссылка сундука разрешается сама, пак автора не правится.
#
# Решение владельца: `[OWNER]` 2026-11-01 08:58 «делаем сейчас 2» — вариант 2 интервью 029: свой СЛУЧАЙНЫЙ рецепт в формате игры (строки — броски по
# меткам: высокий уровень, Стигия — культура Сета, несколько бросков, редкая добавка). Числа ниже — `[AI]` в этой рамке, правятся свободно.
#
# Формат строки — /Script/ConanSandbox.LootTableRow (карта игры KUMM, «Loot generation»): строка берётся КОПИЕЙ строки ванильной таблицы
# DT_LC_RelicHunter (её запрос меток RequiredTags уже в формате игры), меняются поля и имена меток.
# [TESTED: 2026-11-01 · builder step 6 green (12 rows = the recipe, in the container at the chest's path); in game the 16 chests read this table,
#  the nearest filled with 6 items of rows 1-5 · KUMM testcases/reports/2026-11-01_conan-caverns-chest-loot.md]

SOURCE_TABLE = "DT_LC_RelicHunter"
SOURCE_PACKAGE = "/Game/Systems/Loot/New/Culture/RelicHunters/DT_LC_RelicHunter"
TABLE = "Caverns_of_Set_Loot_Chest_Table"
PACKAGE = "/Game/Mods/Mines_of_Set/Tables/Caverns_of_Set_Loot_Chest_Table"

SET_HEALING_TINCTURE = 77991133   # «Set's Healing Tincture» — из Caverns_of_Set_Item_Table мода
SACRED_ELDARIUM = 77991105        # «Sacred Eldarium» — там же

# (имя строки, строка-образец из DT_LC_RelicHunter, поля, замена меток)
ROWS = [
    # основа: общая добыча верхнего уровня, три броска — пещеры у автора «от середины игры до конца»
    ("1", "2", {"Min": 1, "Max": 3, "PercentChance": 100.0, "NumRolls": 3}, {"Loot.T3": "Loot.T4"}),
    ("2", "2", {"Min": 1, "Max": 3, "PercentChance": 75.0, "NumRolls": 2}, {}),
    # Стигия — культура Сета: размещаемые вещи
    ("3", "1", {"Min": 1, "Max": 1, "PercentChance": 35.0, "NumRolls": 1}, {}),
    ("4", "14", {"PercentChance": 15.0}, {"Loot.T3": "Loot.T4"}),            # набор починки оружия T4
    ("5", "15", {"PercentChance": 15.0}, {"Loot.T3": "Loot.T4"}),            # набор починки брони T4
    ("6", "16", {"PercentChance": 10.0, "NumRolls": 1}, {"Loot.T3": "Loot.T4"}),   # инструмент T4
    ("7", "8", {"PercentChance": 40.0, "NumRolls": 2}, {}),                  # монеты
    ("8", "13", {"PercentChance": 5.0}, {}),                                 # сокровище
    # вещи самого мода — редкая добавка
    ("9", "10", {"ItemID": SET_HEALING_TINCTURE, "Min": 1, "Max": 2, "PercentChance": 20.0, "NumRolls": 1}, {}),
    ("10", "10", {"ItemID": SACRED_ELDARIUM, "Min": 1, "Max": 1, "PercentChance": 5.0, "NumRolls": 1}, {}),
    ("11", "20", {"PercentChance": 3.0}, {}),                                # вложенная таблица деталей голема T4
    ("12", "5", {"PercentChance": 2.0}, {}),                                 # учитель эмоций
]
