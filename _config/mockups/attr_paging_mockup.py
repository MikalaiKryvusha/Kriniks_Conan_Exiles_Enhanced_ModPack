# attr_paging_mockup.py — макет листания шкал атрибутов дальше 20 (KUMM plan 49, критерии 3–4) поверх настоящего 4K-кадра «Хар-ки».
#
# Зачем (2026-11-09): слово владельца 2026-11-07 22:02 «вот эти ряды навыков нужно научиться делать листаемыми, или скролл бар, или переключение
# "страницы шкалы"» и «списки с описанием перков нужно … переключать на следующую страницу в соответствие со станицей шкалы перков». Правило 23
# HOUSE_RULES: у каждого элемента макета — статус («работает» · «нет механики — будет сделано» · «нет механики — предложение»).
#   /c/Python314/python.exe -X utf8 attr_paging_mockup.py <кадр 3840x2160> <папка вывода>
# Пишет A_pages.webp и B_scroll.webp (WebP 90, без альфы). Координаты сняты с кадра 2026-11-09 19:17 (Проворство 26, Живучесть 25).
# [NOT-TESTED]
import os
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = "C:/Windows/Fonts/segoeui.ttf"
FONT_B = "C:/Windows/Fonts/segoeuib.ttf"
BAR_X0, BAR_X1 = 730, 2275                     # левый ромб «+» … правый конец шкалы
ROW_Y = [551, 762, 973, 1187, 1398, 1609]      # Сила, Проворство, Живучесть, Авторитет, Выдержка, Мастерство
VALUES = [0, 26, 25, 0, 0, 0]
PAGE = 20
PERK_BOX = (2650, 640, 3700, 2000)             # правая колонка описаний перков
PERK_TITLE_Y = 290                              # заголовок колонки («Сила») — закрывается вместе с ней в макете A
VALUE_TAG_X, VALUE_TAG_DY = 420, 80             # метка «работает» под числом ряда, не поверх него
LEGEND_H = 300
GOLD = (214, 168, 92)
DARK = (24, 26, 30)
STATUS = {
    "ok": ("работает", (70, 160, 90)),
    "todo": ("нет механики — будет сделано", (205, 160, 40)),
    "idea": ("нет механики — предложение", (80, 130, 200)),
}


def font(size, bold=False):
    return ImageFont.truetype(FONT_B if bold else FONT, size)


def tag(d, x, y, key, size=30):
    text, col = STATUS[key]
    f = font(size, True)
    w = d.textlength(text, font=f)
    d.rounded_rectangle((x, y, x + w + 28, y + size + 18), radius=10, fill=col + (235,))
    d.text((x + 14, y + 6), text, font=f, fill=(255, 255, 255, 255))
    return x + w + 28


def erase_bar(d, y):
    d.rectangle((BAR_X0 + 22, y - 62, BAR_X1 + 30, y + 62), fill=DARK + (255,))


def draw_page_bar(d, y, value, page):
    lo = page * PAGE + 1
    hi = (page + 1) * PAGE
    d.line((BAR_X0 + 30, y, BAR_X1, y), fill=(60, 60, 62, 255), width=8)
    filled = max(0, min(PAGE, value - page * PAGE))
    if filled:
        x = BAR_X0 + 30 + (BAR_X1 - BAR_X0 - 30) * filled / PAGE
        d.line((BAR_X0 + 30, y, x, y), fill=GOLD + (255,), width=8)
    for k in (5, 10, 15, 20):
        x = BAR_X0 + 30 + (BAR_X1 - BAR_X0 - 30) * k / PAGE
        d.ellipse((x - 20, y - 20, x + 20, y + 20), outline=(150, 150, 150, 255), width=3, fill=DARK + (255,))
        d.text((x - 9, y - 21), "?", font=font(30, True), fill=(150, 150, 150, 255))
    f = font(30)
    d.text((BAR_X0 + 34, y + 26), str(lo), font=f, fill=(200, 200, 200, 255))
    d.text((BAR_X1 - 34, y + 26), str(hi), font=f, fill=(200, 200, 200, 255))


def legend(img, title, lines):
    out = Image.new("RGB", (img.width, img.height + LEGEND_H), DARK)
    out.paste(img, (0, 0))
    d = ImageDraw.Draw(out, "RGBA")
    d.text((60, img.height + 30), title, font=font(64, True), fill=(240, 220, 170))
    y = img.height + 125
    for ln in lines:
        d.text((60, y), ln, font=font(40), fill=(220, 220, 220))
        y += 56
    x = 2600
    for key in ("ok", "todo", "idea"):
        tag(d, x, img.height + 40 + 70 * list(STATUS).index(key), key, 36)
    return out


