"""Build the Nexus Full description (BBCode) for Krinik Mod Pack 0.9.0 from the owner's started text and the pack README tables."""
import json, re, sys

S = sys.argv[1]
OUT = sys.argv[2]
owner = json.load(open(f'{S}/nexus_desc_now.json', encoding='utf-8'))['bb']
readme = open(f'{S}/conan_readme.md', encoding='utf-8').read()

REPO = 'https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack'
RAW = 'https://raw.githubusercontent.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/main'
C = '#D4D4D8'
ACC = '#E0A458'

# --- the owner's text: minimal fixes only -------------------------------------------------------
fixes = [
    ('opens an email addres[/color]', 'opens an email to the pack author.[/color]'),
    ('[size=4]Camera positioning controls[/size]', '[b][size=4]Camera positioning controls[/size][/b]'),
    ('вид отпервого лица', 'вид от первого лица'),
    ('всё обдумать спокойно. Поселение и спутники\n',
     f'всё обдумать спокойно.[/color]\n\n[color={C}][b][size=4]Поселение и спутники[/size][/b]\n'),
    ('герой\nбыстрее бегает', 'герой быстрее бегает'),
    ('путевых\nкамней', 'путевых камней'),
    ('броня\nсеми религий', 'броня семи религий'),
    ('ловушки\nдля рыбы', 'ловушки для рыбы'),
]
owner = owner.replace(' ', ' ')
for a, b in fixes:
    assert a in owner, a
    owner = owner.replace(a, b)

def between(text, start, end):
    i = text.index(start) + len(start)
    j = text.index(end, i)
    return text[i:j].strip('\n')

en_features = between(owner, '[size=5]• Description[/size][/b]\n', '[b][size=5][b]•[/b]  Installation instructions[/size][/b]')
en_install = between(owner, '[b][size=5][b]•[/b]  Installation instructions[/size][/b]\n', '[size=4][b]Main features[/b][/size]')
ru_features = between(owner, '[size=5][b]• Описание[/b][/size][/color]\n', '[b][size=5]•  Инструкция по установке[/size] [/b]')
ru_install = owner[owner.index('[b][size=5]•  Инструкция по установке[/size] [/b]') + len('[b][size=5]•  Инструкция по установке[/size] [/b]'):].strip('\n')
ru_install = f'[color={C}]' + ru_install + '[/color]'

# --- pack contents from the README tables --------------------------------------------------------
ROW = re.compile(r'^\| (\d+) \| \[(.+?)\]\((.+?)\)(<br><sub>KRINIK MODIFIED</sub>)? \| (.+?) \| (.+?) \|$')
def rows(lang_start, lang_end):
    part = readme[readme.index(lang_start):readme.index(lang_end) if lang_end else None]
    out = []
    for line in part.splitlines():
        m = ROW.match(line)
        if m:
            n, name, link, mod, author, what = m.groups()
            if not link.startswith('http'):
                link = f'{REPO}/tree/main/{link}'
            out.append((name, link, bool(mod), author.replace('\\$', '$'), what.replace('\\$', '$')))
    return out

ru_rows = rows('## 2. Состав сборки', '## 3. Установка')
en_rows = rows('## 2. Contents of the pack', '## 3. Installation')
assert len(ru_rows) == len(en_rows) == 72, (len(ru_rows), len(en_rows))

def mod_list(rs):
    items = []
    for name, link, mod, author, what in rs:
        tag = f' [color={ACC}][size=2]KRINIK MODIFIED[/size][/color]' if mod else ''
        items.append(f'[*][b][url={link}]{name}[/url][/b] — [i]{author}[/i]{tag}\n[color={C}]{what}[/color]')
    return '[list=1]\n' + '\n'.join(items) + '\n[/list]'

def h(title):
    return f'[size=5][b]• {title}[/b][/size]'

def img(name):
    return f'[center][img]{RAW}/docs/nexus/{name}[/img][/center]'

def para(text):
    return f'[color={C}]{text}[/color]'

