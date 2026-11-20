# attr_arrows_mockup.py — макет вида стрелок страниц и чисел отрезка у шкал атрибутов (KUMM plan 49, шаг 2, проход внешнего вида), поверх настоящего
# 4K-кадра «Хар-ки» из сборки: «Проворство» 26 уже на второй странице (полоса 6 из 20, значков нет — работающая механика), «Живучесть» 25 на первой.
#
# Зачем (2026-11-10): слова владельца 10:00–10:07 «у тебя в макете слева была цифра, от которой начинается, справа - на какой наканчивается текущий
# отрезок» · «и кнопочки стрелочки у тебя не налазили на шкалу» · «стрелки можно ниже шкалы по её краям, а цифры - выше» · «только нужен будет макет -
# красивые стрелки и красивые числа». Правило 23 HOUSE_RULES — статус у каждого элемента.
#   /c/Python314/python.exe -X utf8 attr_arrows_mockup.py <кадр 3840x2160> <папка вывода>
# Пишет 01_V1_…webp … 04_V4_…webp (WebP 90). Координаты сняты с кадра 2026-11-10 10:09.
# [NOT-TESTED]
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 2                                          # отрисовка вдвое крупнее и уменьшение — гладкие края
SERIF_B = "C:/Windows/Fonts/cambriab.ttf"       # засечки с кириллицей, близко к цифрам игры («26», «25»)
SANS_B = "C:/Windows/Fonts/segoeuib.ttf"
SANS = "C:/Windows/Fonts/segoeui.ttf"
GOLD = (222, 178, 102)
GOLD_HI = (255, 226, 160)
DARK = (20, 21, 24)
BAR_X0, BAR_X1 = 730, 2281                      # ромб «+» … правый конец шкалы
ROWS = [(762, 21, 40), (973, 1, 20)]            # (y шкалы, начало, конец): Проворство на 2-й странице, Живучесть на 1-й
PIP_X = 2275                                    # столбик значков на 20 (над и под шкалой, радиус ≈ 19)
NUM_DY, ARROW_DY = 58, 60                       # числа над шкалой, стрелки под ней — от линии шкалы
LEFT_X = BAR_X0 + 40                            # левый край: правее ромба «+»
RIGHT_X = PIP_X - 58                            # правый край: левее столбика значков на 20 (−44 — табличка V3 касалась верхнего значка)
LEGEND_H = 300
STATUS = {"ok": ("работает", (70, 160, 90)), "todo": ("нет механики — будет сделано", (205, 160, 40)),
          "idea": ("нет механики — предложение", (80, 130, 200))}


def f(path, size):
    return ImageFont.truetype(path, size * SS)


def S(v):
    return v * SS


def text_c(d, x, y, s, font, fill, anchor="mm", shadow=True):
    if shadow:
        d.text((S(x) + S(2), S(y) + S(3)), s, font=font, fill=(0, 0, 0, 200), anchor=anchor)
    d.text((S(x), S(y)), s, font=font, fill=fill, anchor=anchor)


def chevron(d, x, y, size, left, width, fill):
    h = size
    dx = -h * 0.55 if left else h * 0.55
    pts = [(S(x - dx), S(y - h)), (S(x + dx), S(y)), (S(x - dx), S(y + h))]
    d.line(pts, fill=fill, width=S(width), joint="curve")


def triangle(d, x, y, size, left, fill):
    w = size * 1.1
    # the eye centres a triangle by its centroid (w/6 toward the flat side from the box centre), not by its box — the owner 10:23 «стрелочки плохо центрированы»
    # 10:24 «чуть-чуть двигай стрелки в направлении, в котором они указывают» → w/4; 10:25 «еще двигай» → w/3; 10:26 «еще чуть-чуть» → 0.4 w;
    # 10:27 «хотя, нет, хватит трети, было хорошо на трети» → w/3 toward the tip — ACCEPTED
    x = x - w / 3 if left else x + w / 3
    if left:
        pts = [(S(x - w / 2), S(y)), (S(x + w / 2), S(y - size)), (S(x + w / 2), S(y + size))]
    else:
        pts = [(S(x + w / 2), S(y)), (S(x - w / 2), S(y - size)), (S(x - w / 2), S(y + size))]
    d.polygon(pts, fill=fill)


