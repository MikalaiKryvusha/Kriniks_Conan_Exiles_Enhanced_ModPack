# bench-sheets.py <папка> — листы кадров разведочного облёта: t###.jpg (номер — секунда полёта) по 24 на лист 6×4, webp.
# Зачем: маршрут правится по увиденному — «на какой секунде куда лететь» (слово владельца 2026-10-25 21:22), а секунда кадра
# сопоставляется со строкой `EV fly=prog t=<с>` журнала мода (prog.txt в той же папке).
# Перенесён в пак из черновика сессии 2026-10-25 (там им собраны листы разведок scout1..5), логика прежняя. [NOT-TESTED]
import glob, os, subprocess, sys

PER, COLS, CELL_W = 24, 6, 480
o = sys.argv[1]
files = sorted(glob.glob(os.path.join(o, "t*.jpg")))
for k in range(0, len(files), PER):
    part = files[k:k + PER]
    lst = os.path.join(o, "lst%02d.txt" % (k // PER))
    with open(lst, "w") as fh:
        for f in part:
            fh.write("file '%s'\n" % f.replace(os.sep, "/"))
    rows = (len(part) + COLS - 1) // COLS
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst,
                    "-vf", "scale=%d:-1,tile=%dx%d" % (CELL_W, COLS, rows), "-frames:v", "1",
                    os.path.join(o, "sheet%02d.webp" % (k // PER))])
    print("sheet%02d: %s .. %s" % (k // PER, os.path.basename(part[0]), os.path.basename(part[-1])))
