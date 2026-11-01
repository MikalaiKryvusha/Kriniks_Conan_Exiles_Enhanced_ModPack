# make-intro.py — the build's intro shown while the game loads (KUMM plan 36 W26).
#   `[OWNER]` «на загрузке игры показывать этот логотип как вступительный интро ролик» · 2026-10-30 ≈09:3x;
#   reworked by `[OWNER]` «показываем оба лого - оригинальный и нашей сборки и показываем на все время загрузки игры, а внизу под ними в центре
#   крутим спинер прогресса медленно» · 2026-10-31 00:12.
#
#   python -X utf8 make-intro.py            → intro/KrinikIntro.mp4 (3840×2160, 30 fps, H.264, SECONDS long)
#
# What is on screen: black, the game's logo and ours side by side (the wallpapers' logo pair, make-wallpapers.py), a ring of dots under them
# whose bright head goes round once in SPIN_PERIOD seconds. The movie is LONG on purpose: it must outlast any load; the engine is to cut it when
# loading ends (bWaitForMoviesToComplete=False — KUMM researches/conan-intro-movie/README.md, the route under test).
#
# How it reaches the screen: the game's DefaultGame.ini has `+StartupMovies=` — ONE EMPTY entry, and the engine's WindowsMoviePlayer opens
# `Content/Movies/.mp4` at start; the pack installs this file AS `ConanSandbox/Content/Movies/.mp4` (manifest entry KrinikIntro).
# Correction 2026-10-31: an older line here said «a background frame does not catch video» — false (the white main menu in such frames was real,
# KUMM bug 71); whether a background frame catches the startup movie is simply untested.
# [NOT-TESTED]
import importlib.util
import math
import os
import subprocess
import tempfile

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("make_wallpapers", os.path.join(HERE, "make-wallpapers.py"))
wp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(wp)   # the logo pair lives once — in the wallpapers' composer

# 2026-10-31: the intro ships inside our mod KrinikConanModPackManager (the owner merged KrinikIntro into it).
OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "_unpacked", "KrinikConanModPackManager", "intro", "KrinikIntro.mp4")
W, H = 3840, 2160
FPS = 30
SECONDS = 150      # [AI] longer than any start seen on this machine (≈ 40 s to the menu, launch-bg.ps1) — the load is to cut it
FADE_IN = 0.6      # [AI] the first appearance only; the cut at the end is the engine's
LOGO_H = 0.20      # [AI] each logo's height, share of H — smaller than the wallpapers' 0.26: the frame holds the spinner too
LOGOS_CY = 0.44    # [AI] the logos' centre line, share of H
# The spinner — a wheel, not dots: `[OWNER]` «спинер загрузки сделать спокойнее, не точками, а колесо с крутящимся спокойным фейдом» · 2026-10-31 00:41
SPIN_CY = 0.74     # [AI] the wheel's centre, share of H
SPIN_R = 0.032     # [AI] the wheel's mid radius, share of H
SPIN_W = 0.0045    # [AI] the wheel's thickness, share of H
SPIN_PERIOD = 6.0  # [AI] seconds per turn — calm
SEGMENTS = 720     # [AI] arc pieces the wheel is drawn of (0.5° each — the tail reads as a smooth gradient, the front stays sharp)
# The colours: `[OWNER]` «спинер загрузки должен быть серый, и по нему бежит золотое кольцо в цвете конана с четким фронтом и фейдом на хвосте» · 01:12
WHEEL_GREY = (70, 70, 70)       # [AI] the grey wheel under the run
GOLD = (226, 178, 104)          # [AI] the Conan logo's gold (the bright bronze of its letters)
TAIL_DEG = 220.0   # [AI] the tail length behind the sharp front, degrees
TAIL_POW = 1.6     # [AI] the tail's fade: gold share = (1 − behind / TAIL_DEG) ** TAIL_POW
SS = 4             # supersampling of the wheel's crop — smooth edges


def logos():
    """The black frame with both logos — the wallpapers' pair: the game's left, ours right, one GAP apart."""
    frame = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    h = round(H * LOGO_H)
    g, p = wp.fit_h(wp.trimmed(wp.GAME_LOGO), h), wp.fit_h(wp.trimmed(wp.PACK_LOGO), h)
    gap = round(H * wp.GAP)
    x = (W - g.width - gap - p.width) // 2
    y = round(H * LOGOS_CY - h / 2)
    frame.alpha_composite(g, (x, y))
    frame.alpha_composite(p, (x + g.width + gap, y))
    return frame


def spinner(frame, t):
    """The wheel at time t: a grey ring; a gold run goes round clockwise from the top, one turn per SPIN_PERIOD — a sharp front, the tail fading
    back into grey over TAIL_DEG. Drawn on a supersampled crop (arc pieces, colour by the angle behind the front) and pasted down-scaled."""
    r, w = H * SPIN_R, H * SPIN_W
    half = int(r + w) + 2
    big = Image.new("RGBA", (2 * half * SS, 2 * half * SS), (0, 0, 0, 255))
    d = ImageDraw.Draw(big)
    c = half * SS
    box = (c - (r + w / 2) * SS, c - (r + w / 2) * SS, c + (r + w / 2) * SS, c + (r + w / 2) * SS)
    front = 360.0 * (t / SPIN_PERIOD) - 90.0   # degrees, PIL's 0° is to the right, clockwise
    step = 360.0 / SEGMENTS
    for i in range(SEGMENTS):
        a = i * step
        behind = (front - (a + step / 2)) % 360.0   # how far this piece trails the front; just ahead of the front → ≈ 360 → grey
        k = (1.0 - behind / TAIL_DEG) ** TAIL_POW if behind < TAIL_DEG else 0.0
        col = tuple(round(g * k + c0 * (1 - k)) for g, c0 in zip(GOLD, WHEEL_GREY))
        d.arc(box, a, a + step + 0.3, fill=col + (255,), width=round(w * SS))
    small = big.resize((2 * half, 2 * half), Image.LANCZOS)
    frame.paste(small, (round(W / 2) - half, round(H * SPIN_CY) - half))
    return frame


def main():
    base = logos()
    turn = round(SPIN_PERIOD * FPS)   # frames of one turn; ffmpeg loops them for SECONDS
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for n in range(turn):
            spinner(base.copy(), n / FPS).convert("RGB").save(os.path.join(tmp, "f%04d.jpg" % n), "JPEG", quality=95)
        vf = "fade=t=in:st=0:d=%s,format=yuv420p" % FADE_IN
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-loop", "1", "-i", os.path.join(tmp, "f%04d.jpg"),
                        "-t", str(SECONDS), "-vf", vf, "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-movflags", "+faststart", OUT],
                       check=True)
    print("%s %d bytes" % (OUT, os.path.getsize(OUT)))


if __name__ == "__main__":
    main()
