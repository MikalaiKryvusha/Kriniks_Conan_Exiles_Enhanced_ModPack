"""caption.py -- bake the two-language caption into every frame of the series.

The look lives in sign_style.py (measured off the old run, plus the owner's
three corrections). This file holds only WHAT IS SAID and on which frame.

THE WORDS ARE WRITTEN FROM THE FRAME, NOT FROM THE SETTINGS TABLE. Each one
was checked against the picture it sits on: the series was opened and looked
at frame by frame before a single line was written. That order is the whole
lesson of the previous run, where three identical frames carried three
different captions and the captions were what lied.

Each language is written from the MEANING, not translated across: an English
line assembled out of the Russian one reads like a translation, and the
owner's storefront rule bans exactly that.

    python caption.py <src_dir> <dst_dir> [--style a|b|c]

        a  Russian headline in gold, English in white, both with their
           explaining line   (the default)
        b  both headlines white
        c  headlines only, no explaining lines

[NOT-TESTED] as to the WORDS: they are the owner's voice to approve, and they
are marked for his proofread in the plan. The rendering itself is verified by
opening the result.
"""

import os
import sys

from PIL import Image

import sign_style as st

# key: (russian headline, russian line, english headline, english line)
#
# SIX RULES THE OWNER GAVE FOR THESE WORDS (2026-09-10 and 11).
#
# 1. A caption says WHAT IS IN THE FRAME, as an assertion, strictly and
#    briefly. Not what the mod refuses to do, not what it lets you do.
# 2. EVERY CAPTION READS ON ITS OWN -- no "та же", no "ещё выше", and no
#    comparative category either: "предел", "дальний край диапазона", "средняя
#    дистанция" all need a neighbouring frame before they mean anything.
# 3. THE CAPTION EXPLAINS THE CAMERA'S STAGING: where the camera stands and
#    what that placement buys the shot.
# 4. IT SELLS THE RANGE, NOT THE LOCATION. No sand, no wreck, no shore: on
#    somebody else's map every one of those words is false.
# 5a. ENGLISH IS WRITTEN FIRST AND RUSSIAN IS ITS TRANSLATION, and the
#    translation is CHECKED against Google Translate rather than taken from
#    it: translate.py prints the three versions side by side. Running the
#    machine output straight onto the frames would ship "Дальний выстрел из
#    глубины" for "a long shot from well back" -- machine Russian is fluent
#    and loses the cinematographic terms, which is exactly what these captions
#    are made of. Three of its readings were better than mine and were taken. His words after
#    reading "олд-скульный третий лица": "ты пишешь русский текст как калька с
#    английского?". Composing both languages side by side let English grammar
#    leak into the Russian; writing the English line first and then rendering
#    it into Russian keeps each language its own.
# 5. THE REGISTER IS ACADEMIC, and each caption NAMES THE VIEW its staging
#    produces -- shot size and camera angle as a cinematographer would say
#    them: крупный / средний / общий / дальний план, прямой and верхний
#    ракурс, точка съёмки, кадрирование, изометрия.
# 6. AND WHERE A SHOT ANSWERS A NAMED REQUEST OF HIS, IT SAYS SO. The lifted
#    pivot exists because he asked for the camera of TES IV: Oblivion -- old
#    school third person -- and that is worth stating on the frame.
#
# Every line is written from BOTH sources at once: the frame, opened and
# looked at, and the row of shots.csv that produced it --
#
#     name               sideways  height  distance  tilt
#     02-behind                 0      65       190     0
#     03-closest                0      65        70     0
#     04-close-tilt             0      90        90   -10
#     05-normal-tilt            0      95       190   -10
#     06-lift-soft              0     110       220    -8
#     07-lift-mid               0     150       250   -12
#     08-lift-strong            0     190       280   -16
#     09-lift-tall              0     240       300   -20
#     10-shoulder-right        90      65       190    -6
#     11-shoulder-left        -90      65       190    -6
#     12-lift-shoulder         70     150       250   -12
#     13-far                    0     360       950    -6
#     14-panorama               0     480       950   -10
#     15-limit                  0     620      1000   -12
#
# -- and the numbers stay OUT of the caption (his earlier rule: no camera
# parameters on the frames; they live in shots.csv beside them).
CAPTIONS = {
    "01-vanilla": (
        "Ванильная камера — вид из-за плеча",
        "Классическая схема over-the-shoulder: камера смещена от оси персонажа, прицел в центре, фигура левее.",
        "Vanilla camera — over the shoulder",
        "The classic over-the-shoulder setup: the camera is offset from the character's axis, crosshair centred, figure to the left."),
    "02-behind": (
        "По оси, на уровне плеч",
        "Прямой ракурс с высоты плеч: ось персонажа совпадает с линией прицеливания.",
        "On the axis, at shoulder height",
        "An eye-level angle from shoulder height: the character's axis aligned with the aiming line."),
    "03-closest": (
        "Вплотную за спиной",
        "Крупный план со спины: фигура занимает кадр, глубина сжимается до переднего плана.",
        "Right up against the back",
        "A close shot from behind: the figure dominates and depth compresses to the near plane."),
    "04-close-tilt": (
        "Вплотную, верхний ракурс",
        "Крупный план с наклоном вниз: в кадр попадает земля под ногами.",
        "Close in, high angle",
        "A close shot on a downward angle: the footing enters the framing."),
    "05-normal-tilt": (
        "На оси, верхний ракурс",
        "Средний план с наклоном вниз: линия горизонта поднимается, земля занимает больше кадра.",
        "On the axis, high angle",
        "A medium shot on a downward angle: the horizon line rises, the ground's share grows."),
    "06-lift-soft": (
        "Камера над головой",
        "Небольшой верхний ракурс: фигура опускается ниже прицела, поле обзора расширяется.",
        "The camera above the head",
        "A shallow high angle: the figure drops below the crosshair and the field of view widens."),
    "07-lift-mid": (
        "Посадка как в TES IV: Oblivion",
        "Точка привязки поднята из груди выше головы — вид от третьего лица в духе старой школы.",
        "The TES IV: Oblivion seat",
        "The pivot is lifted out of the chest to above the head — the old-school third-person view."),
    "08-lift-strong": (
        "Высокая точка съёмки",
        "Выраженный верхний ракурс: кадр отдаёт горизонт ради рельефа.",
        "A high camera position",
        "A pronounced high angle: the framing trades the horizon for the terrain."),
    "09-lift-tall": (
        "Почти отвесный верхний ракурс",
        "Съёмка почти вертикально вниз: кадр приближается к изометрии, фигура читается как метка на плане.",
        "An almost vertical high angle",
        "Shooting nearly straight down: the frame approaches isometric, the figure reads as a marker on a plan."),
    "10-shoulder-right": (
        "Боковое смещение вправо",
        "Камера смещена вправо от оси: фигура уходит левее прицела, правая часть кадра открывается.",
        "Lateral offset to the right",
        "The camera is offset right of the axis: the figure moves left of the crosshair, the right side opens."),
    "11-shoulder-left": (
        "Боковое смещение влево",
        "Камера смещена влево от оси: фигура уходит правее прицела, открывается левая часть кадра.",
        "Lateral offset to the left",
        "The camera is offset left of the axis: the figure moves right of the crosshair, the left side opens."),
    "12-lift-shoulder": (
        "Подъём и боковое смещение",
        "Верхний ракурс вместе с боковым смещением: вид из-за плеча сверху, фигура ничего не закрывает.",
        "Lift and lateral offset",
        "A high angle combined with a lateral offset: an over-the-shoulder view from above, nothing blocked by the figure."),
    "13-far": (
        "Общий план издалека",
        "Дальняя точка съёмки с небольшим наклоном: постановочный общий план, фигура становится частью среды.",
        "A long shot from well back",
        "A distant camera at a shallow angle: an establishing long shot, the figure part of the setting."),
    "14-panorama": (
        "Панорама с верхней точки",
        "Дальний план с большой высоты: кадрирование классических ARPG — The Witcher, KOTOR.",
        "A panorama from a high position",
        "An extreme long shot from high up: the framing of the classic ARPG — The Witcher, KOTOR."),
    "15-limit": (
        "Вид с высоты птичьего полёта",
        "Высокая точка съёмки с большим отдалением: местность вокруг фигуры читается как план.",
        "A bird's-eye view",
        "A high camera with a long reach: the ground around the figure reads as a plan."),
}
# Название мода — то же, что стоит на логотипе.
MOD_NAME = "KRINIK CAMERA BEHIND"