def diamond(d, x, y, r, outline, fill, width):
    pts = [(S(x), S(y - r)), (S(x + r), S(y)), (S(x), S(y + r)), (S(x - r), S(y))]
    d.polygon(pts, fill=fill, outline=outline, width=S(width))


# ---- four looks: each draws one row's arrows (under the ends) and numbers (over the ends)
def v1(d, glow, y, lo, hi):            # тонкие золотые шевроны, числа золотом с засечками
    fn = f(SERIF_B, 40)
    for x, s in ((LEFT_X, str(lo)), (RIGHT_X, str(hi))):
        text_c(d, x, y - NUM_DY, s, fn, GOLD + (255,))
    for x, left in ((LEFT_X, True), (RIGHT_X, False)):
        chevron(glow, x, y + ARROW_DY, 15, left, 7, GOLD_HI + (255,))
        chevron(d, x, y + ARROW_DY, 15, left, 5, GOLD + (255,))


def v2(d, glow, y, lo, hi):            # стрелки в ромбах, как «+» игры; числа светлые с засечками
    fn = f(SERIF_B, 38)
    for x, s in ((LEFT_X, str(lo)), (RIGHT_X, str(hi))):
        text_c(d, x, y - NUM_DY, s, fn, (236, 228, 210, 255))
    for x, left in ((LEFT_X, True), (RIGHT_X, False)):
        diamond(d, x, y + ARROW_DY + 4, 26, GOLD + (255,), (34, 30, 24, 235), 3)
        triangle(d, x, y + ARROW_DY + 4, 9, left, GOLD_HI + (255,))


def v3(d, glow, y, lo, hi):            # литые наконечники со свечением; числа в тёмной табличке
    fn = f(SERIF_B, 34)
    for x, s in ((LEFT_X, str(lo)), (RIGHT_X, str(hi))):
        w = 30 + 20 * len(s)
        d.rounded_rectangle((S(x - w / 2), S(y - NUM_DY - 24), S(x + w / 2), S(y - NUM_DY + 24)), radius=S(10),
                            fill=(18, 18, 20, 220), outline=GOLD + (200,), width=S(2))
        text_c(d, x, y - NUM_DY, s, fn, GOLD_HI + (255,), shadow=False)
    for x, left in ((LEFT_X, True), (RIGHT_X, False)):
        triangle(glow, x, y + ARROW_DY, 18, left, GOLD_HI + (255,))
        triangle(d, x, y + ARROW_DY, 14, left, GOLD + (255,))


def v4(d, glow, y, lo, hi):            # двойные шевроны «« »» помельче; числа как значения атрибутов (белые, с засечками)
    fn = f(SERIF_B, 40)
    for x, s in ((LEFT_X, str(lo)), (RIGHT_X, str(hi))):
        text_c(d, x, y - NUM_DY, s, fn, (245, 245, 245, 255))
    for x, left in ((LEFT_X, True), (RIGHT_X, False)):
        for k in (-9, 9):
            chevron(d, x + k, y + ARROW_DY, 12, left, 4, GOLD + (255,))


def v5(d, glow, y, lo, hi):            # the owner's pick 10:11 «стрелки давай как в 2, и в такого же стиля прямоугольники цифры»: V2 diamonds + numbers in
    fn = f(SERIF_B, 34)                 # rectangles of the same look (gold rim 3, the diamond's dark fill)
    for x, s in ((LEFT_X, str(lo)), (RIGHT_X, str(hi))):
        w = 34 + 20 * max(2, len(s))     # one width for «1» and «20» — a narrower box for one digit looked uneven (check 10:13)
        d.rectangle((S(x - w / 2), S(y - NUM_DY - 24), S(x + w / 2), S(y - NUM_DY + 22)), fill=(34, 30, 24, 235), outline=GOLD + (255,), width=S(3))
        text_c(d, x, y - NUM_DY - 1, s, fn, (236, 228, 210, 255), shadow=False)
    for x, left in ((LEFT_X, True), (RIGHT_X, False)):
        diamond(d, x, y + ARROW_DY + 4, 26, GOLD + (255,), (34, 30, 24, 235), 3)
        triangle(d, x, y + ARROW_DY + 4, 9, left, GOLD_HI + (255,))


