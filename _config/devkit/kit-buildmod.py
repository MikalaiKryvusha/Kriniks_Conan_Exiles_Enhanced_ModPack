# kit-buildmod.py — сборка мода китом Conan Exiles шаг в шаг как BuildMod.cs кита (UE4/Build/ModDevKit.Automation), но без UAT.
#
# Зачем (2026-10-27, KUMM план 36 п. 34 и 39b): `RunUAT BuildMod` кита падает «Failed to find command BuildMod» — модуль автоматизации
# пришёл собранной библиотекой без .csproj (собран у Funcom в C:\b\exiles), и UAT с -NoCompile его не находит («Found no script module
# records» — та самая публичная беда). Шаги BuildMod открыты в исходнике — здесь они же:
#   1. кук: UnrealEditor-Cmd -run=Cook -ModDevKit … -PackagesList (Windows + WindowsServer + LinuxServer);
#   2. свободный пак платформы: AssetRegistry.bin + ModCompat.bin (UnrealPak -CreateMultiple);
#   3. контейнер IoStore платформы: пакеты мода (UnrealPak -CreateDLCContainer);
#   4. обёртка <Мод>.pak: modinfo.json + manifest.json (MD5) + девять файлов платформ; игра читает паки V11 — если UnrealPak кита написал
#      другую версию, обёртка переупаковывается repak'ом V11 (как make-loc-mod.py).
#
#   python -I -X utf8 kit-buildmod.py <Мод> <вывод>
# Мод в ките: UE4/Content/Mods/<Мод>/ (modinfo.json, Local/CookInfo.ini, active.txt — активный). Пишет в Saved/Mods кита и в <вывод>.
# [NOT-TESTED]
import configparser
import hashlib
import json
import os
import shutil
import subprocess
import sys

KIT = r"F:\CEUE5Devkit"
BASE = os.path.join(KIT, "UE4")
PROJECT = "ConanSandbox"
UPROJECT = os.path.join(BASE, PROJECT + ".uproject")
EDITOR = os.path.join(KIT, r"Engine\Binaries\Win64\UnrealEditor-Cmd.exe")
UNREALPAK = os.path.join(KIT, r"Engine\Binaries\Win64\UnrealPak.exe")
REPAK = r"D:\work\ai_sandbox\_tools\repak\repak.exe"
PLATFORMS = ["Windows", "WindowsServer", "LinuxServer"]
EXTS = [".uasset", ".umap", ".ubulk", ".uptnl", ".m.ubulk", ".o.uasset", ".o.umap", ".o.ubulk"]
COMPRESS = ["-compressionformats=Oodle", "-compresslevel=7", "-compressmethod=Kraken", "-CompressionFormat=Oodle", "-OodleMethod=Kraken"]


def run(args, log=None):
    print(">", " ".join(args)[:300], flush=True)
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if log:
        open(log, "w", encoding="utf-8").write(r.stdout + "\n" + r.stderr)
    if r.returncode != 0:
        raise SystemExit("FAILED %d: %s\n%s" % (r.returncode, args[0], (r.stdout + r.stderr)[-3000:]))
    return r.stdout


