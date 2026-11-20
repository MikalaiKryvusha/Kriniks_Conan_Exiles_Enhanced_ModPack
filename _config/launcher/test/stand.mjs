// stand.mjs — the test stand of the launcher's build update (KUMM plan 54, case B): a fake Conan folder (an empty ConanSandbox.exe), a tiny pack in two
// versions exported by the real engine (Deploy-ModPack.ps1 -Export) with the real uninstaller template, bundle 1.0.0 unpacked INTO the game folder and
// installed by its own install.cmd, bundle 1.0.1 cut into 7-Zip zip volumes like a release (make_volumes.sh: 7z a -tzip -mx0 -v…).
// Nothing touches the owner's game or desktop: the stand's «desktop» is KUMM_DESKTOP_DIR, which install.ps1 and the uninstaller read first.
//
//   node stand.mjs <empty work dir> --launcher <KrinikConanLauncher.exe> [--big] [--broken]
//     --big     bundle 1.0.1 carries three 1.6 GB files, so its zip needs Zip64 offsets past 4 GB (the real build is 13 GB)
//     --broken  bundle 1.0.1's deploy fails its own check (exit 1) but still writes the uninstaller
// Prints one JSON line: { game, desk, bundleOld, parts, stem }. Exit 0 — stand ready.
// [NOT-TESTED]
import { mkdirSync, writeFileSync, readFileSync, copyFileSync, existsSync, readdirSync, openSync, ftruncateSync, closeSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const PACK = path.resolve(HERE, '..', '..', '..')
const ENGINE = path.resolve(PACK, '..', 'KUMM', 'Deploy-ModPack.ps1')
const SEVEN = 'C:/Program Files/7-Zip/7z.exe'
const UNINSTALL_TEMPLATE = path.join(PACK, '_config', 'uninstall', 'uninstall.cmd')
const BIG_FILE = 1600 * 1024 * 1024
const VOLUME = process.argv.includes('--big') ? '1900m' : '64k'

const args = process.argv.slice(2)
const W = path.resolve(args[0] || '')
const launcher = path.resolve(args[args.indexOf('--launcher') + 1] || '')
if (!args[0] || !existsSync(launcher)) { console.error('usage: node stand.mjs <empty work dir> --launcher <exe> [--big]'); process.exit(2) }
if (existsSync(W) && readdirSync(W).length) { console.error(`${W} is not empty`); process.exit(2) }

const GAME = path.join(W, 'game'), DESK = path.join(W, 'desk'), OUT = path.join(W, 'out'), PARTS = path.join(W, 'parts')
for (const d of [GAME, DESK, OUT, PARTS]) mkdirSync(d, { recursive: true })
process.env.KUMM_DESKTOP_DIR = DESK
writeFileSync(path.join(GAME, 'ConanSandbox.exe'), '')
// Since KUMM plans/57 the launcher reads the game's build number (CL) from the Shipping exe and takes only a release marked for that CL: the fake game
// is 3.1.1 (CL-383549), the feed's default marker (feed.mjs --game).
const SHIPPING = path.join(GAME, 'ConanSandbox', 'Binaries', 'Win64', 'ConanSandbox-Win64-Shipping.exe')
execFileSync('python', ['-I', '-X', 'utf8', path.join(HERE, 'make_stub.py'), SHIPPING, 'game', process.env.STAND_GAME_CL || '383549'], { stdio: 'ignore' })

// One pack folder per version: the manifest, the mods' folders, the launcher and the uninstaller template as extras / template.
function pack(version, mods) {
  const dir = path.join(W, `pack_${version.replace(/\./g, '_')}`)
  for (const [name, files] of Object.entries(mods)) {
    mkdirSync(path.join(dir, 'src', name), { recursive: true })
    for (const [file, body] of Object.entries(files)) {
      const f = path.join(dir, 'src', name, file)
      if (typeof body === 'number') { const fd = openSync(f, 'w'); ftruncateSync(fd, body); closeSync(fd) } else writeFileSync(f, body)
    }
  }
  copyFileSync(launcher, path.join(dir, 'KrinikConanLauncher.exe'))
  copyFileSync(UNINSTALL_TEMPLATE, path.join(dir, 'uninstall.cmd'))
  writeFileSync(path.join(dir, 'modpack.json'), JSON.stringify({
    packName: 'Krinik fixture pack', builtFor: 'fixture', gameExe: 'ConanSandbox.exe', packVersion: version,
    uninstall: { cmd: 'uninstall_krinik_build.cmd', template: 'uninstall.cmd' },
    shortcut: { name: 'Krinik fixture', target: 'KrinikConanLauncher.exe' },
    extras: ['KrinikConanLauncher.exe'],
    mods: Object.keys(mods).map(name => ({ name, kind: 'files', source: { folder: `src/${name}` }, install: [{ from: '.', to: `Mods/${name}` }],
      verify: [`Mods/${name}/${Object.keys(mods[name])[0]}`] })),
  }, null, 2))
  return dir
}

const ps = (...a) => execFileSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ...a], { encoding: 'utf8' })
const OLD = pack('1.0.0', { ModA: { 'a.txt': 'mod A 1.0.0\n' } })
const NEWMODS = { ModA: { 'a.txt': 'mod A 1.0.1\n' }, ModB: { 'b.txt': 'mod B 1.0.1\n' } }
// The zeros of c*.bin would read the same from a wrong offset: the tail file (alphabetically after them, so its entry lies past 4 GB in the zip) carries a
// unique text the case compares byte for byte.
const TAIL = `zip64 tail ${Date.now()}\n`
if (args.includes('--big')) NEWMODS.ModC = { 'c1.bin': BIG_FILE, 'c2.bin': BIG_FILE, 'c3.bin': BIG_FILE, 'z_tail.txt': TAIL }
const NEW = pack('1.0.1', NEWMODS)
// --broken (case B4): build 1.0.1 checks a file it does not ship — its deploy ends with exit 1, yet writes the uninstaller (the judge's finding 2).
if (args.includes('--broken')) {
  const mf = path.join(NEW, 'modpack.json'), m = JSON.parse(readFileSync(mf, 'utf8'))
  m.mods.find(x => x.name === 'ModB').verify = ['Mods/ModB/b_missing.txt']
  writeFileSync(mf, JSON.stringify(m, null, 2))
}

const bundleOld = path.join(GAME, 'Krinik_fixture_1_0_0'), stem = 'Krinik_fixture_1_0_1'
ps(ENGINE, '-PackDir', OLD, '-Export', bundleOld)
ps(ENGINE, '-PackDir', NEW, '-Export', path.join(OUT, stem))
execFileSync(SEVEN, ['a', '-tzip', '-mx0', `-v${VOLUME}`, path.join(PARTS, `${stem}.zip`), stem], { cwd: OUT, stdio: 'ignore' })
// The installed build 1.0.0 — the player's path: its own install.cmd with the game folder, stdin nul (the cmd ends with pause).
execFileSync('cmd.exe', ['/d', '/s', '/c', `""${path.join(bundleOld, 'install.cmd')}" "${GAME}" < nul"`], { stdio: 'ignore', windowsVerbatimArguments: true })
const installed = existsSync(path.join(GAME, 'uninstall_krinik_build.cmd')) && existsSync(path.join(GAME, 'Mods', 'ModA', 'a.txt'))
console.log(JSON.stringify({ installed, game: GAME, desk: DESK, bundleOld, parts: PARTS, stem, volumes: readdirSync(PARTS).length, tail: TAIL }))
process.exit(installed ? 0 : 1)