STYLES = {"a": dict(gold=True, sublines=True),
          "b": dict(gold=False, sublines=True),
          "c": dict(gold=True, sublines=False)}


def _blocks(words, gold):
    ru_head, ru_sub, en_head, en_sub = words
    return [(ru_head, ru_sub, st.GOLD if gold else st.WHITE),
            (en_head, en_sub, st.WHITE)]


def series_plate(size, gold, sublines):
    """ONE plate for the whole series, sized by the longest caption.

    The plate used to hug each caption, and the captions differ in length, so
    it came out a different width on every frame — the owner called it a bug
    and he is right: a storefront reads as one series only if the plate does
    not breathe from picture to picture. It is measured over ALL of CAPTIONS,
    not over the frames present in this run, so the size does not shift when
    one frame is added or left out."""
    W, H = size
    return st.union([st.measure(W, H, _blocks(w, gold), sublines)
                     for w in CAPTIONS.values()])


def caption_one(src, dst, words, vanilla, gold, sublines, plate):
    im = Image.open(src).convert("RGB")
    accent = st.SOFT_RED          # владелец: черта сверху мягким красным
    blocks = _blocks(words, gold)

    # Название мода живёт ПОД той же плашкой, что и подпись. Бронза на песке
    # не читается никакой тенью — владелец сказал это дважды, — а тёмная
    # подложка решает то, чего тень не смогла. Плашка растёт только ВВЕРХ:
    # название короче подписи, ширина от этого не меняется.
    name_box = st.corner_box(im.size, MOD_NAME, above=plate)
    pad = int(im.size[1] * 0.012)
    full = (plate[0], min(plate[1], name_box[1] - pad), plate[2], plate[3])

    # ПЕРЕЕЗД В ПРАВЫЙ ВЕРХНИЙ УГОЛ, поверх миникарты (владелец, 2026-09-11).
    # Блок раскладывается там, где был задуман — внизу слева, — и целиком
    # переносится сдвигом. Считать раскладку заново для каждого угла значило бы
    # завести четыре способа перестать быть одной плашкой на всю серию.
    W, H = im.size
    dx = (W - int(W * st.LEFT_FRAC)) - full[2]
    dy = int(H * st.BOTTOM_FRAC) - full[1]
    off = (dx, dy)

    st.draw(im, blocks, accent=accent, sublines=sublines, plate=full, offset=off)
    # Название мода стоит ПРЯМО НАД плашкой описания (владелец, 2026-09-10):
    # название и подпись читаются одним блоком, а не двумя углами кадра. Что
    # кадр ванильный, говорит сама подпись, так что отдельной метки нет.
    st.corner(im, MOD_NAME, above=plate, on_plate=True, offset=off)
    im.save(dst, quality=95)


def main(argv):
    src_dir, dst_dir = argv[1], argv[2]
    style = argv[argv.index("--style") + 1] if "--style" in argv else "a"
    if style not in STYLES:
        print("стиль бывает a, b или c")
        return 2
    os.makedirs(dst_dir, exist_ok=True)

    frames = [n for n in sorted(os.listdir(src_dir))
              if n.lower().endswith(".png")
              and os.path.splitext(n)[0] in CAPTIONS]
    if not frames:
        print("в %s нет кадров, которым известна подпись" % src_dir)
        return 1
    with Image.open(os.path.join(src_dir, frames[0])) as probe:
        plate = series_plate(probe.size, **STYLES[style])
    print("плашка серии: %d x %d px (одна на все кадры)"
          % (plate[2] - plate[0], plate[3] - plate[1]))

    done = 0
    for name in frames:
        key = os.path.splitext(name)[0]
        caption_one(os.path.join(src_dir, name),
                    os.path.join(dst_dir, key + ".jpg"),
                    CAPTIONS[key], key.endswith("vanilla"),
                    plate=plate, **STYLES[style])
        print("подписан %s" % key)
        done += 1
    print("подписано кадров: %d (стиль %s)" % (done, style))
    return 0 if done else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
