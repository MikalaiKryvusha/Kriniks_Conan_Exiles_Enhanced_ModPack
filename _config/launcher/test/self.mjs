// self.mjs — the cases of the self-sufficient launcher (KUMM plans/57; case set KUMM testcases/TC_conan_launcher_self_sufficient_2026-11-18.md): the game
// found on fake drives and in a fake Steam library, several copies and the copies list, no game, the game version by its build number (CL), the fresh
// install downloaded from the test feed, from the parts next to the launcher and from an unpacked build next to it, a broken connection and its resume,
// the stop and its resume after a restart, the feed offline, the language of the window.
// Nothing reaches the owner: the drives are stand folders (KRINIK_LAUNCHER_SEARCH_ROOTS), Steam is a stand folder (KRINIK_LAUNCHER_STEAM), the state
// folder, TEMP and the desktop are the case's own, the window sits off-screen without a taskbar button (KRINIK_LAUNCHER_FRAMES, which also writes the
// window's frames), buttons are pressed by BM_CLICK through click.ps1 — no real mouse or keyboard. Every wait is bounded; every process is killed by PID.
//
//   node self.mjs <case> <work dir> <launcher exe> [--stand <stand.json from stand.mjs>] [--dpi N] [--lang ru|en]
//   cases: none · steam · steam-old · games · pf · many · scan · unknown · around · fresh-feed · fresh-beside · fresh-local · fresh-cut · fresh-stop ·
//          fresh-416 · fresh-429 · perf · offline · lang · refused · rc · never · removing · title · shot:<screen>
// Prints one line per check «PASS|FAIL <what> — <observed>». Exit 0 — all PASS. [NOT-TESTED]
import { spawn, execFileSync } from 'node:child_process'
import { existsSync, readFileSync, writeFileSync, mkdirSync, readdirSync, copyFileSync, cpSync, unlinkSync, rmdirSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const args = process.argv.slice(2)
const [kase, workArg, exeArg] = args
const opt = n => { const i = args.indexOf('--' + n); return i >= 0 ? args[i + 1] : undefined }
const W = path.resolve(workArg || ''), EXE = path.resolve(exeArg || '')
const DPI = Number(opt('dpi') || 288)
const LANG = opt('lang') || 'ru'
const ST = opt('stand') ? JSON.parse(readFileSync(path.resolve(opt('stand')), 'utf8')) : null
let failed = 0
const check = (ok, what, seen) => { if (!ok) failed++; console.log(`${ok ? 'PASS' : 'FAIL'} ${what} — ${String(seen).slice(0, 400)}`) }
const wait = ms => new Promise(r => setTimeout(r, ms))
const killPid = pid => { try { execFileSync('taskkill', ['/PID', String(pid), '/T', '/F'], { stdio: 'ignore' }) } catch {} }
const children = []
process.on('exit', () => children.forEach(killPid))
async function until(test, ms, step = 250) {
  for (const end = Date.now() + ms; Date.now() < end; await wait(step)) { const v = test(); if (v) return v }
  return null
}
function alive(pid) { try { return execFileSync('tasklist', ['/FI', `PID eq ${pid}`, '/NH'], { encoding: 'utf8' }).includes(` ${pid} `) } catch { return false } }
function pidOf(exe, not = 0) {
  const out = execFileSync('powershell', ['-NoProfile', '-Command',
    `Get-CimInstance Win32_Process -Filter "Name='KrinikConanLauncher.exe'" | Where-Object { $_.ExecutablePath -eq '${exe.replace(/\//g, '\\').replace(/'/g, "''")}' } | ForEach-Object { $_.ProcessId }`],
    { encoding: 'utf8' }).trim()
  const pids = out ? out.split(/\s+/).map(Number).filter(p => p !== not) : []
  return pids.length ? pids[0] : null
}

const C = path.join(W, kase.replace(/[^a-z0-9-]/gi, '_'))
mkdirSync(C, { recursive: true })
const TMP = path.join(C, 'tmp'), STATE = path.join(C, 'state'), FRAMES = path.join(C, 'frames'), DESK = path.join(C, 'desk')
for (const d of [TMP, STATE, FRAMES, DESK]) mkdirSync(d, { recursive: true })
const LOG = path.join(TMP, 'KrinikConanLauncher.log')
const logText = () => existsSync(LOG) ? readFileSync(LOG, 'utf8') : ''
const last = re => (logText().match(new RegExp('.*' + re.source + '.*', 'g')) || ['no line']).pop()

// --- stand parts

const STUBS = path.join(W, 'stubs')
function stub(kind, cl = '') {
  const out = path.join(STUBS, `${kind}${cl}.exe`)
  if (!existsSync(out)) execFileSync('python', ['-I', '-X', 'utf8', path.join(HERE, 'make_stub.py'), out, kind, ...(cl ? [cl] : [])], { encoding: 'utf8' })
  return out
}
// A copy of the game: ConanSandbox.exe (a program that ends at once) and the Shipping exe with the CL in its ProductVersion (or only inside the file).
// record — the installer's record of the installed build (_kumm_backup\pack_version.txt, KUMM Deploy-ModPack.ps1 since 2026-11-18); unpacked — a newer
// bundle the launcher unpacked beside the game (pack\.krinik_unpacked) and never installed (the judge 2026-11-18, finding 2); krinikGame — the game the
// installed build was made for (launcher.gameVersion of its bundle's manifest; the judge 2026-11-18, round 2, finding 3).
function game(dir, { cl = '383549', scan = false, krinik = null, krinikGame = null, mods = false, record = false, unpacked = null } = {}) {
  mkdirSync(path.join(dir, 'ConanSandbox', 'Binaries', 'Win64'), { recursive: true })
  copyFileSync(stub('exit'), path.join(dir, 'ConanSandbox.exe'))
  copyFileSync(stub(scan ? 'scan' : 'game', cl), path.join(dir, 'ConanSandbox', 'Binaries', 'Win64', 'ConanSandbox-Win64-Shipping.exe'))
  if (krinik) {
    writeFileSync(path.join(dir, 'uninstall_krinik_build.cmd'), '@echo off\n')
    mkdirSync(path.join(dir, `Krinik_Mod_Pack_${krinik.replace(/\./g, '_')}`, 'pack'), { recursive: true })
    writeFileSync(path.join(dir, `Krinik_Mod_Pack_${krinik.replace(/\./g, '_')}`, 'pack', 'modpack.json'),
      JSON.stringify({ packVersion: krinik, ...(krinikGame ? { launcher: { gameVersion: krinikGame } } : {}) }))
    if (record) { mkdirSync(path.join(dir, '_kumm_backup'), { recursive: true }); writeFileSync(path.join(dir, '_kumm_backup', 'pack_version.txt'), krinik) }
  }
  if (unpacked) {
    const b = path.join(dir, `Krinik_Mod_Pack_${unpacked.replace(/\./g, '_')}`, 'pack')
    mkdirSync(b, { recursive: true })
    writeFileSync(path.join(b, 'modpack.json'), JSON.stringify({ packVersion: unpacked }))
    writeFileSync(path.join(b, '.krinik_unpacked'), unpacked)
  }
  if (mods) { mkdirSync(path.join(dir, 'ConanSandbox', 'Mods'), { recursive: true }); writeFileSync(path.join(dir, 'ConanSandbox', 'Mods', 'other.pak'), 'x') }
  return dir
}
// A fake Steam: <steam>\config\libraryfolders.vdf (current format) or <steam>\steamapps\libraryfolders.vdf (old format) listing a second library,
// whose appmanifest_440900.acf says «fully installed» (StateFlags 4) with installdir «Conan Exiles». LastOwner carries a SteamID the log must never show.
function steam(root, lib, { old = false } = {}) {
  mkdirSync(path.join(root, 'config'), { recursive: true })
  mkdirSync(path.join(root, 'steamapps'), { recursive: true })
  const esc = p => p.replace(/\\/g, '\\\\')
  if (old) writeFileSync(path.join(root, 'steamapps', 'libraryfolders.vdf'), `"LibraryFolders"\n{\n\t"TimeNextStatsReport"\t"1"\n\t"1"\t"${esc(lib)}"\n}\n`)
  else writeFileSync(path.join(root, 'config', 'libraryfolders.vdf'),
    `"libraryfolders"\n{\n\t"0"\n\t{\n\t\t"path"\t"${esc(root)}"\n\t\t"apps"\n\t\t{\n\t\t}\n\t}\n\t// a comment\n\t"1"\n\t{\n\t\t"path"\t"${esc(lib)}"\n\t\t"apps"\n\t\t{\n\t\t\t"440900"\t"1"\n\t\t}\n\t}\n}\n`)
  mkdirSync(path.join(lib, 'steamapps', 'common'), { recursive: true })
  writeFileSync(path.join(lib, 'steamapps', 'appmanifest_440900.acf'),
    `"AppState"\n{\n\t"appid"\t"440900"\n\t"name"\t"Conan Exiles"\n\t"StateFlags"\t"4"\n\t"installdir"\t"Conan Exiles"\n\t"LastOwner"\t"76561190000000042"\n}\n`)
  return game(path.join(lib, 'steamapps', 'common', 'Conan Exiles'))
}

function feed(extra) {
  const port = 20000 + Math.floor(Math.random() * 20000), log = path.join(TMP, 'feed.log')
  const p = spawn('node', [path.join(HERE, 'feed.mjs'), '--port', String(port), '--log', log, ...extra], { stdio: 'ignore' })
  children.push(p.pid)
  return { url: `http://127.0.0.1:${port}/releases`, log, pid: p.pid, text: () => existsSync(log) ? readFileSync(log, 'utf8') : '' }
}
async function ready(url) {
  for (const end = Date.now() + 120000; Date.now() < end; await wait(300)) { try { if ((await fetch(url.replace(/\/releases$/, '/ready'))).ok) return true } catch {} }
  return false
}
const NOFEED = 'http://127.0.0.1:9/releases'

function launch(exe, env = {}) {
  const e = { ...process.env, TEMP: TMP, TMP, KRINIK_LAUNCHER_NOACTIVATE: '1', KRINIK_LAUNCHER_STATE_DIR: STATE, KRINIK_LAUNCHER_FRAMES: `${FRAMES};${DPI}`,
    KRINIK_LAUNCHER_SYSTEM_LANG: LANG === 'en' ? 'en-US' : 'ru-RU', KRINIK_LAUNCHER_STEAM: path.join(C, 'nosteam'), KRINIK_LAUNCHER_SEARCH_ROOTS: path.join(C, 'noroots'),
    KRINIK_LAUNCHER_FEED: NOFEED, KUMM_DESKTOP_DIR: DESK, ...env }
  const p = spawn(exe, [], { cwd: path.dirname(exe), env: e, stdio: 'ignore' })
  children.push(p.pid)
  return p.pid
}
const ps1 = (...a) => execFileSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(HERE, 'click.ps1'), ...a], { encoding: 'utf8' }).trim()
// click() answers «pressed #i of n» or «not pressed: …»: a check of the press is anchored (/^pressed/) — a bare /pressed/ matched the refusal too and could
// not fail (the judge 2026-11-18, round 2, finding 6).
const click = (pid, name, extra = []) => { try { return ps1('-ProcessId', String(pid), '-Name', name, ...extra) } catch (e) { return 'not pressed: ' + (e.stdout || e.message).toString().trim() } }
// The window's title as the taskbar shows it (UTF-8 through a file: the console of PowerShell 5.1 is not UTF-8).
function title(pid) {
  const out = path.join(TMP, 'title.txt')
  try { ps1('-ProcessId', String(pid), '-Title', '-Out', out, '-TimeoutSec', '10'); return readFileSync(out, 'utf8').trim() } catch { return 'no title read' }
}
function dialog(pid, press, sec = 30) {
  const out = path.join(TMP, 'dialog.txt')
  try { ps1('-ProcessId', String(pid), '-Dialog', '-Out', out, ...(press ? ['-Press', press] : []), '-TimeoutSec', String(sec)); return readFileSync(out, 'utf8').replace(/\s+/g, ' ').trim() }
  catch { return null }
}
const screenIs = (id, ms = 20000) => until(() => new RegExp(`экран: ${id} `).test(logText()), ms)
// One copy per case: a second start reuses it (copying over an exe killed a moment ago fails with EBUSY — run 15:49).
const lone = () => { const d = path.join(C, 'lone'); mkdirSync(d, { recursive: true }); const e = path.join(d, 'KrinikConanLauncher.exe'); if (!existsSync(e)) copyFileSync(EXE, e); return e }
const roots = (...names) => names.map(n => { const d = path.join(C, n); mkdirSync(d, { recursive: true }); return d })
const frameCount = re => readdirSync(FRAMES).filter(f => re.test(f)).length

