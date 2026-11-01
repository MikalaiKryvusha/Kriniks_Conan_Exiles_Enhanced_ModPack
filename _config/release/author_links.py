"""
Разбор author_links.txt — ссылок автора сборки. Один разбор на всех потребителей: ридми (путеводитель → PDF) и лаунчер.
Владелец сам докидывает строки в файл (2026-10-31 15:36: «я туда буду докидывать свои ссылки»), поэтому кривая строка
не пропускается молча, а останавливает сборку с номером строки: тихо потерянная ссылка хуже упавшей сборки.

Формат строки (слово владельца, дословно): "Текст до двоеточия"[OpenAI](https://openai.com)
Вид в ридми и лаунчере: «Текст до двоеточия: OpenAI», где OpenAI — ссылка на https://openai.com (разделитель — двоеточие, SEPARATOR ниже).
Короткий текст для лаунчера — необязательно, вторыми кавычками через черту: "Личные сообщения на PlayGround"|"PlayGround"[…](…):
ридми пишет длинный текст, лаунчер — короткий (владелец 2026-10-31 18:30 «просто плейграунд, без длинного текста» — о лаунчере).
[TESTED: 2026-10-31 · parse(author_links.txt): «Почта» without a short text, «PlayGround» with one; the guide keeps the long text]
"""
import re
import sys
from pathlib import Path

# Разделитель между текстом и ссылкой — двоеточие: «разделители двоеточием, а не точкой с запятой» (владелец 2026-10-31 16:11; до того «; » по его образцу 15:36).
SEPARATOR = ": "

# Кавычки — прямые, а также «ёлочки» и “лапки”: Word и телефон сами превращают прямые кавычки в типографские.
LINE = re.compile(r'^["«“„](?P<text>[^"»”“]+)["»”“](?:\|["«“„](?P<short>[^"»”“]+)["»”“])?\[(?P<label>[^\]]+)\]\((?P<url>[^)\s]+)\)$')
ALLOWED_SCHEMES = ("https://", "http://", "mailto:")


class LinksError(Exception):
    pass


def parse(path):
    """Список словарей {text, short, label, url} в порядке файла (short — текст для лаунчера, без него = text). Пустые строки и # — пропуск; кривая строка — LinksError."""
    links = []
    for n, raw in enumerate(Path(path).read_text(encoding="utf-8-sig").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = LINE.match(line)
        if not m:
            raise LinksError(f'{path}:{n}: строка не в формате "Текст"[Ссылка](адрес) или "Текст"|"Коротко"[Ссылка](адрес): {line}')
        url = m["url"]
        if not url.startswith(ALLOWED_SCHEMES):
            raise LinksError(f"{path}:{n}: адрес должен начинаться с https://, http:// или mailto: — {url}")
        text = m["text"].strip()
        links.append({"text": text, "short": (m["short"] or text).strip(), "label": m["label"].strip(), "url": url})
    if not links:
        raise LinksError(f"{path}: ни одной ссылки — раздел автора вышел бы пустым")
    return links


if __name__ == "__main__":
    # Ручная проверка файла: python _config/release/author_links.py author_links.txt
    try:
        for link in parse(sys.argv[1] if len(sys.argv) > 1 else "author_links.txt"):
            print(f'{link["text"]}{SEPARATOR}{link["label"]}  ->  {link["url"]}')
    except LinksError as e:
        print(e, file=sys.stderr)
        sys.exit(1)
