"""lua-globals.py — ловит в Lua-моде UE4SS имя, которое Lua молча прочтёт как nil.

Класс дефекта, оплаченный трижды (KUMM EXP-0051, EXP-0072, и 13.09.2026 пойман до запуска):
`local x` объявлен НИЖЕ места, где x используется, — и там это уже не локальная переменная,
а глобальное имя со значением nil. `luac -p` синтаксис пропускает, `pcall` глотает ошибку,
в журнале тишина. 13.09 в зонде атрибутов так выпали бы сразу три имени.

Проверка по байткоду: `luac -l` печатает каждое обращение к глобальному имени (GETTABUP/
SETTABUP _ENV "имя"). Всё, что не встроенное Lua и не API UE4SS из списка ниже, — дефект.

  python lua-globals.py <main.lua> [<ещё.lua> ...]      выход 1, если нашлись чужие имена
"""
import os
import re
import subprocess
import sys

LUAC = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Lua", "bin", "luac.exe")

LUA_BUILTINS = {
    "print", "pcall", "xpcall", "error", "assert", "type", "tostring", "tonumber", "ipairs",
    "pairs", "next", "select", "rawget", "rawset", "rawequal", "rawlen", "setmetatable",
    "getmetatable", "require", "load", "loadfile", "dofile", "collectgarbage",
    "string", "table", "math", "os", "io", "utf8", "coroutine", "debug", "package", "_G", "_VERSION",
}
# API UE4SS, которым пользуются моды этого пака. Новое имя — добавить сюда осознанно.
UE4SS_API = {
    "FindAllOf", "FindFirstOf", "StaticFindObject", "FindObject", "ExecuteInGameThread",
    "ExecuteWithDelay", "ExecuteAsync", "LoopAsync", "LoopInGameThreadWithDelay",
    "RegisterKeyBind", "RegisterKeyBindAsync", "IsKeyBindRegistered", "RegisterHook", "UnregisterHook",
    "NotifyOnNewObject", "RegisterCustomEvent", "RegisterConsoleCommandHandler",
    "RegisterConsoleCommandGlobalHandler", "RegisterLoadMapPreHook", "RegisterLoadMapPostHook",
    "RegisterInitGameStatePostHook", "RegisterBeginPlayPostHook", "RegisterProcessConsoleExecPreHook",
    "ModifierKey", "Key", "FName", "FText", "UEHelpers", "StaticConstructObject", "CreateInvalidObject",
    "IterateGameDirectories", "GetKismetSystemLibrary", "GetKismetMathLibrary",
    "LoopInGameThreadAfterFrames", "EngineTickAvailable",
}
ALLOWED = LUA_BUILTINS | UE4SS_API
PATTERN = re.compile(r'(?:GETTABUP|SETTABUP)\s.*?_ENV\s+"([A-Za-z_][A-Za-z0-9_]*)"')
# Намеренно глобальное имя объявляется в самом файле строкой `-- lua-globals: allow имя1 имя2` —
# осознанное исключение живёт рядом с кодом, а не в этом списке.
ALLOW_LINE = re.compile(r"--\s*lua-globals:\s*allow\s+([A-Za-z0-9_ ,]+)")


def audit(path: str) -> set[str]:
    out = subprocess.run([LUAC, "-l", "-p", path], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if out.returncode != 0:
        print(f"{path}: luac не принял файл\n{out.stderr.strip()}")
        return {"<синтаксис>"}
    local_allow = set()
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = ALLOW_LINE.search(line)
            if m:
                local_allow |= set(re.split(r"[ ,]+", m.group(1).strip()))
    return {m.group(1) for m in PATTERN.finditer(out.stdout)} - ALLOWED - local_allow


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    if not os.path.exists(LUAC):
        print(f"нет luac: {LUAC} — проверка НЕ выполнена")
        return 2
    bad = 0
    for p in sys.argv[1:]:
        unknown = audit(p)
        if unknown:
            bad += 1
            print(f"{p}: чужие глобальные имена (объявлены ниже использования или опечатка): {sorted(unknown)}")
        else:
            print(f"{p}: чисто")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