// --- cases

const cases = {
  // G0 (criterion 3): no game anywhere — the window says so and offers «Указать папку игры»; the press opens the Windows folder dialog.
  async none() {
    const exe = lone(), [d] = roots('driveD')
    const pid = launch(exe, { KRINIK_LAUNCHER_SEARCH_ROOTS: d })
    check(!!await screenIs('notfound'), 'G0 no game: the screen «notfound»', last(/экран:/))
    check(/Лаунчер не нашёл игру ни\u00A0в\u00A0библиотеках Steam/.test(logText()), 'G0 the window names where it looked', last(/экран: notfound/))
    check(!!await until(() => readdirSync(FRAMES).some(f => /_notfound_/.test(f)), 8000), 'G0 a frame of the screen', readdirSync(FRAMES).join(', '))
    const g0 = click(pid, 'Указать папку игры')
    check(/^pressed/.test(g0), 'G0 the gold «Указать папку игры» pressed', g0)
    // The frames stand does not open the Windows folder dialog: Windows centres it on the owner's screen (watcher, 16:00). The press reaches it in the log;
    // the real dialog was read once at 15:4x (title «Обзор папок»).
    check(!!await until(() => /окно выбора папки: стенд кадров, окно не показано/.test(logText()), 8000), 'G0 the press reaches the folder dialog (not shown on the frames stand)', last(/окно выбора папки/))
    await wait(1000)
    check(alive(pid) && !/игра выбрана/.test(logText()), 'G0 after «Отмена» the launcher stays, no game chosen', last(/игра выбрана|экран:/))
    killPid(pid)
  },
  // G1 (criterion 1): a game in a second Steam library, listed by config\libraryfolders.vdf (current format) and appmanifest_440900.acf.
  async steam() { await steamCase(false) },
  // G1b: the old LibraryFolders format in steamapps\libraryfolders.vdf.
  async 'steam-old'() { await steamCase(true) },
  // G2 (criterion 1, the owner 2026-11-18 10:04): X:\Games\<any name>.
  async games() {
    const [d] = roots('driveD'), g = game(path.join(d, 'Games', 'Conan Exiles Enhanced'))
    await foundCase({ KRINIK_LAUNCHER_SEARCH_ROOTS: d }, g, 'G2 X:\\Games\\<any name>')
  },
  // G3 (criterion 1): a standard install folder X:\Program Files\<name>.
  async pf() {
    const [d] = roots('driveE'), g = game(path.join(d, 'Program Files', 'Conan Exiles'))
    await foundCase({ KRINIK_LAUNCHER_SEARCH_ROOTS: d }, g, 'G3 X:\\Program Files\\<name>')
  },
  // G4 (criterion 2) + G7: four copies — the copies list with version and state of each; the player picks the second; the next start remembers it.
  async many() {
    const s = path.join(C, 'steam'), st = steam(s, path.join(C, 'lib2'))
    const [d, e, f] = roots('driveD', 'driveE', 'driveF')
    const krinik = game(path.join(d, 'Games', 'Conan Exiles'), { krinik: '0.9.0' })
    const other = game(path.join(e, 'Games', 'Other', 'Conan Exiles'), { mods: true })
    const old = game(path.join(f, 'Program Files', 'Conan Exiles 3.0.1'), { cl: '379176' })
    const fd = await standFeed()
    const env = { KRINIK_LAUNCHER_STEAM: s, KRINIK_LAUNCHER_SEARCH_ROOTS: [d, e, f].join(';'), KRINIK_LAUNCHER_FEED: fd.url }
    let pid = launch(lone(), env)
    check(!!await until(() => /выбор копии: 4 копий/.test(logText()), 25000), 'G4 four copies — the copies list opens', last(/выбор копии/))
    const line = last(/выбор копии/)
    check(line.includes(`Conan Exiles 3.1.1 · без модов · ${st}`), 'G4 the Steam copy: 3.1.1, no mods', line)
    check(line.includes(`Conan Exiles 3.1.1 · установлена сборка 0.9.0 · ${krinik}`), 'G4 the copy with build 0.9.0', line)
    check(line.includes(`Conan Exiles 3.1.1 · установлены другие моды · ${other}`), 'G4 the copy with other mods', line)
    check(line.includes(`Conan Exiles 3.0.1 · сборка для этой версии ещё не вышла · ${old}`), 'G4 the 3.0.1 copy: no build for its version', line)
    check(!!await until(() => readdirSync(FRAMES).some(n => /choose-modal/.test(n)), 8000), 'G4 a frame of the copies list', readdirSync(FRAMES).join(', '))
    // The second row (the order is the search's: Steam, then the drives in order) — one Down key to the list, then the gold «Установить сборку» of the list.
    const key = click(pid, 'Копии игры', ['-Key', '40'])
    check(/^pressed/.test(key), 'G4 the Down key reached the copies list', key)
    await wait(500)
    click(pid, 'Установить сборку')
    check(!!await until(() => logText().includes('игра выбрана: ' + krinik), 10000), 'G4 the picked copy is remembered', last(/игра выбрана/))
    // The picked copy holds build 0.9.0 and the feed has 1.0.1 for its CL: «Играть» with the update plate (first written as «installed» — the row was wrong).
    check(!!await screenIs('update', 10000), 'G4 the window shows the picked copy (build 0.9.0 installed, «Играть» and the plate for 1.0.1)', last(/экран:/))
    killPid(pid)
    writeFileSync(LOG, '')
    pid = launch(lone(), env)
    check(!!await until(() => logText().includes('игра: ' + krinik), 10000) && !/ищу игру/.test(logText()), 'G7 the next start takes the remembered copy, no search', last(/игра:|ищу игру/))
    killPid(pid)
  },
  // V1–V2 (the judge 2026-11-18, finding 2): the installed build is the one the installer recorded, never a newer bundle unpacked beside the game and not
  // installed (an update stopped by the running game or by the player). V1 with the record; V2 an install of 0.9.0 (no record): the bundle the player
  // unpacked himself wins over the one the launcher unpacked.
  async refused() {
    const [d] = roots('driveD')
    const fd = await standFeed()
    const g = game(path.join(d, 'Games', 'Conan Exiles'), { krinik: '1.0.0', record: true, unpacked: '1.0.1' })
    let pid = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: d, KRINIK_LAUNCHER_FEED: fd.url })
    check(!!await screenIs('update', 25000), 'V1 build 1.0.0 recorded, 1.0.1 only unpacked — «Играть» with the update plate for 1.0.1', last(/экран:/))
    killPid(pid)
    unlinkSync(path.join(g, '_kumm_backup', 'pack_version.txt'))
    writeFileSync(LOG, '')
    pid = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: d, KRINIK_LAUNCHER_FEED: fd.url })
    check(!!await screenIs('update', 25000), 'V2 no record (an install of 0.9.0): the hand-unpacked 1.0.0 is the installed build, the plate offers 1.0.1', last(/экран:/))
    killPid(pid)
  },
  // RC1–RC4 (KUMM plans/55 phase E, the owner 2026-11-18 19:08–19:11): release candidates are ordered as numbers and below their release — a player on
  // 0.9.1-RC1 is offered RC2, a player on RC2 is offered 0.9.1, a player on 0.9.1 is NOT offered RC2, the same RC is not an update. The installed build is
  // the installer's record (_kumm_backup\pack_version.txt); the feed carries one build release. Until 2026-11-18 the tail «-RC1» was cut and RC1 = RC2 = 0.9.1.
  async rc() {
    const pairs = [['RC1', '0.9.1-RC1', '0.9.1-RC2', 'update'], ['RC2', '0.9.1-RC2', '0.9.1', 'update'], ['RC3', '0.9.1', '0.9.1-RC2', 'installed'],
                   ['RC4', '0.9.1-RC1', '0.9.1-RC1', 'installed']]
    for (const [id, have, offered, want] of pairs) {
      const [d] = roots('drive_' + id)
      const fd = feed(['--build', offered, '--parts', ST.parts])
      check(await ready(fd.url), `${id} the test feed came up`, fd.url)
      game(path.join(d, 'Games', 'Conan Exiles'), { krinik: have, record: true })
      writeFileSync(LOG, '')
      // Each pair its own state folder: the launcher remembers the copy it took, and a shared state read the first pair's game in every pair (run 21:04).
      const pid = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: d, KRINIK_LAUNCHER_FEED: fd.url, KRINIK_LAUNCHER_STATE_DIR: path.join(C, 'state_' + id) })
      // The window shows its screen before the feed answers and redraws it after: the verdict is the last screen once the feed line is in the log.
      const seen = await until(() => /лента: сборок/.test(logText()), 25000)
      await wait(1500)
      const screen = (last(/экран: (update|installed) /).match(/экран: (\S+)/) || [])[1]
      const feedLine = last(/лента: сборок/)
      check(!!seen && screen === want && feedLine.includes(`(у нас ${have})`), `${id} ${have} installed, ${offered} in the feed — the screen «${want}»`, `${last(/экран:/)} || ${feedLine}`)
      killPid(pid)
      killPid(fd.pid)
      await wait(500)
    }
  },
  // N1 (the judge 2026-11-18, finding 1): a folder in never.txt of the launcher's state folder — the reference copy of the game — is never offered; the
  // other copy is the only one, taken at once. N2: with the reference copy alone the launcher finds no game.
  async never() {
    const [d] = roots('driveD')
    const ref = game(path.join(d, 'Instals', 'Conan Exiles Enhanced 3.1.1')), own = game(path.join(d, 'Games', 'Conan Exiles'))
    mkdirSync(STATE, { recursive: true })
    writeFileSync(path.join(STATE, 'never.txt'), path.join(d, 'Instals') + '\r\n')
    let pid = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: d })
    check(!!await until(() => /экран: (found-|offline|noversion)/.test(logText()), 25000), 'N1 one copy found — no copies list', last(/экран:|выбор копии/))
    const lt = logText()
    check(lt.includes('копия игры в запретной папке (never.txt), не предлагается: ' + ref) && lt.includes('найдена игра: ' + own) && !lt.includes('найдена игра: ' + ref),
      'N1 the reference copy is skipped, the other one is the game', last(/запретной папке|найдена игра/))
    killPid(pid)
    // N3 (the judge 2026-11-18, round 2, finding 4): never.txt as Explorer's «Copy as path» writes it, in quotes, still forbids the folder; a relative line
    // is no folder (it would resolve against the launcher's working folder) and is logged as ignored. Its own state folder: N1's never.txt stays.
    const st3 = path.join(C, 'state_n3')
    mkdirSync(st3, { recursive: true })
    writeFileSync(path.join(st3, 'never.txt'), `"${path.join(d, 'Instals')}"\r\nInstals\r\n`)
    writeFileSync(LOG, '')
    pid = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: d, KRINIK_LAUNCHER_STATE_DIR: st3 })
    check(!!await until(() => /экран: (found-|offline|noversion)/.test(logText()), 25000), 'N3 a quoted line in never.txt forbids the folder — one copy, no copies list', last(/экран:|выбор копии/))
    const l3 = logText()
    check(l3.includes('копия игры в запретной папке (never.txt), не предлагается: ' + ref) && !l3.includes('найдена игра: ' + ref), 'N3 the reference copy is skipped', last(/запретной папке|найдена игра/))
    check(/never\.txt: строка пропущена, это не полный путь к папке: Instals$/m.test(l3), 'N3 the relative line is logged as ignored', last(/never\.txt: строка/))
    killPid(pid)
    unlinkSync(path.join(own, 'ConanSandbox.exe'))
    writeFileSync(LOG, '')
    writeFileSync(path.join(STATE, 'game.txt'), ref)
    pid = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: d })
    check(!!await screenIs('notfound', 25000), 'N2 only the reference copy, even remembered as chosen — «notfound»', last(/экран:/))
    await wait(1000)
    killPid(pid)
    // N4 (the judge 2026-11-18, round 2, finding 9): a build unpacked INTO a forbidden game folder — the launcher takes that game (it lies around the
    // launcher), says the folder is forbidden and offers no install: «Установить сборку» used to end in the «never» box on every press.
    const fg = game(path.join(C, 'n4', 'Instals', 'Conan Exiles'))
    const inside = path.join(fg, ST.stem)
    cpSync(path.join(path.dirname(ST.parts), 'out', ST.stem), inside, { recursive: true })
    const exe4 = path.join(inside, 'KrinikConanLauncher.exe')
    copyFileSync(EXE, exe4)
    const st4 = path.join(C, 'state_n4')
    mkdirSync(st4, { recursive: true })
    writeFileSync(path.join(st4, 'never.txt'), path.join(C, 'n4', 'Instals') + '\r\n')
    writeFileSync(LOG, '')
    pid = launch(exe4, { KRINIK_LAUNCHER_STATE_DIR: st4 })
    check(!!await until(() => logText().includes('игра: ' + fg), 10000) && !!await until(() => /экран: (?!search)/.test(logText()), 15000), 'N4 the game around the launcher is taken', last(/игра:|экран:/))
    await wait(1000)
    const s4 = last(/экран:/)
    check(/экран: release-bad /.test(s4) && s4.includes('never.txt') && !/экран: found-files/.test(logText()), 'N4 a forbidden game around the launcher — the window says so, no «found-files»', s4)
    const p4 = click(pid, 'Установить сборку', ['-TimeoutSec', '2'])
    check(p4.startsWith('not pressed'), 'N4 no «Установить сборку» on the screen', p4)
    killPid(pid)
    // N5 (the judge 2026-11-20, round 3, finding 4): a build INSTALLED in a forbidden game folder, the launcher inside it, the feed has a newer build —
    // «Играть» stays, no update plate (every «Обновить сборку» press ended in the never box). [NOT-TESTED]
    const fd5 = await standFeed()
    const fg5 = game(path.join(C, 'n5', 'Instals', 'Conan Exiles'), { krinik: '1.0.0', record: true })
    const in5 = path.join(fg5, 'Krinik_Mod_Pack_1_0_0')
    const exe5 = path.join(in5, 'KrinikConanLauncher.exe')
    copyFileSync(EXE, exe5)
    const st5 = path.join(C, 'state_n5')
    mkdirSync(st5, { recursive: true })
    writeFileSync(path.join(st5, 'never.txt'), path.join(C, 'n5', 'Instals') + '\r\n')
    writeFileSync(LOG, '')
    pid = launch(exe5, { KRINIK_LAUNCHER_STATE_DIR: st5, KRINIK_LAUNCHER_FEED: fd5.url })
    check(!!await until(() => /лента: сборок/.test(logText()), 25000) && !!await screenIs('installed', 10000), 'N5 a forbidden Krinik game with a newer build in the feed — «installed»', last(/экран:/))
    await wait(1500)
    check(!/экран: update/.test(logText()), 'N5 no update plate for a build in a forbidden folder', last(/экран:/))
    killPid(pid)
  },
  // U1 (the judge 2026-11-18, finding 5): while the uninstaller the launcher started runs, the window shows «removing» — no «Играть», no second
  // «Удалить сборку»; when it closes, the window shows the game again. The stand's uninstaller runs while the hold file lives (at most ≈ 90 s) and removes
  // itself (the frames stand starts it hidden, so no console reaches the owner's screen). The case deletes the hold file after both probes: a fixed 4 s
  // wait ended before the second probe, which then passed with or without the «removing» screen (the judge 2026-11-18, round 2, finding 7).
  async removing() {
    const [d] = roots('driveD')
    const fd = await standFeed()
    const g = game(path.join(d, 'Games', 'Conan Exiles'), { krinik: '1.0.1', record: true })
    const hold = path.join(C, 'uninstaller.hold')
    writeFileSync(hold, 'hold')
    writeFileSync(path.join(g, 'uninstall_krinik_build.cmd'), ['@echo off', 'set n=0', ':wait', `if not exist "${hold}" goto done`, 'set /a n+=1',
      'if %n% geq 90 goto done', 'ping -n 2 127.0.0.1 >nul', 'goto wait', ':done', '(goto) 2>nul & del "%~f0"', ''].join('\r\n'))
    const pid = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: d, KRINIK_LAUNCHER_FEED: fd.url })
    check(!!await screenIs('installed', 25000), 'U1 build 1.0.1 installed — «installed»', last(/экран:/))
    click(pid, 'Удалить сборку')
    const asked = dialog(pid, '6', 15)
    check(!!asked, 'U1 the uninstall question answered «Да»', asked || 'no box')
    check(!!await screenIs('removing', 10000), 'U1 the uninstaller runs — the screen «removing»', last(/экран:/))
    check(last(/экран: removing/).includes('Программа удаления сборки работает в отдельном окне.'), 'U1 the window says the uninstaller runs in its own window', last(/экран: removing/))
    const play = click(pid, 'Играть', ['-TimeoutSec', '2']), again = click(pid, 'Удалить сборку', ['-TimeoutSec', '2'])
    const still = last(/экран:/)
    check(play.startsWith('not pressed') && again.startsWith('not pressed') && still.includes('экран: removing ') && !/окно удаления сборки закрыто/.test(logText()),
      'U1 no «Играть» and no «Удалить сборку» while it runs (the screen still «removing» after both probes)', `${play} | ${again} | ${still}`)
    unlinkSync(hold)
    check(!!await until(() => /окно удаления сборки закрыто/.test(logText()), 20000), 'U1 the uninstaller closed', last(/окно удаления/))
    check(!!await until(() => /экран: found-/.test(last(/экран:/)), 10000), 'U1 then the window shows the game without the build', last(/экран:/))
    killPid(pid)
  },
  // H1 (the judge 2026-11-18, round 2, finding 3): the window title pairs the INSTALLED build with the game it was made for (launcher.gameVersion of its
  // bundle's manifest in the game), never with the found game's version — also after the feed has named that game (Games.Learn). The game is CL-390000,
  // unknown until the feed's marker «3.2.0 CL-390000»; the installed 1.0.0 was made for 3.1.0; the launcher's own fallback (BuildInfo) is 3.1.1.
  async title() {
    const [d] = roots('driveD')
    const fd = feed(['--build', '1.0.1', '--parts', ST.parts, '--game', '3.2.0 CL-390000'])
    check(await ready(fd.url), 'the test feed came up', fd.url)
    game(path.join(d, 'Games', 'Conan Exiles'), { cl: '390000', krinik: '1.0.0', krinikGame: '3.1.0', record: true })
    const pid = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: d, KRINIK_LAUNCHER_FEED: fd.url })
    const fed = await until(() => /лента: сборок/.test(logText()), 25000)
    check(!!fed && !!await screenIs('update', 10000), 'H1 1.0.0 installed, the feed has 1.0.1 for this game (3.2.0) — «update»', last(/экран:/))
    await wait(1500)
    const t = title(pid)
    check(t.endsWith('Krinik Mod Pack 1.0.0 для Conan Exiles Enhanced 3.1.0'), 'H1 the title pairs the installed 1.0.0 with the game it was made for (3.1.0), not the found 3.2.0', t)
    killPid(pid)
    // H2 (the judge 2026-11-20, round 3, finding 3): the record names the launcher's OWN build, its Krinik_* folder is gone from the game — the title takes
    // the launcher's own game (its manifest / BuildInfo), not the found 3.2.0. [NOT-TESTED]
    const own = execFileSync('powershell', ['-NoProfile', '-Command', `(Get-Item '${EXE.replace(/'/g, "''")}').VersionInfo.ProductVersion`], { encoding: 'utf8' }).trim()
    const ownPack = JSON.parse(readFileSync(path.join(HERE, '..', '..', '..', 'modpack.json'), 'utf8'))
    const g2 = game(path.join(roots('driveE')[0], 'Games', 'Conan Exiles'), { cl: '390000', krinik: ownPack.packVersion, record: true })
    const sub = path.join(g2, `Krinik_Mod_Pack_${ownPack.packVersion.replace(/\./g, '_')}`)   // the folder name game() writes
    unlinkSync(path.join(sub, 'pack', 'modpack.json')); rmdirSync(path.join(sub, 'pack')); rmdirSync(sub)
    writeFileSync(LOG, '')
    // Its own state folder: the launcher remembers the chosen copy (game.txt), and H1's copy would be taken again.
    const st2 = path.join(C, 'state_h2'); mkdirSync(st2, { recursive: true })
    const pid2 = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: roots('driveE')[0], KRINIK_LAUNCHER_FEED: fd.url, KRINIK_LAUNCHER_STATE_DIR: st2 })
    // The feed must have answered: before it the launcher does not know CL 390000 (Games.VersionOf is null until Learn), and the title falls back to the
    // launcher's own game by the OLD code path too — H2 would pass without exercising the fix (the judge 2026-11-20, round 4, finding 5). [TESTED: 2026-11-20 · PASS on the r5 exe, the feed line read · KUMM testcases/reports/2026-11-20_conan-launcher-judge4-fixes.md]
    check(!!await until(() => /лента: сборок/.test(logText()), 25000), 'H2 the feed answered (the CL is known)', last(/лента:/))
    await wait(1500)
    const t2 = title(pid2)
    check(t2.endsWith(`Krinik Mod Pack ${ownPack.packVersion} для Conan Exiles Enhanced ${ownPack.launcher.gameVersion}`),
      `H2 no build folder in the game — the title takes the launcher's own game (${ownPack.launcher.gameVersion}), not the found 3.2.0`, `${t2} (exe ${own})`)
    killPid(pid2)
  },
  // G5: the CL read from inside the Shipping exe when its ProductVersion has no «-CL-».
  async scan() {
    const [d] = roots('driveD'), g = game(path.join(d, 'Games', 'Conan Exiles'), { scan: true })
    await foundCase({ KRINIK_LAUNCHER_SEARCH_ROOTS: d }, g, 'G5 the CL found inside the file')
  },
  // G6 (criterion 6): a game version no release is made for — the window names the latest build and its game, installs nothing.
  async unknown() {
    const [d] = roots('driveD'), g = game(path.join(d, 'Games', 'Conan Exiles'), { cl: '390000' })
    const fd = await standFeed()
    const pid = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: d, KRINIK_LAUNCHER_FEED: fd.url })
    check(!!await screenIs('noversion', 25000), 'G6 the screen «noversion»', last(/экран:/))
    const l = last(/экран: noversion/)
    check(l.includes('Версия игры: CL-390000') && l.includes('Сборка для игры CL-390000 ещё не вышла.') && l.includes('Последняя сборка: 1.0.1 для игры 3.1.1'),
      'G6 the window names the latest build and its game', l)
    check(click(pid, 'Установить сборку').startsWith('not pressed'), 'G6 no «Установить сборку» on the screen', '')
    check(!/GET \/file\//.test(fd.text()), 'G6 nothing was downloaded', '')
    killPid(pid)
  },
  // G8: the launcher inside a game folder — that game, no search.
  async around() {
    const g = game(path.join(C, 'gamehere')), exe = path.join(g, 'KrinikConanLauncher.exe')
    copyFileSync(EXE, exe)
    const pid = launch(exe)
    check(!!await until(() => logText().includes('игра: ' + g), 10000) && !/ищу игру/.test(logText()), 'G8 the game around the launcher, no search', last(/игра:|ищу игру/))
    // The window must exist before the kill: the run of 18:40 killed it 0.1 s after the log line, and the screen watcher (C1) saw no window to judge.
    check(!!await until(() => /экран:/.test(logText()), 10000), 'G8 the window shows its first screen', last(/экран:/))
    await wait(1500)   // one poll of the watcher (Get-CimInstance + EnumWindows) takes ≈ 0.5 s: the window must outlive it
    killPid(pid)
  },
  // D1 (criteria 5, 7): a clean game, no files beside — «Установить сборку» downloads the release's parts, checks, unpacks and installs; every phase on the bar.
  async 'fresh-feed'() { await freshCase({ rate: 600000 }) },
  // D2 (criterion 4): the release's parts lie next to the launcher — installed with no download (the feed log shows no file request).
  async 'fresh-beside'() { await freshCase({ beside: true }) },
  // D4 (criterion 8): the connection breaks mid-file — «Продолжить скачивание» resumes by Range and finishes.
  async 'fresh-cut'() { await freshCase({ cut: 30000, rate: 400000 }) },
  // D5: «Остановить» mid-download; a restart shows the stop and resumes.
  async 'fresh-stop'() { await freshCase({ stop: true, rate: 250000 }) },
  // D6 (the judge 2026-11-18, round 2, finding 8): the broken part is resumed by Range and the server answers 416 — the launcher drops the part and fetches it
  // whole instead of an error screen whose only button sent the same Range again.
  async 'fresh-416'() { await freshCase({ cut: 30000, rate: 400000, range416: true }) },
  // P (bug 110, KUMM researches/efficient-code §1.5, HOUSE_RULES 41): the fresh install from the feed with the launcher's own timers on
  // (KRINIK_LAUNCHER_PERF=1), judged by a time budget at the stand's 300 % scale — P1 the window's picture is rendered at most twice in the whole flow
  // (at birth and when the found game's version appears under its logo), P2 every screen refresh after the first fits one 60 Hz frame (16 ms), P3 every
  // repaint of the state list during the download after its first fits 16 ms. To be seen red on the pre-fix build (a timed copy of its sources).
  async perf() { await freshCase({ rate: 600000, extraEnv: { KRINIK_LAUNCHER_PERF: '1' } }); perfBudget() },
  // D6b (same finding): 429 «too many requests» and 408 «request timeout» pass by themselves — each is a broken connection («neterror», «Продолжить
  // скачивание»), not a final error.
  // Four error answers in a row, each one a «Продолжить скачивание» that must reach the server again. This case does NOT guard the connection leak of the
  // judge's round 3, finding 6 (an error response left open holding one of the two connections .NET gives a host): it passed on the exe before that fix
  // too (report KUMM testcases/reports/2026-11-20_conan-launcher-judge3-fixes.md) — the stand's feed listens on 127.0.0.1, where most likely the
  // two-connection limit does not apply. The leak is closed in the code (Feed.Respond, Feed.Download) and has no test (the judge 2026-11-20, round 4,
  // finding 3).
  async 'fresh-429'() { await freshCase({ status: [429, 408, 429, 408] }) },
  // D3: an unpacked build next to the launcher, no feed at all — installed as it is, the window turns to «Играть».
  async 'fresh-local'() {
    const [d] = roots('driveD'), g = game(path.join(d, 'Games', 'Conan Exiles'))
    const bundle = path.join(C, 'bundle')
    cpSync(path.join(path.dirname(ST.parts), 'out', ST.stem), bundle, { recursive: true })
    const exe = path.join(bundle, 'KrinikConanLauncher.exe')
    copyFileSync(EXE, exe)
    const pid = launch(exe, { KRINIK_LAUNCHER_SEARCH_ROOTS: d })
    check(!!await screenIs('found-files', 20000), 'D3 the unpacked build next to the launcher, offline — «found-files»', last(/экран:/))
    check(last(/экран: found-files/).includes('Файлы сборки: уже лежат рядом с лаунчером'), 'D3 the window says the files lie next to it', last(/экран: found-files/))
    click(pid, 'Установить сборку')
    check(!!await screenIs('install', 20000), 'D3 the install runs on the bar', last(/экран:/))
    check(!!await screenIs('installed', 60000), 'D3 then the window shows «Играть»', last(/экран:/))
    check(/модов в строках установщика 2 из 2/.test(logText()), 'D3 the bar counted every mod of the build', last(/модов в строках установщика/))
    check(existsSync(path.join(g, 'Mods', 'ModA', 'a.txt')) && readFileSync(path.join(g, 'Mods', 'ModA', 'a.txt'), 'utf8').trim() === 'mod A 1.0.1', 'D3 the mods are in the game', '')
    check(existsSync(path.join(g, 'uninstall_krinik_build.cmd')), 'D3 the uninstaller is in the game', '')
    killPid(pid)
  },
  // D7: the feed does not answer — the window says so and offers «Проверить ещё раз».
  async offline() {
    const [d] = roots('driveD'); game(path.join(d, 'Games', 'Conan Exiles'))
    const fd = feed(['--refuse'])
    await ready(fd.url)
    const pid = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: d, KRINIK_LAUNCHER_FEED: fd.url, KRINIK_LAUNCHER_PERF: '1' })
    check(!!await screenIs('offline', 20000), 'D7 the feed refuses — the screen «offline»', last(/экран:/))
    check(last(/экран: offline/).includes('Лаунчер не связался с GitHub'), 'D7 the window says so', last(/экран: offline/))
    click(pid, 'Проверить ещё раз')
    check(!!await until(() => (logText().match(/лента не ответила/g) || []).length >= 2, 15000), 'D7 «Проверить ещё раз» asks the feed again', String((logText().match(/лента не ответила/g) || []).length))
    // D7b (judge 2026-11-20, round 5, finding 1): the retry goes «feed-wait» → «offline»; both keep the state list's height, and the list must still be
    // repainted — a frame cannot show it (DrawToBitmap paints fresh), so the check reads the list's repaint request (below). (The start's own «offline»
    // usually comes from «search», a different shape.) Proven 2026-11-20 14:43: green on the fix, red on a control build that differs by the one line.
    // The launcher writes a screen line AFTER it applied the screen, so the list's mark of the «offline» screen stands between the LAST «feed-wait» line
    // (the retry's — judge round 6, finding 5: the start may pass through «feed-wait» too) and the «offline» line after it.
    const WAIT = 'экран: feed-wait'
    const afterRetry = () => { const t = logText(), w = t.lastIndexOf(WAIT), o = w < 0 ? -1 : t.indexOf('экран: offline', w); return o < 0 ? null : t.slice(w + WAIT.length, o) }
    check(!!await until(() => afterRetry() !== null, 8000), 'D7b the retry ends on «offline» again', last(/экран:/))
    // The stand's window sits off-screen, and Windows sends it no WM_PAINT at all (2026-11-20: every paint line of the case was a frame's Print), so
    // the check reads the list's repaint REQUEST — the mark «StatePanel.Invalidate» the launcher writes after the list's Invalidate().
    const repainted = () => /StatePanel\.Invalidate/.test(afterRetry() || '')
    check(repainted(), 'D7b the state list asks for its repaint on «feed-wait» → «offline»', repainted() ? 'a StatePanel.Invalidate mark between the «feed-wait» line and the second «offline» line' : 'no repaint request of the list on that switch')
    killPid(pid)
  },
  // LG1–LG3 (criteria 10–11): the first start in the Windows language; the switch re-renders the window at once and is saved; the next start keeps it.
  async lang() {
    const [d] = roots('driveD')
    let pid = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: d, KRINIK_LAUNCHER_SYSTEM_LANG: 'en-US' })
    check(!!await screenIs('notfound'), 'LG1 the first start opens', last(/экран:/))
    check(/язык окна по языку системы en-US: En/.test(logText()), 'LG1 the first start follows the system language (en-US → English)', last(/язык окна/))
    check(last(/экран: notfound/).includes('The launcher did not find the game'), 'LG1 the window speaks English', last(/экран: notfound/))
    // LG4 (criterion 11, the dropdown of the owner's 15:55): the field opens a list naming each language in itself; Esc and a second press close it
    // with the language unchanged; a pick from the list changes it.
    const field = click(pid, 'Window language')
    check(/^pressed/.test(field), 'LG4 the language field pressed', field)
    check(!!await until(() => /список языков открыт: Русский, English \(текущий\)/.test(logText()), 8000), 'LG4 the list opened, each language named in itself, English current', last(/список языков/))
    check(!!await until(() => readdirSync(FRAMES).some(n => /-langlist_en/.test(n)), 8000), 'LG4 a frame of the open list', readdirSync(FRAMES).join(', '))
    const esc = click(pid, 'Русский', ['-Key', '27'])
    check(/^pressed/.test(esc), 'LG4 Esc sent to the list', esc)
    check(!!await until(() => /список языков закрыт/.test(logText()), 8000) && !/язык окна выбран игроком/.test(logText()), 'LG4 Esc closed the list, the language unchanged', last(/список языков|язык окна выбран/))
    writeFileSync(LOG, '')
    click(pid, 'Window language')
    check(!!await until(() => /список языков открыт/.test(logText()), 8000), 'LG4 the list opened again', last(/список языков/))
    click(pid, 'Window language')
    check(!!await until(() => /список языков закрыт/.test(logText()), 8000) && !/язык окна выбран игроком/.test(logText()), 'LG4 a second press on the field closed it, the language unchanged', last(/список языков|язык окна выбран/))
    click(pid, 'Window language')
    check(!!await until(() => /список языков открыт/.test(logText()), 8000), 'LG2 the list opened for the pick', last(/список языков/))
    const pick = click(pid, 'Русский')
    check(/^pressed/.test(pick), 'LG2 «Русский» picked from the list', pick)
    check(!!await until(() => /язык окна выбран игроком: Ru/.test(logText()), 8000), 'LG2 the switch chose Russian', last(/язык окна/))
    check(/список языков закрыт/.test(logText()), 'LG2 the list closed by the pick', last(/список языков/))
    // The switch logs its choice before the window re-renders: wait for the re-render's own line (run 15:52 read it too early).
    check(!!await until(() => last(/экран после смены языка/).includes('Лаунчер не нашёл игру'), 8000), 'LG2 the whole window re-rendered in Russian without a restart', last(/экран после смены языка/))
    check(existsSync(path.join(STATE, 'language.txt')) && readFileSync(path.join(STATE, 'language.txt'), 'utf8').trim() === 'ru', 'LG2 the choice saved in the stand state folder', '')
    check(!!await until(() => readdirSync(FRAMES).some(n => /-lang_ru/.test(n)), 8000), 'LG2 a frame of the re-rendered window', readdirSync(FRAMES).join(', '))
    killPid(pid)
    writeFileSync(LOG, '')
    pid = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: d, KRINIK_LAUNCHER_SYSTEM_LANG: 'en-US' })
    check(!!await screenIs('notfound'), 'LG3 the next start opens', last(/экран:/))
    check(!/по языку системы/.test(logText()) && last(/экран: notfound/).includes('Лаунчер не нашёл игру'), 'LG3 the saved Russian wins over the English system', last(/экран: notfound|язык окна/))
    killPid(pid)
    // LG1b (criterion 11): any other system language (de-DE), no saved choice — English.
    writeFileSync(LOG, '')
    pid = launch(lone(), { KRINIK_LAUNCHER_SEARCH_ROOTS: d, KRINIK_LAUNCHER_SYSTEM_LANG: 'de-DE', KRINIK_LAUNCHER_STATE_DIR: path.join(C, 'state_de') })
    check(!!await screenIs('notfound') && /язык окна по языку системы de-DE: En/.test(logText()) && last(/экран: notfound/).includes('The launcher did not find the game'),
      'LG1b a German system, no saved choice — English', last(/язык окна|экран: notfound/))
    killPid(pid)
  },
}

