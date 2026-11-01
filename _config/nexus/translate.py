"""translate.py -- run the English captions through Google Translate.

WHY. The owner read "олд-скульный третий лица" and asked the obvious question:
"ты пишешь русский текст как калька с английского?". Composing both languages
side by side lets English grammar leak into the Russian. His instruction was
to write the English first and get the Russian from Google Translate.

THE ENDPOINT IS THE UNOFFICIAL ONE, and that is said out loud rather than
hidden: https://translate.googleapis.com/translate_a/single with client=gtx
needs no key and no token, is what the community libraries use, and carries
no support or guarantee. It is called here for a couple of dozen short lines,
once, by hand -- not on any hot path.

    python translate.py                 печатает сравнение в файл
    python translate.py --apply         кладёт машинный перевод в caption.py

WITHOUT --apply NOTHING IS WRITTEN. Machine Russian is a draft to be read by
the owner, not a decision: a translation that reads worse than the line it
replaces is not an improvement, and only he judges that.
"""

import io
import json
import sys
import time
import urllib.parse
import urllib.request

import caption as C

OUT = "perevod-sravnenie.md"


def translate(text, sl="en", tl="ru"):
    url = ("https://translate.googleapis.com/translate_a/single"
           "?client=gtx&sl=%s&tl=%s&dt=t&q=%s"
           % (sl, tl, urllib.parse.quote(text)))
    with urllib.request.urlopen(url, timeout=25) as r:
        data = json.loads(r.read().decode("utf-8"))
    return "".join(part[0] for part in data[0])


def main(argv):
    apply = "--apply" in argv
    rows = []
    for key in sorted(C.CAPTIONS):
        ru_h, ru_s, en_h, en_s = C.CAPTIONS[key]
        mt_h = translate(en_h)
        time.sleep(0.4)
        mt_s = translate(en_s)
        time.sleep(0.4)
        rows.append((key, en_h, en_s, ru_h, ru_s, mt_h, mt_s))
        print("переведён %s" % key)

    with io.open(OUT, "w", encoding="utf-8") as f:
        f.write("# Подписи: английский источник, мой русский, машинный русский\n\n")
        f.write("Машинный перевод получен через неофициальную точку Google "
                "Translate (client=gtx, без ключа).\n\n")
        for key, en_h, en_s, ru_h, ru_s, mt_h, mt_s in rows:
            f.write("## %s\n\n" % key)
            f.write("**EN** %s\n\n" % en_h)
            f.write("- мой   · %s\n" % ru_h)
            f.write("- гугл  · %s\n\n" % mt_h)
            f.write("**EN** %s\n\n" % en_s)
            f.write("- мой   · %s\n" % ru_s)
            f.write("- гугл  · %s\n\n" % mt_s)
    print("сравнение: %s" % OUT)

    if apply:
        src = io.open("caption.py", encoding="utf-8").read()
        for key, en_h, en_s, ru_h, ru_s, mt_h, mt_s in rows:
            src = src.replace('"%s",' % ru_h, '"%s",' % mt_h, 1)
            src = src.replace('"%s",' % ru_s, '"%s",' % mt_s, 1)
        io.open("caption.py", "w", encoding="utf-8").write(src)
        print("машинный перевод поставлен в caption.py")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