def md5(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def file_to_package(x, mod):
    # FDWModDevKitModule::ModdedFileNameToPackageName (BuildMod.cs): Local/ — новый ассет мода, Mods/<мод>/Content/ — подмена родного
    x = x.replace("Local/", "", 1).replace("Mods/%s/Content/" % mod, "", 1)
    return "/Game/" + os.path.splitext(x)[0]


def main(mod, out_dir):
    mod_path = os.path.join(BASE, "Content", "Mods", mod)
    assert os.path.exists(os.path.join(mod_path, "active.txt")), "мод не активен в ките (active.txt)"
    ini = configparser.ConfigParser(strict=False, allow_no_value=True)
    lines = [l.strip() for l in open(os.path.join(mod_path, "Local", "CookInfo.ini"), encoding="utf-8")]
    files = [l.split("=", 1)[1] for l in lines if l.startswith("FilesToCook=")]
    packages = [file_to_package(f, mod) for f in files]
    print("packages:", packages)

    cooked = os.path.join(BASE, "Saved", "Mods", "_Cooked")
    build = os.path.join(BASE, "Saved", "Mods", mod)
    staged = os.path.join(build, "Staged")
    for d in (cooked, staged):
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(d)
    plist = os.path.join(cooked, "PackageList.txt")
    open(plist, "w", encoding="utf-8").write("\n".join(packages) + "\n")

    # 1. кук
    run([EDITOR, UPROJECT, "-run=Cook", "-OutputDir=%s/[Platform]/" % cooked, "-ModDevKit", "-NoAssetRegistryCache",
         "-TargetPlatform=" + "+".join(PLATFORMS), "-NoGameAlwaysCook", "-NoDefaultMaps", "-SkipSoftReferences", "-SkipHardReferences",
         "-SkipZenStore", "-ini:Game:[/Script/UnrealEd.ProjectPackagingSettings]:bGenerateNoChunks=True", "-PackagesList=" + plist,
         "-unattended", "-nopause", "-NullRHI", "-nosplash", "-stdout", "-abslog=" + os.path.join(build, "cook.log")],
        log=os.path.join(build, "cook-stdout.log"))
    found = {}
    for pkg in packages:
        found[pkg] = [pl for pl in PLATFORMS if any(os.path.exists(pkg.replace("/Game/", os.path.join(cooked, pl, PROJECT, "Content") + "/", 1) + e)
                                                    for e in EXTS)]
        print("cooked", pkg, found[pkg])
        assert found[pkg], "не скукан ни под одну платформу: " + pkg

    # Платформа без кука пропускается: на машине нет Linux SDK, кит LinuxServer не кукует (2026-10-27: «нет packagestore.manifest и
    # ue.projectstore у LinuxServer»); клиенту игры нужен Windows, в обёртку идут только собранные платформы.
    built = [pl for pl in PLATFORMS if any(pl in f for f in found.values())]
    print("platforms built:", built)
    for pl in built:
        cp = os.path.join(cooked, pl)
        content = os.path.join(cp, PROJECT, "Content")
        # 2. свободный пак: реестр и ModCompat
        pak_list = os.path.join(staged, pl + "-PakList.txt")
        cmds = os.path.join(staged, pl + "-Commands.txt")
        open(pak_list, "w", encoding="utf-8").write("\n".join([
            '"%s" "../../../ConanSandbox/Content/Mods/%s/AssetRegistry.bin"' % (os.path.join(cp, PROJECT, "AssetRegistry.bin"), mod),
            '"%s" "../../../ConanSandbox/Content/Mods/%s/ModCompat.bin"' % (os.path.join(cp, PROJECT, "ModCompat.bin"), mod)]) + "\n")
        open(cmds, "w", encoding="utf-8").write('"%s" -create="%s"\n' % (os.path.join(staged, "%s-%s.pak" % (mod, pl)), pak_list))
        run([UNREALPAK, staged, "-platform=" + pl, "-CreateMultiple=" + cmds] + COMPRESS)
        # 3. контейнер IoStore
        io_list = os.path.join(staged, pl + "-PakListIoStore.txt")
        io_cmds = os.path.join(staged, pl + "-CommandsIoStore.txt")
        entries = []
        for pkg in packages:
            if pl not in found[pkg]:
                continue
            disk = pkg.replace("/Game/", content.replace("\\", "/") + "/", 1)
            virt = pkg.replace("/Game/", "../../../%s/Content/" % PROJECT, 1)
            entries += ['"%s" "%s"' % (disk + e, virt + e) for e in EXTS if os.path.exists(disk + e)]
        if os.path.isdir(content):
            for fn in os.listdir(content):
                if fn.endswith(".ushaderbytecode") and "ShaderArchive-Global" not in fn:
                    new = fn.replace("ShaderArchive-%s-" % PROJECT, "ShaderArchive-%s-" % mod)
                    os.replace(os.path.join(content, fn), os.path.join(content, new))
                    info = fn.replace("ShaderArchive-", "ShaderAssetInfo-").replace(".ushaderbytecode", ".assetinfo.json")
                    if os.path.exists(os.path.join(content, info)):
                        os.replace(os.path.join(content, info), os.path.join(content, info.replace("-%s-" % PROJECT, "-%s-" % mod)))
                    entries.append('"%s" "../../../%s/Content/Mods/%s/%s"' % (os.path.join(content, new), PROJECT, mod, new))
        open(io_list, "w", encoding="utf-8").write("\n".join(entries) + "\n")
        open(io_cmds, "w", encoding="utf-8").write('-Output="%s" -ContainerName="%s-%s" -ResponseFile="%s"\n'
                                                   % (os.path.join(staged, "%s-%s" % (mod, pl)), mod, pl, io_list))
        args = [UNREALPAK, "-Project=" + UPROJECT, '-CreateDLCContainer=', "-CookedDirectory=" + cp, "-Commands=" + io_cmds,
                "-WriteBackMetadataToAssetRegistry=Disabled"] + COMPRESS
        store = os.path.join(cp, PROJECT, "Metadata", "packagestore.manifest")
        if os.path.exists(store):
            args += ["-PackageStoreManifest=" + store, "-ScriptObjects=" + os.path.join(cp, PROJECT, "Metadata", "scriptobjects.bin")]
        elif os.path.exists(os.path.join(cp, "ue.projectstore")):
            args += ["-ProjectStore=" + os.path.join(cp, "ue.projectstore")]
        else:
            raise SystemExit("нет packagestore.manifest и ue.projectstore у " + pl)
        run(args, log=os.path.join(build, "iostore-%s.log" % pl))

    # 4. обёртка
    manifest = {}
    for pl in built:
        for e in ("pak", "utoc", "ucas"):
            n = "%s-%s.%s" % (mod, pl, e)
            manifest[n] = md5(os.path.join(staged, n))
    shutil.copyfile(os.path.join(mod_path, "modinfo.json"), os.path.join(staged, "modinfo.json"))
    manifest["modinfo.json"] = md5(os.path.join(staged, "modinfo.json"))
    json.dump(manifest, open(os.path.join(staged, "manifest.json"), "w", encoding="utf-8"), indent=2)
    outer = os.path.join(build, "outer")
    shutil.rmtree(outer, ignore_errors=True)
    os.makedirs(outer)
    for n in list(manifest) + ["manifest.json"]:
        shutil.copyfile(os.path.join(staged, n), os.path.join(outer, n))
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, mod + ".pak")
    if os.path.exists(out):
        os.remove(out)
    run([REPAK, "pack", "--version", "V11", "--mount-point", "../../../ConanSandbox/Mods/", outer, out])
    print("OK", out, os.path.getsize(out))
    for pl in built:
        print(pl, run([REPAK, "info", os.path.join(staged, "%s-%s.pak" % (mod, pl))]).splitlines()[1:2])


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
