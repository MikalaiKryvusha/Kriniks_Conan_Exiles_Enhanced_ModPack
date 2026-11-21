# make-loc-mod.py - build a Conan Enhanced mod pak that OVERLAYS Russian strings onto a localization target.
#
# Что делает: берёт живой <Target>/ru/<Target>.locres игры (распакованный из pakchunk0 китовским UnrealPak),
# добавляет к нему записи из .locres, скомпилированного движком (GatherText), и собирает мод в том же виде,
# в каком его собирает BuildMod.cs кита: обёртка <Mod>.pak (без сжатия, точка монтирования
# ../../../ConanSandbox/Mods/) с modinfo.json, manifest.json (MD5 каждого файла) и внутренним
# <Mod>-Windows.pak, где наш locres лежит по ПУТИ ИГРЫ (../../../ConanSandbox/Content/Localization/<Target>/ru/).
# Контейнеров IoStore (.utoc/.ucas) в этом моде нет — в нём нет ассетов; живой мод SimpleModlist без
# ModCompat.bin монтируется («skipping compatibility check»), так что и этот файл не нужен.
#
# ПОЧЕМУ НЕ UnrealPak: UnrealPak кита 5.8 пишет пак ВЕРСИИ 12, а игра читает до 11 и падает с
# «Invalid pak file version (12)» (журнал 12.09.2026 08:21). Ключа версии у UnrealPak нет. Паки пишет
# repak (trumank, MIT, `_tools/repak/repak.exe`, sha256 сверен с релизом) с `--version V11`; UnrealPak
# остаётся читателем (-List) для контроля.
#
# Граница: пишет только в <out>; папку игры не трогает (раскатка — отдельный шаг).
# [NOT-TESTED]
import sys, os, json, hashlib, subprocess, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import locres
import repak_tool  # repak on one thread: the same folder packs into the same bytes (2026-11-21, the launcher's delta update, step 0)

UNREALPAK = r'F:\CEDevKit\CEUE5Devkit\Engine\Binaries\Win64\UnrealPak.exe'
REPAK = r'D:\work\ai_sandbox\_tools\repak\repak.exe'
PAK_VERSION = 'V11'   # the game's own paks and every live mod are version 11 (pakfooter check, 12.09)

def md5(p):
    h = hashlib.md5()
    with open(p, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace', env=repak_tool.env_for(cmd))
    if r.returncode != 0:
        raise SystemExit('FAILED (%d): %s\n%s\n%s' % (r.returncode, ' '.join(cmd), r.stdout[-1500:], r.stderr[-1500:]))
    return r.stdout

def repak_pack(src_dir, mount, out_pak):
    if os.path.exists(out_pak):
        os.remove(out_pak)
    run([REPAK, 'pack', '--version', PAK_VERSION, '-m', mount, '-q', src_dir, out_pak])
    assert os.path.exists(out_pak), 'repak produced nothing: ' + out_pak

def pak_version(p):
    import struct
    sz = os.path.getsize(p)
    with open(p, 'rb') as f:
        f.seek(max(0, sz - 4096)); tail = f.read()
    i = tail.rfind(bytes.fromhex('E1126F5A'))
    return struct.unpack_from('<i', tail, i + 4)[0] if i >= 0 else None

def unrealpak_list(p):
    out = run([UNREALPAK, p, '-List'])
    return [l.split('Display: ')[1] for l in out.splitlines() if 'LogPakFile: Display: "' in l or 'mount point' in l]

def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--mod', required=True, help='mod folder/pak name, e.g. HosavRU')
    ap.add_argument('--target', default='Exiles_UI', help='game localization target to overlay')
    ap.add_argument('--base', required=True, help="the GAME's ru/<Target>.locres (extracted from pakchunk0)")
    ap.add_argument('--overlay', required=True, help='engine-compiled ru/<Mod>.locres with the new entries')
    ap.add_argument('--out', required=True, help='output dir; <out>/<Mod>.pak is the result')
    ap.add_argument('--modinfo', required=True, help='modinfo.json to embed')
    ap.add_argument('--registry', default=None, help='AssetRegistry.bin to embed at Content/Mods/<Mod>/ (the game refuses a platform pak without one: ValidateMod_MissingAssetRegistry)')
    a = ap.parse_args()

    os.makedirs(a.out, exist_ok=True)
    staged = os.path.join(a.out, 'staged')
    if os.path.isdir(staged):
        shutil.rmtree(staged)
    inner_dir = os.path.join(staged, 'inner')
    wrap_dir = os.path.join(staged, 'wrapper')
    os.makedirs(inner_dir); os.makedirs(wrap_dir)

    # 1. merge: base entries + overlay entries (overlay wins on the same (ns, key))
    vb, base = locres.read(a.base)
    vo, over = locres.read(a.overlay)
    idx = {(e.ns, e.key): i for i, e in enumerate(base)}
    replaced = 0
    merged = list(base)
    for e in over:
        k = (e.ns, e.key)
        if k in idx:
            merged[idx[k]] = e; replaced += 1
        else:
            merged.append(e)
    loc_dir = os.path.join(inner_dir, 'Localization', a.target, 'ru')
    os.makedirs(loc_dir)
    merged_path = os.path.join(loc_dir, a.target + '.locres')
    total, nstr = locres.write(merged_path, merged, vb)
    print('merged locres: base %d + overlay %d (replaced %d) = %d entries, %d strings, version %d' % (len(base), len(over), replaced, total, nstr, vb))
    v2, e2 = locres.read(merged_path)
    assert len(e2) == total, 'merged file does not read back'
    if a.registry:
        rd = os.path.join(inner_dir, 'Mods', a.mod)
        os.makedirs(rd)
        shutil.copyfile(a.registry, os.path.join(rd, 'AssetRegistry.bin'))

    # 2. inner Windows pak (mount ../../../ConanSandbox/Content/)
    inner = os.path.join(wrap_dir, a.mod + '-Windows.pak')
    repak_pack(inner_dir, '../../../ConanSandbox/Content/', inner)

    # 3. wrapper: modinfo + manifest + inner pak (mount ../../../ConanSandbox/Mods/)
    shutil.copyfile(a.modinfo, os.path.join(wrap_dir, 'modinfo.json'))
    manifest = {name: md5(os.path.join(wrap_dir, name)) for name in (a.mod + '-Windows.pak', 'modinfo.json')}
    with open(os.path.join(wrap_dir, 'manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2)
    wrapper = os.path.join(a.out, a.mod + '.pak')
    repak_pack(wrap_dir, '../../../ConanSandbox/Mods/', wrapper)

    # 4. control: versions and listings through the kit's reader
    for p in (inner, wrapper):
        print('%s: pak version %s' % (os.path.basename(p), pak_version(p)))
        for l in unrealpak_list(p):
            print('   ', l[:160])
    assert pak_version(wrapper) == 11 and pak_version(inner) == 11, 'pak version is not 11'
    print('OK ->', wrapper, os.path.getsize(wrapper), 'bytes')

if __name__ == '__main__':
    main()