async function steamCase(old) {
  const s = path.join(C, 'steam'), g = steam(s, path.join(C, 'lib2'), { old })
  await foundCase({ KRINIK_LAUNCHER_STEAM: s }, g, old ? 'G1b the old libraryfolders.vdf' : 'G1 the second Steam library')
  check(!/76561190000000042/.test(logText()), 'G1 the SteamID of the manifest is not in the log', '')
}

async function standFeed(extra = []) {
  const fd = feed(['--build', '1.0.1', '--parts', ST.parts, ...extra])
  check(await ready(fd.url), 'the test feed came up', fd.url)
  return fd
}

// The game found where it lies; the window shows its folder, version and the build to download.
async function foundCase(env, g, name) {
  const fd = await standFeed()
  const pid = launch(lone(), { KRINIK_LAUNCHER_FEED: fd.url, ...env })
  check(!!await until(() => logText().includes('найдена игра: ' + g), 25000), `${name}: the log names the found folder`, last(/найдена игра/))
  check(!!await screenIs('found-nofiles', 20000), `${name}: the screen «found-nofiles»`, last(/экран:/))
  const l = last(/экран: found-nofiles/)
  check(l.includes(`Папка игры: ${g}`) && l.includes('Версия игры: 3.1.1') && l.includes('Сборка: 1.0.1 для игры 3.1.1') && /Нужно скачать: \d/.test(l),
    `${name}: folder, version, build and size on the screen`, l)
  check(!!await until(() => readdirSync(FRAMES).some(n => /found-nofiles/.test(n)), 8000), `${name}: a frame`, readdirSync(FRAMES).join(', '))
  killPid(pid)
}

