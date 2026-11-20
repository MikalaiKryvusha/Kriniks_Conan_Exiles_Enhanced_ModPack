# -*- coding: utf-8 -*-
"""build_music_folders.py — KrinikConanMusic's ONE scene table -> the mod's music folders, their Russian README.md, and Scripts/scenes.lua (KUMM plan 46).

The owner's word (2026-11-06 17:25): «Поставляться в сборке он будет с пустыми папками, в которых будут лежить README.md, с описание, за какие сцены отвечает
текущая папка, какие треки в неё пользователю закидывать». One table here is the truth (DRY): the folder list, each folder's README and the Lua map cue -> scene
are all generated from it, so they cannot drift.

The cues come from stage_rows.tsv (the music group of the game's SoundStageAudioTable and the stage tables of the build's mods, read from the paks
2026-11-06). Every cue there must land in a scene or in SILENCE — `--verify` fails otherwise (a new mod's stage rows show up as «unmapped»).
    python build_music_folders.py <mod dir>            # writes music/<scene>/README.md, music/README.md, Scripts/scenes.lua
    python build_music_folders.py <mod dir> --verify   # exit 1 when a folder, a README or a cue mapping is missing or extra
[TESTED: 2026-11-06 · wrote 21 files / 19 scenes / 112 cues; --verify ok; control: an edited README and an extra folder -> exit 1 (stale + "folders not in the table")]
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# folder, Russian title, what plays here (the player's words), what tracks fit, fallback chain after the folder itself
SCENES = [
    ('explore', 'Мир — общая папка',
     'Любое место открытого мира, для которого в своей папке нет треков: пустыня, реки, джунгли, север, города. Сюда удобно положить «музыку на всё».',
     'Спокойные фоновые треки без резких начал: эмбиент, оркестр, фолк. Длинные, от трёх минут.', []),
    ('explore_desert', 'Пустыня',
     'Юг карты: пески, оазисы, Гибельные курганы, Провал, стоянки пиратов и Псов пустыни; песчаные земли мода Caverns of Set.',
     'Сухие, тягучие, восточные мотивы: дудук, уд, барабаны, гортанное пение.', ['explore']),
    ('explore_riverlands', 'Реки и нагорья',
     'Середина карты: речные долины, плодородные нагорья, плато каньона, горячие источники, пиратский берег и корабль.',
     'Светлая, просторная музыка: струнные, флейты, неторопливый оркестр.', ['explore']),
    ('explore_jungle', 'Джунгли и болота',
     'Джунгли и болота к югу от реки.',
     'Влажная, тревожная музыка: перкуссия, низкие духовые, звуки леса.', ['explore']),
    ('explore_north', 'Север и снега',
     'Север карты: ледяные склоны, деревни киммерийцев и нордхеймцев, Полуночная роща.',
     'Холодная, суровая музыка: волынка, рог, хор, северный фолк.', ['explore']),
    ('explore_volcano', 'Вулкан',
     'Вулкан на севере карты и земли вокруг него.',
     'Тяжёлая, грозная музыка: литавры, низкий хор, медь.', ['explore']),
    ('explore_cities', 'Города и руины',
     'Безымянный город и его окрестности, Сепермеру, обсерватория, Остров Телиф, Архивы, храм Сета, город нежити.',
     'Таинственная, древняя музыка: хоралы, арфа, медленные струнные.', ['explore']),
    ('explore_siptah', 'Остров Сиптах',
     'Карта острова Сиптаха: побережье, пепельные земли, мёртвая зона, разливы, холмы, леса секвой, башня Сиптаха. Если вы играете только в Землях изгнанников, папка не понадобится.',
     'Морская, мистическая музыка.', ['explore']),
    ('tavern', 'Таверна',
     'Таверны и винный погреб.',
     'Застольная музыка: лютня, бубен, весёлые песни.', ['explore']),
    ('dungeon', 'Подземелья',
     'Подземелья и пещеры: Клоака, подземелья у Наковальни королей-великанов, ледяная, каменная, песчаная и паучья пещеры, дворец Королевы-ведьмы, '
     'хранилища острова Сиптаха; пещеры модов Caverns of Set и Ymir\'s Respite.',
     'Тёмная, гнетущая музыка: дроны, низкие струнные, редкие удары.', []),
    ('character_creation', 'Создание героя',
     'Экран создания героя и точка возрождения.',
     'Вступительная тема: торжественно, но спокойно.', []),
    ('death', 'Смерть героя',
     'От гибели героя до возрождения.',
     'Короткая печальная или торжественная тема — она звучит, пока вы выбираете, где возродиться.', []),
    ('combat', 'Бой — общая папка',
     'Любой бой, для силы противника которого в своей папке нет треков.',
     'Ритмичная боевая музыка: барабаны, медь, хор. Треки с быстрым началом.', []),
    ('combat_very_easy', 'Бой со слабым противником',
     'Самые слабые враги: звери, мелкие хищники. У игры здесь своей музыки почти нет — сюда кладут, если хочется музыки и в таких стычках.',
     'Лёгкая перкуссия, короткие треки.', ['combat']),
    ('combat_easy', 'Бой: противник попроще', 'Слабые люди и звери.', 'Негромкая боевая музыка.', ['combat']),
    ('combat_normal', 'Бой: обычный противник', 'Обычные враги.', 'Боевая музыка средней силы.', ['combat']),
    ('combat_hard', 'Бой: сильный противник', 'Сильные враги, элита.', 'Напряжённая боевая музыка.', ['combat']),
    ('combat_very_hard', 'Бой: очень сильный противник', 'Очень сильные враги.', 'Тяжёлая, напористая боевая музыка.', ['combat']),
    ('combat_boss', 'Бой с боссом', 'Боссы мира и подземелий.', 'Эпическая музыка: хор, оркестр, большой барабан.', ['combat']),
    ('combat_avatar', 'Бой с аватаром бога', 'Призванный аватар бога.', 'Самая грандиозная боевая музыка.', ['combat_boss', 'combat']),
]

COMBAT_TIERS = {'VeryEasy': 'combat_very_easy', 'Easy': 'combat_easy', 'Normal': 'combat_normal', 'Hard': 'combat_hard',
                'VeryHard': 'combat_very_hard', 'Boss': 'combat_boss', 'Avatar': 'combat_avatar'}

# cue -> scene. [AI] grouping by where the cue plays (row names of the stage tables); the owner sees the folder list with the first build.
CUE_SCENE = {
    'Music_Area_Oasis': 'explore_desert', 'Music_Area_Middle': 'explore_desert', 'Music_Mounds_of_the_dead': 'explore_desert',
    'Music_Area_Sinkhole_Arena': 'explore_desert', 'Music_Area_Blackhand_Pirate_Main': 'explore_desert', 'Music_Temp_Neutral_Cue': 'explore_desert',
    'Music_Area_North': 'explore_desert',
    'CUE_1__Sand_Gates_Cue': 'explore_desert', 'CUE_2__Sand_Market_Cue': 'explore_desert', 'CUE_4__Dune_Outpost_Cue': 'explore_desert',
    'CUE_9__Desert_Tribe_Cue': 'explore_desert', '2_Arabian_Nights_Loop_Cue': 'explore_desert', 'Music_Area_Akhlut_Outpost': 'explore_desert',
    'Music_Area_Riverland': 'explore_riverlands', 'Music_Area_Fertile_Highlands': 'explore_riverlands', 'Music_Temp_Neutral_Highlands_Cue': 'explore_riverlands',
    'Music_Area_Canyon_Plateou': 'explore_riverlands', 'Music_Area_Hotsprings': 'explore_riverlands', 'Music_Area_Blackhand_Pirate': 'explore_riverlands',
    'Music_Area_Blackhand_PirateShip': 'explore_riverlands',
    'Music_Area_Jungle_Swamp_main': 'explore_jungle', 'Music_Area_South_of_the_River': 'explore_jungle',
    'Music_Area_South_of_the_River_BatDemon': 'explore_jungle',
    'Music_Area_the_frozen_slope': 'explore_north', 'Music_Village_Cimmerian_1_Cue': 'explore_north', 'Music_Village_Nordheimer_1_Cue': 'explore_north',
    'Music_Area_Midnight_Grove': 'explore_north',
    'Music_Area_Volcano_1': 'explore_volcano', 'Music_Area_Volcano_2': 'explore_volcano',
    'Music_Area_Unnamed_City': 'explore_cities', 'Music_Area_Unnamed_City_Extended': 'explore_cities', 'Music_Area_Undead_City': 'explore_cities',
    'Music_Area_RellicHunterCity': 'explore_cities', 'Music_Area_Observatory': 'explore_cities', 'Music_Area_Teliths_island': 'explore_cities',
    'Music_Area_Unnamed_Archives': 'explore_cities', 'Music_Area_Unnamed_Set_Temple': 'explore_cities',
    'Music_Area_Ashlands': 'explore_siptah', 'Music_Area_Beach': 'explore_siptah', 'Music_Area_Deadzone': 'explore_siptah',
    'Music_Area_Eastern_Redwoods': 'explore_siptah', 'Music_Area_Floodlands': 'explore_siptah', 'Music_Area_Rolling_Hills': 'explore_siptah',
    'Music_Area_Savanna': 'explore_siptah', 'Music_Area_Tower': 'explore_siptah', 'Music_Area_Western_Highlands': 'explore_siptah',
    'tavern_music_styg_ST_Cue': 'tavern', 'Music_Area_WineCellar_Drunk': 'tavern',
    'music_xls_033_resurrection_point_ST_Cue': 'character_creation',
}
DUNGEON_PREFIXES = ('Music_Area_Dungeon_Sewer_', 'music_dark_dregs_', 'MS_mus_anvil_giants_', 'MS_mus_od_rift_arena', 'mus_vault_',
                    'music_witch_queen_', 'music_xls_025_', 'music_xls_026_', 'music_xls_027_', 'music_xls_028_',
                    '1_Dread_', '4_Macabre_', '7_Nightmare_', '8_Doom_', 'Darkness_Vol_2_Mix', 'DarknessVol_Mix_', '08_Low1_', '13_Full_Loop_',
                    'FantasyAdventure', 'Leading_Nowhere_', 'Out_Of_The_Mist_')
# the game asks for silence (or a test cue) — ours stays silent too
SILENCE = ('Music_Silence', 'Music_Silence_Slow_Fade', 'sfx_misc_test_music_Main_Cue', 'mus_vault_stop_Cue', 'music_dark_dregs_stop_Cue')

ROOT_README = '''# Своя музыка в Conan Exiles — KrinikConanMusic

Положите свои треки в папки — и в этих местах и сценах игры зазвучит ваша музыка вместо родной.

- **Форматы:** mp3, ogg, flac, wav. Имена файлов — любые, кириллица тоже.
- **Несколько треков в папке** — при каждом входе в сцену играет случайный, один и тот же два раза подряд не повторяется; кончился — начинается следующий.
- **Пустая папка** — играет родная музыка игры. Положили треки только в «Бой — общая папка» — ваша музыка звучит в любом бою.
- **Запасные папки.** Если в папке сцены пусто, играет общая папка: для мест мира — `explore`, для боя — `combat`.
- **Переходы плавные.** Если вернуться в сцену в течение минуты, трек продолжится с того же места.
- **Треки можно добавлять, не выходя из игры:** мод замечает их за несколько секунд.
- **Громкость отдельного трека** — строка `имя_файла.mp3|0.5` в файле `track_gains.txt` этой папки: 0.5 — вдвое тише, 1.5 — громче.
- **Свой порядок** — файл `playlist.txt` в папке сцены: по одному имени файла на строку, играют только они и по порядку; строка `-имя_файла.mp3` убирает файл из игры.

Что звучит в каждой папке — в её `README.md`.
'''


def folder_readme(folder, title, what, tracks, chain):
    fallback = ''
    if chain:
        names = {s[0]: s[1] for s in SCENES}
        fallback = '\n**Если здесь пусто**, играет папка `%s` («%s»).\n' % (chain[0], names[chain[0]])
    elif folder not in ('explore', 'combat'):
        fallback = '\n**Если здесь пусто**, играет родная музыка игры.\n'
    return '# %s\n\n**Где звучит.** %s\n\n**Какие треки подходят.** %s\n%s' % (title, what, tracks, fallback)


def scene_of(cue):
    if cue in CUE_SCENE:
        return CUE_SCENE[cue]
    if cue in SILENCE:
        return ''
    if cue.startswith(DUNGEON_PREFIXES):
        return 'dungeon'
    return None


def cues():
    out = []
    for line in open(os.path.join(HERE, 'stage_rows.tsv'), encoding='utf-8'):
        if line.startswith('#') or not line.strip():
            continue
        t, row, cue = line.rstrip('\n').split('\t')
        out.append((t, row, cue))
    return out


def scenes_lua():
    chains = {s[0]: [s[0]] + s[4] for s in SCENES}
    lines = ['-- scenes.lua — GENERATED by ConanExiles/_config/music/build_music_folders.py from its scene table; edit the table, not this file.',
             '-- CUE: the game\'s stage music cue -> our scene ("" = the game asks for silence). CHAIN: scene -> folders in fallback order.',
             'local M = {}', 'M.CUE = {']
    rows_of = {}
    for t, row, cue in cues():
        rows_of.setdefault(cue, set()).add('%s:%s' % (t, row))
    for cue in sorted(rows_of):                       # one line per cue, a full sort: the output is diffed by --verify
        s = scene_of(cue)
        lines.append('  ["%s"] = "%s", -- %s' % (cue, s if s is not None else 'explore', ' '.join(sorted(rows_of[cue]))))
    lines.append('}')
    lines.append('M.COMBAT_TIER = {')
    for k, v in COMBAT_TIERS.items():
        lines.append('  [%d] = "%s", -- %s' % (list(COMBAT_TIERS).index(k) + 1, v, k))
    lines.append('}')
    lines.append('M.CHAIN = {')
    for k in sorted(chains):
        lines.append('  %s = {%s},' % (k, ', '.join('"%s"' % c for c in chains[k])))
    lines.append('}')
    lines.append('M.UNKNOWN_CUE_SCENE = "explore"  -- a stage cue of a mod we have not read yet')
    lines.append('return M')
    return '\n'.join(lines) + '\n'


def main():
    mod = sys.argv[1]
    verify = '--verify' in sys.argv
    music = os.path.join(mod, 'music')
    errors = []
    unmapped = sorted({c for _, _, c in cues() if scene_of(c) is None})
    if unmapped:
        errors.append('unmapped cues: ' + ', '.join(unmapped))
    want = {os.path.join(music, 'README.md'): ROOT_README}
    for folder, title, what, tracks, chain in SCENES:
        want[os.path.join(music, folder, 'README.md')] = folder_readme(folder, title, what, tracks, chain)
    want[os.path.join(mod, 'Scripts', 'scenes.lua')] = scenes_lua()
    if verify:
        for path, text in want.items():
            if not os.path.exists(path):
                errors.append('missing ' + os.path.relpath(path, mod))
            elif open(path, encoding='utf-8', newline='').read().replace('\r\n', '\n') != text:   # a clone with core.autocrlf=true has CRLF
                errors.append('stale ' + os.path.relpath(path, mod))
        present = {d for d in os.listdir(music) if os.path.isdir(os.path.join(music, d))} if os.path.isdir(music) else set()
        extra = present - {s[0] for s in SCENES}
        if extra:
            errors.append('folders not in the table: ' + ', '.join(sorted(extra)))
    else:
        for path, text in want.items():
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                f.write(text)
        print('wrote %d files, %d scenes, %d cues' % (len(want), len(SCENES), len({c for _, _, c in cues()})))
    for e in errors:
        print('ERROR', e)
    if verify and not errors:
        print('verify ok: %d scenes, every cue mapped' % len(SCENES))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