# --- texts ---------------------------------------------------------------------------------------
en_desc = ' '.join([
    'Krinik Mod Pack 0.9.0 turns [b][i]Conan Exiles Enhanced 3.0.1[/i][/b] into an old-school role-playing game in the spirit of [b][i]The Elder Scrolls IV: Oblivion[/i][/b].',
    'The pack brings together 7 mods by its author and 64 mods by other authors from the Steam Workshop and Nexus Mods, tuned to work together, with the UE4SS loader and a launcher.',
    'The camera stands behind the hero\'s back, the arrow flies along an arc to the aim point, and the hero grows up to level 10,000, running faster, jumping higher and shooting better with every level.',
    'The inventory and the hub pause the game, so loot can be sorted at leisure.',
    'The world is larger and more dangerous: new lands and dungeons, ambushes, night demons and undead, storms, heat and cold, and over 700 new NPCs.',
    'At home a settlement with its own daily routine waits for the hero, and on the road a party of up to a hundred followers marches with the hero.',
    'The base is run from all its chests at once, and thousands of decor items furnish it.',
    'The interface is reworked for readability and gets a HUD, a minimap, a damage meter and follower health bars.',
])
en_desc2 = ' '.join([
    '[b]The pack is made for the Russian version of the game:[/b] every mod is translated into Russian, and the pack switches the game to Russian.',
    'The launcher installs, launches and removes the pack, and the «Отзыв» (Feedback) button in the game menu collects a report for the author.',
    'Version 0.9.0 ships as the pack worked on 2 November 2026; what is not done yet is listed below and goes into 1.0.0.',
])
ru_desc = ' '.join([
    'Krinik Mod Pack 0.9.0 превращает [b][i]Conan Exiles Enhanced 3.0.1[/i][/b] в ролевую игру старой школы в духе [b][i]The Elder Scrolls IV: Oblivion[/i][/b].',
    'Сборка объединяет 7 модов автора и 64 мода других авторов из Мастерской Steam и с Nexus Mods, загрузчик UE4SS и лаунчер; моды подогнаны друг к другу.',
    'Камера стоит за спиной героя, стрела летит по дуге в точку прицела, а герой растёт до 10 000 уровня и с каждым уровнем бегает быстрее, прыгает выше и лучше стреляет.',
    'В инвентаре и хабе игра встаёт на паузу, и добычу можно разобрать спокойно.',
    'Мир стал больше и опаснее: новые земли и подземелья, засады, ночные демоны и нежить, бури, жара и холод, более 700 новых неигровых персонажей.',
    'Дома героя ждёт поселение со своим распорядком дня, а в походе с ним идёт отряд до сотни спутников.',
    'Хозяйство базы игрок ведёт из всех её сундуков сразу, а обставить дом помогают тысячи предметов декора.',
    'Интерфейс переработан для читаемости, в нём появились HUD, мини-карта, счётчик урона и полоски здоровья спутников.',
])
ru_desc2 = ' '.join([
    '[b]Сборка сделана для русской версии игры:[/b] все моды в ней переведены на русский язык, а при установке игра переключается на русский.',
    'Лаунчер ставит, запускает и удаляет сборку, а кнопка «Отзыв» в меню игры собирает отчёт для автора.',
    'Версия 0.9.0 выходит в том виде, в каком сборка работала 2 ноября 2026 года; что пока не доделано, перечислено ниже, и всё это войдёт в 1.0.0.',
])

en_contents_intro = 'The pack holds 7 mods by its author, the UE4SS loader and 64 mods by other authors. [color=' + ACC + ']KRINIK MODIFIED[/color] marks mods by other authors that were changed for the pack: Russian translation, interface fixes, bug fixes. Every name links to the mod\'s page.'
ru_contents_intro = 'В сборку входят 7 модов её автора, загрузчик UE4SS и 64 мода других авторов. Знаком [color=' + ACC + ']KRINIK MODIFIED[/color] отмечены моды других авторов с доработками для сборки: перевод на русский язык, исправления интерфейса и ошибок. Каждое название ведёт на страницу мода.'

en_req = f'''[list]
[*][b]Conan Exiles Enhanced 3.0.1[/b] (build CL-379176).
[*][url=https://www.7-zip.org/]7-Zip[/url] or [url=https://www.win-rar.com/]WinRAR[/url] to unpack the multi-part archive.
[*]Free disk space: 12.7 GB for the archive parts and as much again for the unpacked pack.
[*]Nothing else: every mod and the UE4SS loader are inside the archive, no Steam Workshop subscriptions are needed.
[*]The pack switches the game to Russian and to fullscreen 3840 × 2160.
[/list]'''
ru_req = f'''[list]
[*][b]Conan Exiles Enhanced 3.0.1[/b] (билд CL-379176).
[*][url=https://www.7-zip.org/]7-Zip[/url] или [url=https://www.win-rar.com/]WinRAR[/url], чтобы распаковать многотомный архив.
[*]Место на диске: 12,7 ГБ под части архива и столько же под распакованную сборку.
[*]Больше ничего: все моды и загрузчик UE4SS лежат в архиве, подписываться на моды в Мастерской Steam не нужно.
[*]Сборка переключает игру на русский язык и полноэкранный режим 3840 × 2160.
[/list]'''