// The time budget of case perf, read from the «perf: <ms since start> <what> <ms> ms» lines of the launcher's log; a timed copy of the sources writes
// «<Class>[<name>|<text>].OnPaint <w>x<h>» — the brackets and the size are dropped, so the same judge reads both. [NOT-TESTED]
const FRAME_MS = 16
// Only the FIRST launcher is judged (judge 2026-11-20, round 5, finding 2): the case ends with the bundle's own launcher, which inherits
// KRINIK_LAUNCHER_PERF and writes into the same log; since then every log line carries «[pid]», and the rows of other pids are dropped. A log
// without pids (a timed copy of the older sources) is read whole, as before.
function perfBudget() {
  const all = []
  for (const line of logText().split(/\r?\n/)) {
    const pid = (line.match(/^\S+ \[(\d+)\] /) || [])[1]
    const m = /perf: (\d+) (\S+?)(?:\[[^\]]*\])?(\.OnPaint)?(?: \d+x\d+)? ([\d.,]+) ms/.exec(line)
    if (m) all.push({ pid, what: m[2] + (m[3] || ''), ms: Number(m[4].replace(',', '.')), line })
    else if (/экран: /.test(line)) all.push({ pid, screen: (line.match(/экран: (\S+)/) || [])[1] })
  }
  // The launcher under test writes the FIRST timed line; its pid (or its having none — an older timed copy) picks the rows (judge round 6, finding 2: a
  // stand bundled with a newer launcher made the bundle's pid «first» and dropped every line of a pid-less launcher under test).
  const head = all.find(r => r.what) || {}
  const first = head.pid
  const rows = all.filter(r => r.pid === first)
  check(true, 'P· the judged launcher', first ? `pid ${first}; other pids dropped: ${[...new Set(all.filter(r => r.pid !== first).map(r => r.pid || 'none'))].join(', ') || 'none'}` : 'pid-less lines (an older timed copy); lines with a pid dropped')
  const timed = rows.filter(r => r.what)
  check(timed.some(r => r.what === 'Launcher.Refresh'), 'P0 the launcher wrote its timers (KRINIK_LAUNCHER_PERF=1)', `${timed.length} timed lines`)
  const renders = timed.filter(r => r.what === 'MetalWindow.Render')
  check(renders.length >= 1 && renders.length <= 2, 'P1 the picture rendered at most twice in the whole flow (birth, the found game\'s version)',
    renders.map(r => r.ms + ' ms').join(', ') || 'none')
  const refreshes = timed.filter(r => r.what === 'Launcher.Refresh').slice(1)
  const slowRefresh = refreshes.filter(r => r.ms > FRAME_MS)
  check(refreshes.length > 0 && slowRefresh.length === 0, `P2 every refresh after the first fits ${FRAME_MS} ms`, refreshes.map(r => r.ms).join(', '))
  let inDownload = false, seen = 0
  const ticks = []
  for (const r of rows) {
    if (r.screen) { inDownload = r.screen === 'download'; seen = 0; continue }
    // The off-screen stand window gets no WM_PAINT; the list's paints here are the frames' Print — the same PaintNow, so the same cost (2026-11-20).
    if (inDownload && (r.what === 'StatePanel.OnPaint' || r.what === 'StatePanel.Print') && seen++ > 0) ticks.push(r.ms)
  }
  check(ticks.length > 0 && ticks.every(ms => ms <= FRAME_MS), `P3 every state-list paint of the download after its first fits ${FRAME_MS} ms`,
    ticks.join(', ') || 'no download repaint seen')
}