CALM_RIM = (150, 122, 80, 175)          # the owner 10:13 «можно чуть спокойнее цвета для контейнеров цифр»: muted bronze, thinner, lower alpha
CALM_FILL = (22, 21, 20, 205)
CALM_TEXT = (218, 210, 194, 255)


VALUE_AT = {762: 26, 973: 25}            # the row's value: an arrow with nowhere to go is drawn DIM (the owner 10:13 «тусклое неактивное состояние для стрелки»)
DIM_RIM, DIM_FILL, DIM_TRI = (120, 108, 90, 95), (28, 27, 26, 150), (150, 140, 120, 85)


NUM_INSET, NUM_DY_CALM, NUM_RADIUS = 34, 46, 10   # the owner 10:16–10:17: numbers «чуть-чуть глубже внутрь» · «чуть чуть опустим к шкале» · left «правее и ниже» ·
                                                  # right «левее и ниже» · «вот такие закругленные уголки»


def v6(d, glow, y, lo, hi):            # V5 with calmer number boxes; the arrows' diamonds as in V5, dim when inactive
    fn = f(SERIF_B, 34)
    for x, s in ((LEFT_X + NUM_INSET, str(lo)), (RIGHT_X - NUM_INSET, str(hi))):
        w = 34 + 20 * max(2, len(s))
        d.rounded_rectangle((S(x - w / 2), S(y - NUM_DY_CALM - 24), S(x + w / 2), S(y - NUM_DY_CALM + 22)), radius=S(NUM_RADIUS), fill=CALM_FILL,
                            outline=CALM_RIM, width=S(2))
        text_c(d, x, y - NUM_DY_CALM - 1, s, fn, CALM_TEXT, shadow=False)
    value = VALUE_AT.get(y, hi)
    for x, left in ((LEFT_X, True), (RIGHT_X, False)):
        active = lo > 1 if left else value > hi
        if active:
            diamond(d, x, y + ARROW_DY + 4, 26, GOLD + (255,), (34, 30, 24, 235), 3)
            triangle(d, x, y + ARROW_DY + 4, 9, left, GOLD_HI + (255,))
        else:
            diamond(d, x, y + ARROW_DY + 4, 26, DIM_RIM, DIM_FILL, 2)
            triangle(d, x, y + ARROW_DY + 4, 9, left, DIM_TRI)


BRONZE = (198, 158, 102, 255)           # the owner 10:19 «всё же давай цифры как в v1» · «бронза, без контейнеров»


def v7(d, glow, y, lo, hi):            # V6's arrows (diamonds, dim when inactive) + V1's serif numbers in bronze, no boxes, at V6's places
    fn = f(SERIF_B, 40)
    for x, s in ((LEFT_X + NUM_INSET, str(lo)), (RIGHT_X - NUM_INSET, str(hi))):
        text_c(d, x, y - NUM_DY_CALM, s, fn, BRONZE)
    value = VALUE_AT.get(y, hi)
    for x, left in ((LEFT_X, True), (RIGHT_X, False)):
        if (lo > 1) if left else (value > hi):
            diamond(d, x, y + ARROW_DY + 4, 26, GOLD + (255,), (34, 30, 24, 235), 3)
            triangle(d, x, y + ARROW_DY + 4, 9, left, GOLD_HI + (255,))
        else:
            diamond(d, x, y + ARROW_DY + 4, 26, DIM_RIM, DIM_FILL, 2)
            triangle(d, x, y + ARROW_DY + 4, 9, left, DIM_TRI)