def variant_a(base):
    img = base.copy()
    d = ImageDraw.Draw(img, "RGBA")
    cx = (BAR_X0 + BAR_X1) // 2
    # переключатель страниц над шкалами — один на все ряды; каждая надпись ставится отдельно, рамка — по её настоящей ширине
    d.rounded_rectangle((cx - 470, 410, cx + 470, 490), radius=14, fill=(40, 36, 30, 245), outline=GOLD + (255,), width=3)
    f = font(48, True)
    x = cx - 440
    for i, s in enumerate(["‹", "1–20", "21–40", "41–60", "›"]):
        w = d.textlength(s, font=f)
        d.text((x, 418), s, font=f, fill=(235, 225, 200, 255) if i != 2 else (255, 215, 130, 255))
        if i == 2:
            d.rounded_rectangle((x - 16, 420, x + w + 16, 482), radius=10, outline=(255, 210, 120, 255), width=4)
        x += w + 70
    tag(d, cx + 500, 425, "todo")
    for y, v in zip(ROW_Y, VALUES):
        erase_bar(d, y)
        draw_page_bar(d, y, v, 1)
    tag(d, BAR_X1 - 560, ROW_Y[1] - 118, "todo", 28)
    d.text((BAR_X1 - 1100, ROW_Y[1] - 112), "шкала на странице 21–40:", font=font(30), fill=(230, 230, 230, 255))
    tag(d, BAR_X0 + 60, ROW_Y[5] + 70, "idea", 28)
    d.text((BAR_X0 + 560, ROW_Y[5] + 76), "«?» — узлы перков выше 20: перков пока нет", font=font(30), fill=(230, 230, 230, 255))
    tag(d, VALUE_TAG_X, ROW_Y[1] + VALUE_TAG_DY, "ok", 26)
    # колонка перков — та же страница; закрываем и её старый заголовок «Сила»
    x0, y0, x1, y1 = PERK_BOX
    y0 = PERK_TITLE_Y
    d.rectangle((x0, y0, x1, y1), fill=DARK + (250,))
    d.text((x0 + 30, y0 + 20), "Проворство · 21–40", font=font(52, True), fill=(240, 220, 170, 255))
    d.text((x0 + 30, y0 + 110), "На этой странице перков пока нет.", font=font(40), fill=(220, 220, 220, 255))
    d.text((x0 + 30, y0 + 165), "Сюда встанут новые перки уровней", font=font(40), fill=(220, 220, 220, 255))
    d.text((x0 + 30, y0 + 220), "выше 20 — по данным перков.", font=font(40), fill=(220, 220, 220, 255))
    tag(d, x0 + 30, y0 + 300, "todo", 28)
    d.text((x0 + 30, y0 + 360), "колонка листается вместе со шкалой", font=font(32), fill=(200, 200, 200, 255))
    return legend(img, "Макет A — страницы шкалы (все ряды листаются вместе)", [
        "Над шкалами — переключатель страниц 1–20 · 21–40 · 41–60: стрелки, щелчок по странице или колесо мыши над шкалами.",
        "На странице 21–40 полоска считает очки сверх 20: Проворство 26 — заполнено 6 из 20, Живучесть 25 — 5 из 20.",
        "Правая колонка показывает перки той же страницы; пока перков выше 20 нет — пустая страница с пояснением.",
    ])