en_issues = [
    'Palm leaf shadows flicker.', 'Enemy health bars cover the enemies themselves.', 'At dusk the light and the sky sometimes change in a jump.',
    'The hub shakes when tabs are switched with Q and E, and some mod elements appear in it late.', 'The text on the menu tabs trembles slightly when switching.',
    'The quick loot window jerks when the mouse wheel is turned over it.',
    'In the settings windows of some mods the Russian text does not fit into buttons and fields: the magic school menu, the «Система аксессуаров» (Accessory system) window and others.',
    'Perk descriptions under an attribute on the «Хар-ки» (Attributes) tab overlap in places.',
    'Class names and descriptions on the Enhanced Armory and Arsenal cards stay in English: the text is painted into the images.',
    'In the Simple Minimap marker tutorial the lines appear with a long delay, and the slide area stays black.',
]
en_plans = [
    'Fix every issue in the list above.', 'Teach the hero to jump off a wall the hero is climbing.',
    'The «Моды Xevyr\'а» (Xevyr\'s mods) entry in the «Настройки модов» (Mod settings) list will open one window with the settings of all Xevyr\'s mods.',
    'Check every window of the pack at 720p, 1080p, 2K and 4K.', 'Measure how much the pack\'s mods load the game in combat and on the road.',
    'Check that a long play session runs without crashes.',
]
ru_issues = [
    'Тени от листьев пальм мерцают.', 'Полоски здоровья врагов закрывают самих врагов.', 'В сумерках свет и небо иногда меняются скачком.',
    'Хаб вздрагивает при переключении вкладок клавишами Q и E, и часть элементов модов появляется в нём с задержкой.', 'Текст на вкладках меню слегка дрожит при переключении.',
    'Окно быстрой добычи дёргается, если над ним крутить колесо мыши.',
    'В окнах настроек некоторых модов русский текст не помещается в кнопки и поля: в меню школы магии, в окне «Система аксессуаров» и других.',
    'Описания перков под атрибутом на вкладке «Хар-ки» местами наползают друг на друга.',
    'Названия и описания классов на карточках Enhanced Armory and Arsenal остались английскими: текст нарисован прямо на картинках.',
    'В обучении маркерам Simple Minimap строки появляются с большой задержкой, а место под слайды остаётся чёрным.',
]
ru_plans = [
    'Исправить каждую проблему из списка выше.', 'Научить героя прыгать со стены, по которой он лезет.',
    'Пункт «Моды Xevyr\'а» в списке «Настройки модов» будет открывать общее окно с настройками всех модов Xevyr\'а.',
    'Проверить каждое окно сборки в разрешениях 720p, 1080p, 2K и 4K.', 'Замерить, насколько моды сборки нагружают игру в бою и в пути.',
    'Проверить, что долгая игра идёт без вылетов.',
]
def blist(items):
    return '[list]\n' + '\n'.join(f'[*][color={C}]{x}[/color]' for x in items) + '\n[/list]'

en_shout = para(' '.join([
    'Thanks to every author whose mod is in the pack: their names and pages are in the Pack contents list above, and the pack stands on their work.',
    'Thanks to Narknon and the [url=https://github.com/UE4SS-RE/RE-UE4SS]UE4SS-RE[/url] team for the Lua mod loader.',
    'Thanks to Taurin78 for the hint that made items pick up at any camera distance.',
    'Thanks to Funcom for Conan Exiles, and to [i]The Elder Scrolls IV: Oblivion[/i], whose camera and archery inspired the pack.',
]))
ru_shout = para(' '.join([
    'Спасибо каждому автору, чей мод вошёл в сборку: их имена и страницы — в разделе «Состав сборки» выше, и сборка держится на их труде.',
    'Спасибо Narknon и команде [url=https://github.com/UE4SS-RE/RE-UE4SS]UE4SS-RE[/url] за загрузчик Lua-модов.',
    'Спасибо Taurin78 за подсказку, после которой предметы поднимаются при любом отдалении камеры.',
    'Спасибо Funcom за Conan Exiles и [i]The Elder Scrolls IV: Oblivion[/i], чьи камера и стрельба из лука вдохновили сборку.',
]))