async function freshCase({ beside = false, cut = 0, rate = 0, stop = false, range416 = false, status = [], extraEnv = {} }) {
  const [d] = roots('driveD'), g = game(path.join(d, 'Games', 'Conan Exiles'))
  const exe = lone()
  if (beside) for (const n of readdirSync(ST.parts)) copyFileSync(path.join(ST.parts, n), path.join(path.dirname(exe), n))
  const fd = await standFeed([...(cut ? ['--cut', String(cut)] : []), ...(rate ? ['--rate', String(rate)] : []), ...(range416 ? ['--range416'] : []),
                              ...(status.length ? ['--status', status.join(',')] : [])])
  const env = { KRINIK_LAUNCHER_SEARCH_ROOTS: d, KRINIK_LAUNCHER_FEED: fd.url, ...extraEnv }
  let pid = launch(exe, env)
  const want = beside ? 'found-files' : 'found-nofiles'
  check(!!await screenIs(want, 25000), `the screen «${want}»`, last(/экран:/))
  const asked = () => (fd.text().match(/GET \/file\//g) || []).length
  click(pid, 'Установить сборку')
  if (beside) {
    // The «verify» screen itself is not asserted: 4.7 MB of stand parts hash in less than one 250 ms tick of the window (run 15:47:07); the bar of the
    // check is seen only with big parts (stand.mjs --big).
    check(!!await until(() => /лежат рядом с лаунчером: .* скачивание пропущено/.test(logText()), 15000), 'D2 the log says the parts beside are used, the download skipped', last(/скачивание пропущено/))
  }
  else {
    check(!!await screenIs('download', 15000), 'the download runs on the bar', last(/экран:/))
    if (rate && !cut && !stop) {
      // Criterion 7: the numbers move between two frames of the download.
      const two = await until(() => { const f = logText().match(/кадр \d+_download_t\d+.*/g) || []; return f.length >= 2 ? f : null }, 30000)
      const amounts = (two || []).map(l => (l.match(/Скачано: ([^·]+)/) || [])[1])
      check(!!two && amounts[0] !== amounts[amounts.length - 1], 'D1 the amount moves between two frames', (two || []).join(' || ').slice(0, 400))
      check(!!two && two.some(l => /Скорость: \d/.test(l)) && two.some(l => /Осталось времени: \d/.test(l)) && two.every(l => /Прошло времени: \d/.test(l)),
        'D1 speed, time left and time spent shown', (two || []).pop())
    }
  }
  if (cut) {
    check(!!await screenIs('neterror', 30000), 'D4 the broken connection — the screen «neterror»', last(/экран:/))
    const l = last(/экран: neterror/)
    check(l.includes('Связь с GitHub прервалась, и скачивание остановилось.') && /Скачано: \d/.test(l) && l.includes('Лаунчер сохранил скачанные файлы'), 'D4 the window says what happened and what is kept', l)
    check(/cut after/.test(fd.text()), 'D4 the feed did cut a file', '')
    // D4b (the judge 2026-11-18, finding 3): the launcher killed mid-download leaves no reason mark — the next start says only that the download is not
    // finished, never «the connection broke». The kill is simulated by removing the mark the cut wrote.
    killPid(pid)
    await wait(500)
    const marks = [path.dirname(exe), g].flatMap(r => readdirSync(r, { recursive: true }).filter(n => path.basename(String(n)) === '.krinik_stop').map(n => path.join(r, String(n))))
    check(marks.length === 1 && readFileSync(marks[0], 'utf8').trim() === 'net', 'D4b the cut wrote the reason mark «net»', marks.join(', '))
    for (const m of marks) unlinkSync(m)
    writeFileSync(LOG, '')
    pid = launch(exe, env)
    check(!!await screenIs('unfinished', 20000), 'D4b no mark — the screen «unfinished»', last(/экран:/))
    const u = last(/экран: unfinished/)
    check(u.includes('Лаунчер не закончил скачивание сборки.') && !u.includes('Связь с GitHub прервалась'), 'D4b the window says the download is not finished, not that the connection broke', u)
    click(pid, 'Продолжить скачивание')
  }
  if (range416) {
    check(!!await until(() => /answered 416/.test(fd.text()), 20000), 'D6 the feed answered the resume by Range with 416', (fd.text().match(/.*answered 416.*/) || ['none'])[0])
    check(!!await until(() => /\(416\), часть удалена и скачивается целиком/.test(logText()), 10000), 'D6 the launcher dropped the part and asked it whole', last(/416/))
  }
  for (const code of status) {
    check(!!await screenIs('neterror', 30000), `D6b the feed answered ${code} — the screen «neterror» with «Продолжить скачивание»`, last(/экран:/))
    check(fd.text().includes(`answered ${code}`), `D6b the feed did answer ${code}`, (fd.text().match(/.*answered \d+.*/g) || ['none']).join(' | '))
    writeFileSync(LOG, '')
    const again = click(pid, 'Продолжить скачивание')
    check(/^pressed/.test(again), `D6b «Продолжить скачивание» pressed after ${code}`, again)
  }
  if (stop) {
    await until(() => (logText().match(/кадр \d+_download/g) || []).length >= 1 && asked() >= 3, 30000)
    click(pid, 'Остановить')
    check(!!await screenIs('paused', 20000), 'D5 «Остановить» — the screen «paused»', last(/экран:/))
    check(last(/экран: paused/).includes('Вы остановили скачивание.'), 'D5 the window says the player stopped it', last(/экран: paused/))
    killPid(pid)
    await wait(500)
    writeFileSync(LOG, '')
    pid = launch(exe, env)
    check(!!await screenIs('paused', 20000), 'D5 after a restart the stop is still shown, with what is downloaded', last(/экран:/))
    // D5b (the judge 2026-11-18, round 2, finding 5): a refusal before the start keeps the stop reason — the game runs (a stand-in named ConanSandbox.exe,
    // a hidden program that only waits), «Продолжить скачивание» is refused, and the screen is still «paused», not «unfinished».
    const fakeDir = path.join(C, 'fakegame'), fakeExe = path.join(fakeDir, 'ConanSandbox.exe')
    mkdirSync(fakeDir, { recursive: true })
    if (!existsSync(fakeExe)) copyFileSync(stub('hang'), fakeExe)
    const fake = spawn(fakeExe, [], { stdio: 'ignore' })
    children.push(fake.pid)
    await wait(500)
    writeFileSync(LOG, '')
    click(pid, 'Продолжить скачивание')
    const refused = dialog(pid, 'first', 15)
    check(!!refused && refused.includes('Игра запущена'), 'D5b the running game refuses the resume', refused || 'no box')
    await wait(1000)
    const after = last(/экран:/)
    check(after.includes('экран: paused ') && !/экран: unfinished/.test(logText()), 'D5b after the refusal the screen is still «paused» (the stop reason kept)', after)
    killPid(fake.pid)
    await wait(500)
    click(pid, 'Продолжить скачивание')
  }
  check(!!await until(() => /сборка 1\.0\.1 поставлена/.test(logText()), 120000, 500), 'the log says build 1.0.1 is installed', logText().trim().split('\n').slice(-2).join(' | '))
  check(/модов в строках установщика 2 из 2/.test(logText()), 'the install bar counted every mod', last(/модов в строках установщика/))
  if (!beside) check(/хвост архива проверен/.test(logText()), 'the tail of the archive was checked before the download', last(/хвост архива/))
  if (beside) check(asked() === 0, 'D2 no file was asked of the feed', `${asked()} file requests`)
  // The tail check (HasZipEnd) asks the LAST part by Range on every download, so «any Range request» could not fail (the judge 2026-11-20, round 3,
  // finding 7): the resumed part is a Range request from a byte past 0 on a part other than the last one. Only the cut case is asked: its break falls
  // inside the first file by construction; a «stop» may land between two parts, and then the next part is rightly fetched whole (run 2026-11-20 10:30).
  if (cut) {
    const lastPart = String(readdirSync(ST.parts).filter(n => /\.zip\.\d{3}$/.test(n)).length).padStart(3, '0')
    const resumed = (fd.text().match(/GET \/file\/\S+\.zip\.\d{3} .*range=bytes=\d+-/g) || []).filter(l => {
      const [, n, from] = l.match(/\.zip\.(\d{3}) .*range=bytes=(\d+)-/)
      return n !== lastPart && Number(from) > 0
    })
    check(resumed.length > 0, 'the resumed part was asked by Range (a part other than the last, from a byte past 0)', resumed[0] || 'none')
  }
  const a = path.join(g, 'Mods', 'ModA', 'a.txt'), b = path.join(g, 'Mods', 'ModB', 'b.txt')
  check(existsSync(a) && readFileSync(a, 'utf8').trim() === 'mod A 1.0.1' && existsSync(b), 'the mods of 1.0.1 are in the game', existsSync(a) ? readFileSync(a, 'utf8').trim() : 'missing')
  check(existsSync(path.join(g, 'uninstall_krinik_build.cmd')), 'the uninstaller is in the game', '')
  check(!existsSync(path.join(g, `${ST.stem}_parts`)), 'the downloaded parts are gone', '')
  if (beside) check(readdirSync(path.dirname(exe)).filter(n => /\.zip\.\d{3}$/.test(n)).length === ST.volumes, 'D2 the player\'s own parts next to the launcher are kept', '')
  const newExe = path.join(g, ST.stem, 'KrinikConanLauncher.exe')
  const np = await until(() => pidOf(newExe), 15000)
  check(!!np, 'the new build\'s own launcher runs from the game folder', `pid ${np}`)
  check(!!await until(() => !alive(pid), 10000), 'the downloaded launcher closed', '')
  check(existsSync(path.join(DESK, 'Krinik fixture.lnk')), 'the stand desktop got the shortcut', readdirSync(DESK).join(', '))
  if (np) { children.push(np); killPid(np) }
}

// shot:<screen> — static frames of one screen at --dpi in both languages (rule 17): the language switch is pressed once after the first frame.
async function shot(screen) {
  const [d] = roots('driveD')
  let env = { KRINIK_LAUNCHER_SEARCH_ROOTS: d }, exe = lone()
  if (['found-nofiles', 'noversion', 'update', 'installed'].includes(screen) || screen === 'choose') {
    const fd = await standFeed(screen === 'update' ? [] : [])
    env.KRINIK_LAUNCHER_FEED = fd.url
  }
  if (screen === 'found-nofiles') game(path.join(d, 'Games', 'Conan Exiles'))
  if (screen === 'noversion') game(path.join(d, 'Games', 'Conan Exiles'), { cl: '390000' })
  if (screen === 'installed') game(path.join(d, 'Games', 'Conan Exiles'), { krinik: '1.0.1' })
  if (screen === 'update') game(path.join(d, 'Games', 'Conan Exiles'), { krinik: '1.0.0' })
  if (screen === 'choose') { game(path.join(d, 'Games', 'Conan Exiles')); game(path.join(d, 'Games', 'Conan Exiles 3.0.1'), { cl: '379176' }); game(path.join(d, 'Program Files', 'Conan Exiles'), { mods: true }) }
  const pid = launch(exe, env)
  const id = screen === 'choose' ? 'choose' : screen
  check(!!await screenIs(id, 25000), `shot ${screen}: the screen`, last(/экран:/))
  if (screen === 'choose') await until(() => readdirSync(FRAMES).some(n => /choose-modal/.test(n)), 8000)
  await wait(1500)
  const name = LANG === 'en' ? 'Window language' : 'Язык окна'
  if (screen !== 'choose') {
    // The dropdown: the field opens the list (its frame «<screen>-langlist» is the mockup screen «language»), then the other language is picked by its name.
    click(pid, name)
    check(!!await until(() => readdirSync(FRAMES).some(n => n.includes(`${screen}-langlist`)), 8000), `shot ${screen}: the open language list`, last(/список языков/))
    click(pid, LANG === 'en' ? 'Русский' : 'English')
    check(!!await until(() => /экран после смены языка/.test(logText()), 8000), `shot ${screen}: the other language`, last(/экран после смены языка/))
    await wait(1500)
  }
  killPid(pid)
}

const OWNER_STATE = path.join(process.env.LOCALAPPDATA || '', 'KrinikConanLauncher')
const ownerState = () => existsSync(OWNER_STATE) ? readdirSync(OWNER_STATE).sort().join(',') : 'absent'
const ownerBefore = ownerState()
const run = kase.startsWith('shot:') ? () => shot(kase.slice(5)) : cases[kase]
if (!run || !existsSync(EXE)) { console.log('usage: see the header'); process.exit(2) }
// The stand needs a machine with no Conan game running: the launcher's GameRunning() looks for the game's processes machine-wide (GAME_PROCESSES) and
// refuses every install and download while one runs — the batch of 2026-11-18 21:19–21:36 read the main session's real game as four broken cases and
// 56 FAIL lines (KUMM EXPERIENCE.md, 2026-11-20). Such a run is one named FAIL, before any window starts. [NOT-TESTED]
const gameProcs = (() => {
  try {
    return execFileSync('tasklist', ['/FO', 'CSV', '/NH'], { encoding: 'utf8' }).split(/\r?\n/).filter(l => /^"ConanSandbox/i.test(l))
      .map(l => l.split('","').slice(0, 2).join(' pid ').replace(/"/g, ''))
  } catch { return [] }
})()
if (gameProcs.length) {
  check(false, 'stand: no Conan game runs on this machine (the launcher refuses every install and download while one runs)', gameProcs.join(', '))
  console.log('1 FAILED'); process.exit(1)
}
writeFileSync(LOG, '')
// The owner's screen (2026-11-18 15:55: a stand window bottom-right, cut by the screen edges, no taskbar button, alive for 10 minutes): a watcher polls
// every visible window of every launcher under this case's folder for the whole case and records any rect touching a monitor (offscreen.ps1, proved red
// on a transparent 1x1 window, 15:5x). Every launcher under the case folder is closed by PID at the end — the ones the case started and the ones THEY
// started (the build's own launcher after an install).
const OFF = path.join(C, 'offscreen.txt'), OFF_STOP = path.join(C, 'offscreen.stop')
if (existsSync(OFF)) writeFileSync(OFF, '')
if (existsSync(OFF_STOP)) unlinkSync(OFF_STOP)
const watcher = spawn('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(HERE, 'offscreen.ps1'), '-Root', C, '-Out', OFF, '-Stop', OFF_STOP, '-Seconds', '900'], { stdio: 'ignore' })
function closeAll() {
  const out = execFileSync('powershell', ['-NoProfile', '-Command',
    `Get-CimInstance Win32_Process -Filter "Name='KrinikConanLauncher.exe'" | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith('${C.replace(/'/g, "''")}\\', [System.StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { $_.ProcessId }`],
    { encoding: 'utf8' }).trim()
  const pids = out ? out.split(/\s+/).map(Number) : []
  pids.forEach(killPid)
  return pids
}
// The case starts only when the watcher says «watching»: PowerShell compiles its code for ≈ 2 s, and a short case ended before the first poll (C1 «windows
// seen 0» on the case «around», 2026-11-18 18:40).
// A watcher that never got ready fails the case instead of letting it run unwatched (the judge 2026-11-18, round 2, finding 10).
until(() => existsSync(OFF) && /watching/.test(readFileSync(OFF, 'utf8')), 20000).then(ok => ok ? run() : check(false, 'the screen watcher got ready', existsSync(OFF) ? readFileSync(OFF, 'utf8').trim() || 'empty' : 'no output'))
  .catch(e => check(false, 'the case ran to its end', e.stack)).then(async () => {
  // Every case: no error inside the launcher (the 15:42 crash on an empty text path showed only as a box no row asked about).
  const err = (logText().match(/.*(ошибка в окне лаунчера|упала|самообновление упало).*/g) || [])
  check(err.length === 0, 'no error inside the launcher during the case', err[0] || 'none')
  // Criterion 12: the window's place — centred in the working area of its monitor and inside it — as the launcher computed it (the frames stand logs it,
  // then parks the window outside every monitor).
  const places = logText().match(/место окна: -?\d+,-?\d+ \d+x\d+ в рабочей области -?\d+,-?\d+ \d+x\d+/g) || []
  const bad = places.filter(l => {
    const [x, y, w, h, ax, ay, aw, ah] = l.match(/-?\d+/g).map(Number)
    // a window larger than the area starts at its top-left corner; otherwise it lies inside with equal margins (±1 px of integer division)
    if (w > aw || h > ah) return !(x === ax || w <= aw) || !(y === ay || h <= ah)
    const inside = x >= ax && y >= ay && x + w <= ax + aw && y + h <= ay + ah
    const centred = Math.abs((x - ax) - (ax + aw - x - w)) <= 1 && Math.abs((y - ay) - (ay + ah - y - h)) <= 1
    return !(inside && centred)
  })
  check(places.length > 0 && bad.length === 0, 'C12 the window is placed centred in the working area of its monitor, inside it', (bad[0] || places[0] || 'no line'))
  await wait(800)
  const left = closeAll()
  await wait(500)
  check(closeAll().length === 0, 'every launcher of the case is closed by PID at its end', `closed at the end: ${left.join(', ') || 'none'}`)
  writeFileSync(OFF_STOP, 'stop')
  await until(() => existsSync(OFF) && /windows seen/.test(readFileSync(OFF, 'utf8')), 15000)
  const off = existsSync(OFF) ? readFileSync(OFF, 'utf8') : ''
  check(/windows seen [1-9]/.test(off) && !/ON SCREEN/.test(off), "C1 no window of the case ever touched a monitor (the owner's screen)", off.trim().split(/\r?\n/).slice(-2).join(' | ') || 'no watcher output')
  try { watcher.kill() } catch {}
  check(ownerState() === ownerBefore, "the owner's %LOCALAPPDATA%\\KrinikConanLauncher is untouched", `${ownerBefore} -> ${ownerState()}`)
  console.log(failed ? `${failed} FAILED` : 'ALL PASS'); process.exit(failed ? 1 : 0)
})
