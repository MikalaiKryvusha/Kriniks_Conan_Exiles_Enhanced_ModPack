# Пачки облётов эталона — очередь владельца 2026-10-26

Слово владельца: «Замеры ручек подгрузки: s.AsyncPostLoadEnabled, s.AsyncLoadingTimeLimit, s.PriorityAsyncLoadingExtraTime. Ветка
появления NPC: p.Chaos.EnableAsyncInitBody, цена ткани. Эталон на чистой игре без паков модов» · «можно начинать их грузить дальше по
дистанции, но больше кадров выделять. У меня много врам и рам». Разбор — KUMM `researches/conan-main-thread/README.md` §3–4, замеры —
`docs/18-бенч-облёт.md`.

Общий порядок одного запуска: замок машины → (ini до запуска, если нужно) → `launch-bg.ps1 -HoldSec 0` → `enter-world-remote.sh` →
проверить экран 3840×2160 → `bench-batch.sh <файл>` → `close-game.ps1` → (откат ini) → замок снять. Кино владельца — его слово
действует до обратного (KUMM `HOUSE_RULES.md` §1).

| Файл | Что | До запуска | После |
|---|---|---|---|
| `q1-runtime.txt` | бюджет подгрузки, пул текстур, ткань — меняются на лету | — | — |
| `q2-asyncpostload.txt` | доводка загруженных объектов в потоке загрузки | `python _config/ini-temp.py add <Saved/Config/Windows/Engine.ini> q2 s.AsyncPostLoadEnabled=1` | `ini-temp.py revert <ini> q2` |
| `q3-asyncinitbody.txt` | физические тела при появлении NPC — на рабочих потоках | `ini-temp.py add <ini> q3 p.Chaos.EnableAsyncInitBody=1 p.SkeletalMeshComponent.EnableAsyncInitBody=1` | `ini-temp.py revert <ini> q3` |
| `q4-vanilla.txt` | игра без паков модов (наши Lua-приборы остаются) | `ConanSandbox/Mods/modlist.txt` → `modlist.txt.off` (переименовать, не удалять) | вернуть имя |

Риски: `s.AsyncPostLoadEnabled` и `p.Chaos.EnableAsyncInitBody` — экспериментальные (гонки, зависания, падения) — в сборку владельца не
идут без A-B-A и получаса обычной игры; облёт без модов идёт по другому миру (нет пещер Caverns of Set и NPC модов) — сравнивать
итог, а не секунды.