def links(lang):
    if lang == 'en':
        rows_ = [('Public repository of the pack on GitHub', REPO, 'github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack'),
                 ('Release 0.9.0 on GitHub', f'{REPO}/releases/tag/v0.9.0', 'releases/tag/v0.9.0'),
                 ('User guide (PDF, in Russian)', f'{REPO}/blob/main/docs/guide/Krinik-Conan-3.1.1-guide.pdf', 'Krinik-Conan-3.1.1-guide.pdf'),
                 ('Email', 'mailto:kotkrinik@yandex.ru', 'kotkrinik@yandex.ru'),
                 ('Pack page on Nexus Mods', 'https://www.nexusmods.com/conanexilesenhanced/mods/65', 'nexusmods.com/conanexilesenhanced/mods/65')]
    else:
        rows_ = [('Публичный репозиторий сборки на GitHub', REPO, 'github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack'),
                 ('Выпуск 0.9.0 на GitHub', f'{REPO}/releases/tag/v0.9.0', 'releases/tag/v0.9.0'),
                 ('Руководство пользователя (PDF)', f'{REPO}/blob/main/docs/guide/Krinik-Conan-3.1.1-guide.pdf', 'Krinik-Conan-3.1.1-guide.pdf'),
                 ('Почта', 'mailto:kotkrinik@yandex.ru', 'kotkrinik@yandex.ru'),
                 ('Страница сборки на Nexus Mods', 'https://www.nexusmods.com/conanexilesenhanced/mods/65', 'nexusmods.com/conanexilesenhanced/mods/65')]
    # Почта — простым текстом: тега [email] Nexus не знает и печатает его как есть, а свой [url=mailto:] его визуальный редактор переписывает в [email]
    # (кадр владельца 2026-11-20 14:44: «Email: [email=…]…[/email]» на живой странице 0.9.0). [NOT-TESTED]
    cell = lambda u, t: t if u.startswith('mailto:') else f'[url={u}]{t}[/url]'
    return '[list]\n' + '\n'.join(f'[*][color={C}]{a}:[/color] {cell(u, t)}' for a, u, t in rows_) + '\n[/list]'

en_rights = para('Mods by other authors belong to their authors on the Steam Workshop and Nexus Mods; a mod marked KRINIK MODIFIED stays its author\'s property. Conan Exiles belongs to Funcom. The work of the pack author — the choice and order of mods, the settings, the translation, the Krinik mods and the launcher — is under the MIT license.')
ru_rights = para('Моды других авторов принадлежат их авторам в Мастерской Steam и на Nexus Mods; мод с пометкой KRINIK MODIFIED остаётся собственностью своего автора. Conan Exiles принадлежит Funcom. Работа автора сборки — подбор и порядок модов, настройки, перевод, моды Krinik и лаунчер — выпущена под лицензией MIT.')

parts = [
    f'[center][img]{RAW}/art/logos/krinik-modpack-logo.webp[/img][/center]',
    f'[center][size=4][b][i]Krinik Mod Pack 0.9.0 · Conan Exiles Enhanced 3.0.1[/i][/b][/size][/center]',
    f'[center][color={C}]English below · Русский текст — после английского[/color][/center]',
    '[line]',
    '[size=6][b]EN[/b][/size]', '',
    h('Description'), '', para(en_desc), '', para(en_desc2), '',
    img('hero_oasis_0_9_0.webp'), '',
    h('Main features'), '', en_features, '',
    img('cover_0_9_0.webp'), '',
    h('Pack contents'), '', para(en_contents_intro), '',
    '[spoiler]\n' + mod_list(en_rows) + '\n[/spoiler]', '',
    h('Requirements'), '', en_req, '',
    h('Installation instructions'), '', en_install, '',
    img('guide_title_page_0_9_0.webp'), '',
    h('Known issues and plans for 1.0.0'), '',
    '[spoiler]\n[b]Known issues[/b]\n' + blist(en_issues) + '\n[b]Plans for 1.0.0[/b]\n' + blist(en_plans) + '\n[/spoiler]', '',
    h('Shout outs'), '', en_shout, '',
    h('Links'), '', links('en'), '', en_rights, '',
    '[line]',
    '[size=6][b]RU[/b][/size]', '',
    h('Описание'), '', para(ru_desc), '', para(ru_desc2), '',
    img('hero_oasis_0_9_0.webp'), '',
    h('Основные возможности'), '', ru_features, '',
    img('cover_0_9_0.webp'), '',
    h('Состав сборки'), '', para(ru_contents_intro), '',
    '[spoiler]\n' + mod_list(ru_rows) + '\n[/spoiler]', '',
    h('Требования'), '', ru_req, '',
    h('Инструкция по установке'), '', ru_install, '',
    img('guide_title_page_0_9_0.webp'), '',
    h('Известные проблемы и планы на 1.0.0'), '',
    '[spoiler]\n[b]Известные проблемы[/b]\n' + blist(ru_issues) + '\n[b]Планы на 1.0.0[/b]\n' + blist(ru_plans) + '\n[/spoiler]', '',
    h('Благодарности'), '', ru_shout, '',
    h('Ссылки'), '', links('ru'), '', ru_rights,
]
bb = '\n'.join(parts) + '\n'
open(OUT, 'w', encoding='utf-8', newline='\n').write(bb)
print('chars', len(bb), 'rows', len(en_rows))