def v8(d, glow, y, lo, hi):            # the owner 10:20 «только положение цифр верни» · «и сделай их кегель больше»: V7 with V1's number places, a bigger size
    fn = f(SERIF_B, 50)
    lx = LEFT_X + LEFT_SHIFT_V8
    for x, s in ((lx, str(lo)), (RIGHT_X, str(hi))):
        text_c(d, x, y - NUM_DY, s, fn, BRONZE)
    value = VALUE_AT.get(y, hi)
    for x, left in ((LEFT_X, True), (RIGHT_X, False)):
        if (lo > 1) if left else (value > hi):
            diamond(d, x, y + ARROW_DY + 4, 26, GOLD + (255,), (34, 30, 24, 235), 3)
            triangle(d, x, y + ARROW_DY + 4, 9, left, GOLD_HI + (255,))
        else:
            diamond(d, x, y + ARROW_DY + 4, 26, DIM_RIM, DIM_FILL, 2)
            triangle(d, x, y + ARROW_DY + 4, 9, left, DIM_TRI)


LEFT_SHIFT_V8 = 18                      # the owner 10:21 «левые чуть-чуть дай правее» — the left NUMBER only (10:22 «кнопки левые подвигал - не нужно было, только цифры»)


VARIANTS = [("01_V1_tonkie_shevrony", "V1 — тонкие золотые шевроны, числа золотом", v1),
            ("02_V2_romby_kak_plus", "V2 — стрелки в ромбах, как «+» игры, числа светлые", v2),
            ("03_V3_nakonechniki_tablichki", "V3 — литые наконечники со свечением, числа в табличках", v3),
            ("04_V4_dvoynye_shevrony", "V4 — двойные шевроны, числа белые, как значения атрибутов", v4),
            ("05_V5_romby_i_pryamougolniki", "V5 — стрелки в ромбах, числа в прямоугольниках того же стиля", v5),
            ("06_V6_spokoynye_pryamougolniki", "V6 — как V5, рамки чисел спокойнее (приглушённая бронза)", v6),
            ("07_V7_bronzovye_chisla", "V7 — стрелки в ромбах (тусклая — неактивная), числа бронзой без рамок", v7),
            ("08_V8_bronza_krupnee", "V8 — как V7, числа на местах V1 и крупнее", v8)]
ONLY = os.environ.get("MOCK_ONLY")      # e.g. MOCK_ONLY=05 — draw one variant


def tag(d, x, y, key, size=30):
    text, col = STATUS[key]
    fn = ImageFont.truetype(SANS_B, size)
    w = d.textlength(text, font=fn)
    d.rounded_rectangle((x, y, x + w + 28, y + size + 18), radius=10, fill=col + (235,))
    d.text((x + 14, y + 6), text, font=fn, fill=(255, 255, 255, 255))
    return x + w + 28


def main(frame, out_dir):
    base = Image.open(frame).convert("RGB")
    W, H = base.size
    os.makedirs(out_dir, exist_ok=True)
    for name, title, draw in VARIANTS:
        if ONLY and not name.startswith(ONLY):
            continue
        layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        glow = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        d, g = ImageDraw.Draw(layer), ImageDraw.Draw(glow)
        for y, lo, hi in ROWS:
            draw(d, g, y, lo, hi)
        glow = glow.filter(ImageFilter.GaussianBlur(S(6)))
        over = Image.alpha_composite(glow, layer).resize((W, H), Image.LANCZOS)
        img = Image.new("RGB", (W, H + LEGEND_H), DARK)
        img.paste(base, (0, 0))
        img.paste(over, (0, 0), over)
        dd = ImageDraw.Draw(img, "RGBA")
        dd.text((60, H + 40), title, font=ImageFont.truetype(SANS_B, 64), fill=GOLD + (255,))
        dd.text((60, H + 140), "Стрелки — под шкалой у её краёв; числа — над шкалой: слева начало отрезка, справа его конец. «Проворство» на второй "
                "странице (21–40), «Живучесть» на первой (1–20).", font=ImageFont.truetype(SANS, 40), fill=(220, 220, 220, 255))
        x = tag(dd, 60, H + 210, "ok")
        dd.text((x + 16, H + 214), "стрелки листают, полоса и значки меняются", font=ImageFont.truetype(SANS, 36), fill=(200, 200, 200, 255))
        x = tag(dd, 1500, H + 210, "todo")
        dd.text((x + 16, H + 214), "этот вид стрелок и чисел", font=ImageFont.truetype(SANS, 36), fill=(200, 200, 200, 255))
        img.save(os.path.join(out_dir, name + ".webp"), "WEBP", quality=90)
        print("ok", name)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