def variant_b(base):
    img = base.copy()
    d = ImageDraw.Draw(img, "RGBA")
    for y, v in zip(ROW_Y, VALUES):
        # длина ряда — до конца страницы, где стоит значение; ряд на 0…20 листать некуда — прокрутки нет
        total = max(PAGE, ((v + PAGE - 1) // PAGE) * PAGE)
        if total <= PAGE:
            continue
        sy = y + 48
        d.rounded_rectangle((BAR_X0 + 30, sy, BAR_X1, sy + 12), radius=6, fill=(70, 70, 72, 230))
        w = (BAR_X1 - BAR_X0 - 30) * PAGE / total
        d.rounded_rectangle((BAR_X0 + 30, sy, BAR_X0 + 30 + w, sy + 12), radius=6, fill=GOLD + (255,))
        d.text((BAR_X1 + 40, y - 20), "›", font=font(60, True), fill=(235, 225, 200, 255))
        d.text((BAR_X0 - 70, y - 20), "‹", font=font(60, True), fill=(120, 120, 120, 255))
    tag(d, BAR_X0 + 60, ROW_Y[1] + 66, "todo", 28)
    d.text((BAR_X0 + 560, ROW_Y[1] + 72), "полоса прокрутки под шкалой: видны 1–20 из 1–40", font=font(30), fill=(230, 230, 230, 255))
    tag(d, VALUE_TAG_X, ROW_Y[1] + VALUE_TAG_DY, "ok", 26)
    x0, y0, x1, y1 = PERK_BOX
    # верх плашки — ниже последней строки «Кровожадного берсерка» (≈ 1750 px), иначе плашка режет строку пополам
    d.rectangle((x0 - 10, y1 - 225, x1, y1), fill=DARK + (250,))
    d.text((x0 + 20, y1 - 200), "Колонка перков листается за шкалой", font=font(40, True), fill=(240, 220, 170, 255))
    tag(d, x0 + 20, y1 - 130, "todo", 28)
    return legend(img, "Макет B — прокрутка каждого ряда отдельно", [
        "У ряда с очками выше 20 — полоса прокрутки; колесо мыши или стрелки ‹ › сдвигают окно на 20.",
        "Ряды листаются независимо: Проворство можно смотреть на 21–40, а Силу — на 1–20.",
        "Колонка перков справа показывает то окно, которое открыто у выбранного ряда.",
    ])


AGI = 1   # индекс ряда «Проворство» (26 очков) — на нём показан сдвиг окна в вариантах B2–B4


def draw_window_bar(d, y, lo, value):
    # Окно шкалы lo … lo+19: заполнено до значения; узлы настоящих перков (5, 10, 15, 20) — золотые, выше 20 — «?» (перков пока нет)
    hi = lo + PAGE - 1
    span = BAR_X1 - BAR_X0 - 30
    d.line((BAR_X0 + 30, y, BAR_X1, y), fill=(60, 60, 62, 255), width=8)
    filled = max(0, min(PAGE, value - lo + 1))
    if filled:
        d.line((BAR_X0 + 30, y, BAR_X0 + 30 + span * filled / PAGE, y), fill=GOLD + (255,), width=8)
    for k in range(lo, hi + 1):
        if k % 5:
            continue
        x = BAR_X0 + 30 + span * (k - lo + 1) / PAGE
        if k <= 20:
            d.ellipse((x - 20, y - 20, x + 20, y + 20), outline=GOLD + (255,), width=4, fill=(60, 45, 25, 255))
        else:
            d.ellipse((x - 20, y - 20, x + 20, y + 20), outline=(150, 150, 150, 255), width=3, fill=DARK + (255,))
            d.text((x - 9, y - 21), "?", font=font(30, True), fill=(150, 150, 150, 255))
    f = font(30)
    d.text((BAR_X0 + 34, y + 26), str(lo), font=f, fill=(200, 200, 200, 255))
    d.text((BAR_X1 - 40, y + 26), str(hi), font=f, fill=(200, 200, 200, 255))


def perk_note(d, title, lines):
    x0, y0, x1, y1 = PERK_BOX
    y0 = PERK_TITLE_Y
    d.rectangle((x0, y0, x1, y1), fill=DARK + (250,))
    d.text((x0 + 30, y0 + 20), title, font=font(52, True), fill=(240, 220, 170, 255))
    y = y0 + 110
    for ln in lines:
        d.text((x0 + 30, y), ln, font=font(40), fill=(220, 220, 220, 255))
        y += 55
    tag(d, x0 + 30, y + 25, "todo", 28)
    d.text((x0 + 30, y + 85), "колонка — окно выбранного ряда", font=font(32), fill=(200, 200, 200, 255))


def b2_arrows(base):
    img = base.copy()
    d = ImageDraw.Draw(img, "RGBA")
    # стрелки — у КАЖДОГО ряда выше 20 (Проворство открыто на 21–40, Живучесть — на 1–20); светлая стрелка — куда ещё можно листать
    lit, dim = (235, 225, 200, 255), (120, 120, 120, 255)
    for i, (yy, v) in enumerate(zip(ROW_Y, VALUES)):
        if v <= PAGE:
            continue
        second = i == AGI
        if second:
            erase_bar(d, yy)
            draw_window_bar(d, yy, 21, v)
        d.text((BAR_X0 - 75, yy - 34), "‹", font=font(80, True), fill=lit if second else dim)
        d.text((BAR_X1 + 40, yy - 34), "›", font=font(80, True), fill=dim if second else lit)
        d.text((BAR_X1 - 260, yy - 95), "21–40" if second else "1–20", font=font(44, True), fill=(255, 215, 130, 255))
    y = ROW_Y[AGI]
    tag(d, BAR_X0 + 60, y - 112, "todo", 28)
    tag(d, VALUE_TAG_X, ROW_Y[AGI] + VALUE_TAG_DY, "ok", 26)
    perk_note(d, "Проворство · 21–40", ["На этой странице перков пока нет.", "Сюда встанут новые перки выше 20."])
    return legend(img, "Вариант B2 — стрелки по краям ряда", [
        "У ряда с очками выше 20 по краям шкалы — стрелки ‹ ›; над правым концом — открытое окно «21–40».",
        "Стрелка или колесо мыши над рядом листает на 20 очков; полосы прокрутки нет — экран чище.",
        "Проворство открыто на 21–40, остальные ряды — на своей первой странице.",
    ])


def b3_dots(base):
    img = base.copy()
    d = ImageDraw.Draw(img, "RGBA")
    for i, (y, v) in enumerate(zip(ROW_Y, VALUES)):
        pages = max(1, (v + PAGE - 1) // PAGE)
        if pages < 2:
            continue
        if i == AGI:
            erase_bar(d, y)
            draw_window_bar(d, y, 21, v)
        cur = 1 if i == AGI else 0
        # точки — под правым концом шкалы: справа от шкалы у Живучести стоит ромб порчи (первый макет налез на него)
        for p in range(pages):
            x = BAR_X1 - 130 - (pages - 1 - p) * 56   # левее подписи конца окна «40» (она стоит у BAR_X1 - 40)
            fill = (255, 215, 130, 255) if p == cur else (90, 90, 90, 255)
            d.ellipse((x - 18, y + 52 - 18, x + 18, y + 52 + 18), fill=fill)
    tag(d, BAR_X1 - 380, ROW_Y[AGI] - 112, "todo", 28)
    d.text((BAR_X1 - 900, ROW_Y[AGI] - 106), "точки страниц под концом шкалы:", font=font(30), fill=(230, 230, 230, 255))
    tag(d, VALUE_TAG_X, ROW_Y[AGI] + VALUE_TAG_DY, "ok", 26)
    perk_note(d, "Проворство · 21–40", ["На этой странице перков пока нет.", "Сюда встанут новые перки выше 20."])
    return legend(img, "Вариант B3 — точки страниц у ряда", [
        "Под концом шкалы — по точке на каждые 20 очков; светлая — открытая страница. Щелчок по точке открывает её.",
        "Точки растут с атрибутом: 26 очков — две точки, 41 — три. Колесо мыши над рядом тоже листает.",
        "Проворство открыто на 21–40 (вторая точка), Живучесть — на 1–20 (первая).",
    ])


def b4_running(base):
    img = base.copy()
    d = ImageDraw.Draw(img, "RGBA")
    # окно идёт за значением у каждого ряда выше 20: Проворство 26 → 7–26, Живучесть 25 → 6–25
    for yy, v in zip(ROW_Y, VALUES):
        if v > PAGE:
            erase_bar(d, yy)
            draw_window_bar(d, yy, v - PAGE + 1, v)
    y = ROW_Y[AGI]
    tag(d, BAR_X0 + 60, y - 112, "todo", 28)
    d.text((BAR_X0 + 560, y - 106), "окно 7–26: текущее значение у правого края", font=font(30), fill=(230, 230, 230, 255))
    tag(d, VALUE_TAG_X, ROW_Y[AGI] + VALUE_TAG_DY, "ok", 26)
    perk_note(d, "Проворство · 7–26", ["Видны перки 10, 15, 20", "и узел 25 — перков выше 20 пока нет."])
    return legend(img, "Вариант B4 — бегущая шкала", [
        "Шкала ряда — окно в 20 очков, которое само идёт за значением: при 26 очках видно 7–26.",
        "Колесо мыши над рядом двигает окно по одному очку, без скачков на 20; числа на концах — границы окна.",
        "Колонка перков показывает перки, попавшие в окно, — вместе старые и новые.",
    ])


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    base = Image.open(src).convert("RGB")
    if base.size != (3840, 2160):
        sys.exit("кадр %sx%s, нужен 3840x2160" % base.size)
    if len(sys.argv) > 3 and sys.argv[3] == "four":
        # слово владельца 2026-11-09 19:45 «давай прокрутка каждого ряда отдельно» · «4 варианта этой идеи»
        b1 = variant_b(base)
        for name, im in (("01_B1_polosa_prokrutki", b1), ("02_B2_strelki", b2_arrows(base)),
                         ("03_B3_tochki_stranic", b3_dots(base)), ("04_B4_begushchaya_shkala", b4_running(base))):
            im.save(os.path.join(out, name + ".webp"), "WEBP", quality=90)
    else:
        variant_a(base).save(os.path.join(out, "01_attr_pages_A.webp"), "WEBP", quality=90)
        variant_b(base).save(os.path.join(out, "01_attr_pages_B.webp"), "WEBP", quality=90)
    print("готово:", out)


if __name__ == "__main__":
    main()
