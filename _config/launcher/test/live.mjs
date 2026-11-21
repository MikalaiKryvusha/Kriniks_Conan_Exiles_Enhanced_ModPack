// live.mjs — the launcher's buttons pressed on a LIVE window against the local test feed (KUMM plan 54, cases N1–N3, S1–S2, B1–B3).
// The window is shown without taking the focus (KRINIK_LAUNCHER_NOACTIVATE=1) and pressed by BM_CLICK through click.ps1: no real input, the owner keeps
// his keyboard. Every wait is bounded; on a timeout the case fails and its processes are killed by PID.
//
//   node live.mjs notes   <dir with the exe>                      N1 + N2 (dry mode: links are logged, not opened)
//   node live.mjs offline <dir with the exe>                      N3
//   node live.mjs self    <dir with the 1.0.0 exe> <1.0.1 exe> [--forge | --garbage | --dies | --hang | --quick]
//                                                                 S1 / S2 / S3 (--garbage: the exe arg is not a program) / L4 / L6 (--hang: the asset
//                                                                 starts and never shows a window) / L7 (--quick: the player closes the new window at once)
//   node live.mjs revert  <dir with the 1.0.1 exe> <1.0.0 exe> [--locked]   L5 / L8 (--locked: .old is held open, the revert stops half-way)
//   node live.mjs oldguard <dir with the exe>                     L9 (the previous-bundle delete offer refuses a folder that is not a bundle; default «Нет»)
//   node live.mjs build   <stand JSON from stand.mjs> [--stop] [--close] [--broken] [--big] [--game-starts] [--drop-last]
//                                                                 B1 / B2 / B5 / B4 / B3 / B7′ (the game started mid-download) / B5′
//   node live.mjs delta   <stand JSON from stand.mjs --delta> [--decline | --stop | --first | --corrupt [--volumes] | --digest-off | --bad-list | --nolinks |
//                         --outside | --skip (a stand from stand.mjs --delta --skip)]
//                                                                 D1 / D2 / D3 / D4 / D5a-b / D5c / D6 / D7 / D8 / D9 (testcases/TC_conan_launcher_delta_update_2026-11-21.md)
//   node live.mjs uninstall <stand JSON from stand.mjs> [<another launcher exe>]   U-X (KUMM bugs/115: the uninstaller's console closed by its X)
// Prints one line per check «PASS|FAIL <what> — <observed>». Exit 0 — all PASS.
// [NOT-TESTED]
import { spawn, execFileSync } from 'node:child_process'
import { existsSync, readFileSync, writeFileSync, mkdirSync, readdirSync, statSync, renameSync, copyFileSync, utimesSync } from 'node:fs'
import { createHash } from 'node:crypto'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const [mode, a1, a2] = process.argv.slice(2)
const flag = f => process.argv.includes(f)
let failed = 0
const check = (ok, what, seen) => { if (!ok) failed++; console.log(`${ok ? 'PASS' : 'FAIL'} ${what} — ${seen}`) }
const sha = f => createHash('sha256').update(readFileSync(f)).digest('hex')
const wait = ms => new Promise(r => setTimeout(r, ms))
const killPid = pid => { try { execFileSync('taskkill', ['/PID', String(pid), '/T', '/F'], { stdio: 'ignore' }) } catch {} }
const children = []
process.on('exit', () => children.forEach(killPid))

function feed(args) {
  const port = 20000 + Math.floor(Math.random() * 20000)
  const log = path.join(TMP, `feed_${mode}.log`)
  const p = spawn('node', [path.join(HERE, 'feed.mjs'), '--port', String(port), '--log', log, ...args], { stdio: 'ignore' })
  children.push(p.pid)
  return { url: `http://127.0.0.1:${port}/releases`, log, pid: p.pid }
}

// Every start gets the stand's own state folder (crash «seen» stamps): only the crash case set it, and the build cases wrote 8 files into the owner's
// %LOCALAPPDATA%\KrinikConanLauncher (judge 2026-11-18 08:4x; KUMM memory test-stands-never-touch-owner-folders). A case may still pass its own.
function launch(exe, extraEnv, args = []) {
  // Since KUMM plans/57 a launcher with no game around it searches the drives and Steam: the stand gives it an empty folder for both, so no case reads
  // the owner's games or opens the copies list over the plate; the window language is pinned to Russian (the cases read Russian captions).
  mkdirSync(path.join(TMP, 'noroots'), { recursive: true })
  // The frames stand mode (KRINIK_LAUNCHER_FRAMES): every window and every question box of the launcher stays outside the monitors — this stand showed its
  // windows on the owner's screen (plan 57 criterion 13, the owner 2026-11-18 15:55; moved to frames 2026-11-18 18:5x).
  mkdirSync(path.join(TMP, 'frames'), { recursive: true })
  const env = { ...process.env, TEMP: TMP, TMP, KRINIK_LAUNCHER_NOACTIVATE: '1', KRINIK_LAUNCHER_STATE_DIR: path.join(TMP, 'state'),
    KRINIK_LAUNCHER_FRAMES: path.join(TMP, 'frames'),
    KRINIK_LAUNCHER_SEARCH_ROOTS: path.join(TMP, 'noroots'), KRINIK_LAUNCHER_STEAM: path.join(TMP, 'nosteam'), KRINIK_LAUNCHER_SYSTEM_LANG: 'ru-RU', ...extraEnv }
  const p = spawn(exe, args, { cwd: path.dirname(exe), env, stdio: 'ignore', detached: false })
  children.push(p.pid)
  return p.pid
}
// The player's X on the launcher window (WM_SYSCOMMAND SC_CLOSE, as Alt+F4 and the system X send it) — waits for the window up to 20 s.
const closeWindow = pid => execFileSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(HERE, 'click.ps1'), '-ProcessId', String(pid), '-Close'], { encoding: 'utf8' }).trim()
// The quick-close cases need the close to land BEFORE the window's «alive» timer: the stand stretches the timer (KRINIK_LAUNCHER_SETTLE_MS), so a slow
// PowerShell start cannot make the case pass by the timer instead of the close; the log line names which of the two settled.
const SLOW_SETTLE = { KRINIK_LAUNCHER_SETTLE_MS: '15000' }
// Cases that need no feed point the launcher at a closed local port: no stand run asks the real GitHub (the courtesy rule; the launcher logs «лента не ответила»).
const NOFEED = { KRINIK_LAUNCHER_FEED: 'http://127.0.0.1:9/releases' }
const stub = (out, kind) => execFileSync('python', ['-I', '-X', 'utf8', path.join(HERE, 'make_stub.py'), out, kind], { encoding: 'utf8' }).trim()

// The feed hashes its assets before it listens (2 GB parts take seconds): the launcher starts only after /ready answers.
async function ready(url) {
  for (const end = Date.now() + 300000; Date.now() < end; await wait(500)) {
    try { if ((await fetch(url.replace(/\/releases$/, '/ready'))).ok) return true } catch {}
  }
  return false
}

const LOG = () => path.join(TMP, 'KrinikConanLauncher.log')
const logText = () => existsSync(LOG()) ? readFileSync(LOG(), 'utf8') : ''
async function until(test, ms, step = 250) {
  for (const end = Date.now() + ms; Date.now() < end; await wait(step)) { const v = test(); if (v) return v }
  return null
}
// A button by its caption; the two «Что нового» share one, so index 0 is the left (game), 1 the right (build).
const click = (pid, name, index = 0) => execFileSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(HERE, 'click.ps1'), '-ProcessId', String(pid), '-Name', name, '-Index', String(index)], { encoding: 'utf8' }).trim()
function dialog(pid, press, timeoutSec = 60) {
  const out = path.join(TMP, 'dialog.txt')
  execFileSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(HERE, 'click.ps1'), '-ProcessId', String(pid), '-Dialog',
    '-Out', out, ...(press ? ['-Press', press] : []), '-TimeoutSec', String(timeoutSec)], { encoding: 'utf8' })
  return readFileSync(out, 'utf8').replace(/\s+/g, ' ').trim()
}
// null — no box within the time (click.ps1 exit 3): the «nothing is asked» checks.
function noDialog(pid, timeoutSec) { try { return dialog(pid, null, timeoutSec) } catch { return null } }
// The Windows PID of a running launcher by its exe path (the new launcher is started by the old one, not by us). `not` — a PID to skip: since epic 55 B2
// the old launcher stays alive until the new one signals, and Windows keeps the creation path of a renamed exe, so both match the path (stand 2026-11-17 20:55).
function pidOf(exe, not = 0) {
  const out = execFileSync('powershell', ['-NoProfile', '-Command',
    `Get-CimInstance Win32_Process -Filter "Name='KrinikConanLauncher.exe'" | Where-Object { $_.ExecutablePath -eq '${exe.replace(/\//g, '\\').replace(/'/g, "''")}' } | ForEach-Object { $_.ProcessId }`],
    { encoding: 'utf8' }).trim()
  const pids = out ? out.split(/\s+/).map(Number).filter(p => p !== not) : []
  return pids.length ? pids[0] : null
}

let TMP
async function main() {
  if (mode === 'notes' || mode === 'offline') {
    const dir = path.resolve(a1), exe = path.join(dir, 'KrinikConanLauncher.exe')
    TMP = path.join(dir, 'tmp'); mkdirSync(TMP, { recursive: true }); writeFileSync(LOG(), '')
    const f = feed(mode === 'notes' ? ['--build', '1.0.1'] : ['--refuse'])
    if (!await ready(f.url)) { check(false, 'the test feed came up', 'no answer on /ready'); return }
    const pid = launch(exe, { KRINIK_LAUNCHER_FEED: f.url, KRINIK_LAUNCHER_DRY: '1' })
    check(!!await until(() => /лента/.test(logText()), 15000), 'the feed was read after the window showed', logText().trim().split('\n').pop())
    click(pid, 'Что нового', 1)
    const want = mode === 'notes' ? /открыл бы http:\/\/127\.0\.0\.1:\d+\/page\/v1\.0\.1/ : /открыл бы https:\/\/github\.com\/MikalaiKryvusha\/Kriniks_Conan_Exiles_Enhanced_ModPack\/releases\/latest/
    check(!!await until(() => want.test(logText()), 10000), `«Что нового» of the build (${mode})`, (logText().match(/открыл бы .*/g) || ['no line']).pop())
    if (mode === 'notes') {
      click(pid, 'Что нового', 0)
      check(!!await until(() => /открыл бы https:\/\/store\.steampowered\.com\/news\/app\/440900\/view\/1846018067929785/.test(logText()), 10000),
        '«Что нового» of the game', (logText().match(/открыл бы .*/g) || ['no line']).pop())
    }
    killPid(pid)
    return
  }

  if (mode === 'self') {
    const dir = path.resolve(a1), exe = path.join(dir, 'KrinikConanLauncher.exe'), fresh = path.resolve(a2)
    TMP = path.join(dir, 'tmp'); mkdirSync(TMP, { recursive: true }); writeFileSync(LOG(), '')
    const before = sha(exe), target = sha(fresh)
    const f = feed(['--launcher', '1.0.1', '--exe', fresh, ...(flag('--forge') ? ['--forge'] : [])])
    if (!await ready(f.url)) { check(false, 'the test feed came up', 'no answer on /ready'); return }
    const pid = launch(exe, { KRINIK_LAUNCHER_FEED: f.url, ...(flag('--quick') ? SLOW_SETTLE : {}) })
    check(!!await until(() => /лаунчер 1\.0\.1 \(у нас 1\.0\.0\)/.test(logText()), 15000), 'the plate saw launcher 1.0.1', logText().trim().split('\n').pop())
    click(pid, 'Обновить лаунчер')
    // --hang (case L6, epic 55 B7): the asset starts and never shows a window nor exits — after 30 s the old launcher kills it and puts itself back.
    if (flag('--hang')) {
      const text = dialog(pid, 'first', 60)
      check(/не открыл окно/.test(text) && /вернулся на место/.test(text), 'a new launcher that hangs is rolled back after 30 s', text)
      // judge B7 round 2 R6: «(код -1)» is what Process.Kill leaves — an asset that exited by itself shows its own code (L4: 0), so the case proves the kill.
      check(/не показал окно за 30 с \(код -1\)/.test(logText()), 'the log names the 30 s wait and the kill (code -1)', (logText().match(/не показал окно.*/g) || ['no line']).pop())
      check(sha(exe) === before, 'the exe is the old one again', sha(exe).slice(0, 12))
      check(!existsSync(exe + '.new') && !existsSync(exe + '.old'), 'no .new / .old left', readdirSync(dir).join(', '))
      check(pidOf(exe, pid) === null, 'the hung process is gone', String(pidOf(exe, pid)))
      check(alive(pid), 'the old launcher stays open', '')
      killPid(pid)
      return
    }
    // --quick (case L7, epic 55 B7 п. 1): the player closes the new launcher's window at once (the X, as «Играть» does) — that is «alive», not a crash:
    // the old launcher must leave, the new exe stay, and the start counter must not grow.
    if (flag('--quick')) {
      const newPid = await until(() => pidOf(exe, pid), 20000)
      check(!!newPid, 'the new launcher started', `pid ${newPid}`)
      if (newPid) { children.push(newPid); closeWindow(newPid) }
      check(!!await until(() => !alive(pid), 30000), 'the old launcher exits (no rollback)', `old pid ${pid}`)
      check(/окно закрыто игроком — сигнал прежнему лаунчеру/.test(logText()), 'the close (not the timer) signalled «alive»', (logText().match(/(окно живо|окно закрыто).*/g) || ['no line']).pop())
      check(!/не открыл окно|не показал окно/.test(logText()), 'no rollback in the log', '')
      check(existsSync(exe) && sha(exe) === target, 'the exe is the 1.0.1 build', existsSync(exe) ? sha(exe).slice(0, 12) : 'missing')
      check(!existsSync(exe + '.starting'), 'the start counter is cleared', readdirSync(dir).join(', '))
      check(existsSync(exe + '.old'), 'the .old exe is kept after the first start', readdirSync(dir).join(', '))
      // The second ordinary start, closed at once too: the commit happens on the close — .old goes, no counter left. Only meaningful with .old there before
      // (stand 22:06: after a rollback there was no .old, and «.old gone» passed for nothing).
      const hadOld = existsSync(exe + '.old')
      const second = launch(exe, { ...SLOW_SETTLE, KRINIK_LAUNCHER_FEED: f.url })
      closeWindow(second)
      check(!!await until(() => !alive(second), 15000), 'the second start closed by the player', '')
      check(hadOld && !existsSync(exe + '.old') && !existsSync(exe + '.starting'), 'the quick-closed second start removed .old (commit), no counter',
        `.old before: ${hadOld}; now: ${readdirSync(dir).join(', ')}`)
      check(/окно закрыто игроком — прежний лаунчер больше не нужен/.test(logText()), 'the log tells the commit on the close', (logText().match(/прежний лаунчер больше не нужен.*/g) || ['no line']).pop())
      return
    }
    // --garbage (case S3): the asset is not a program but its digest matches — the swap happens, the start fails, the old exe must come back.
    if (flag('--garbage')) {
      const text = dialog(pid, 'first')
      check(/не запустился/.test(text) && /вернулся на место/.test(text), 'a new launcher that does not start is rolled back', text)
      check(sha(exe) === before, 'the exe is the old one again', sha(exe).slice(0, 12))
      check(!existsSync(exe + '.new') && !existsSync(exe + '.old'), 'no .new / .old left', readdirSync(dir).join(', '))
      check(alive(pid), 'the old launcher stays open', '')
      killPid(pid)
      return
    }
    if (flag('--forge')) {
      const text = dialog(pid, 'first')
      check(/не совпал/.test(text), 'the forged asset is refused with a box', text)
      check(sha(exe) === before, 'the exe is unchanged', sha(exe).slice(0, 12))
      check(!existsSync(exe + '.new') && !existsSync(exe + '.old'), 'no .new / .old left', readdirSync(dir).join(', '))
      killPid(pid)
      return
    }
    // --dies (case L4, epic 55 B2): the asset is a real program that starts and exits at once (no launcher window) — the old launcher must wait for the
    // «alive» signal, not get it, put itself back and stay open.
    if (flag('--dies')) {
      const text = dialog(pid, 'first')
      check(/не открыл окно/.test(text) && /вернулся на место/.test(text), 'a new launcher that starts and dies is rolled back', text)
      check(sha(exe) === before, 'the exe is the old one again', sha(exe).slice(0, 12))
      check(!existsSync(exe + '.new') && !existsSync(exe + '.old'), 'no .new / .old left', readdirSync(dir).join(', '))
      check(alive(pid), 'the old launcher stays open', '')
      killPid(pid)
      return
    }
    const swapped = await until(() => existsSync(exe) && sha(exe) === target, 20000)
    check(!!swapped, 'the exe is the 1.0.1 build (SHA-256 = asset)', sha(exe).slice(0, 12) + ' vs ' + target.slice(0, 12))
    const newPid = await until(() => pidOf(exe, pid), 15000)
    check(!!newPid && newPid !== pid, 'a new launcher process runs from the same path', `pid ${newPid} (old ${pid})`)
    // Since epic 55 B2 the old launcher leaves only after the new one signalled «alive» (3 s after its window), and .old stays until the new one's
    // second ordinary start (the commit).
    check(!!await until(() => !alive(pid), 40000), 'the old launcher exits after the new one signalled', `old pid ${pid}`)
    check(/окно живо — сигнал прежнему лаунчеру/.test(logText()), 'the new launcher signalled «alive»', (logText().match(/окно живо.*/g) || ['no line']).pop())
    check(existsSync(exe + '.old'), 'the .old exe is KEPT after the first start', readdirSync(dir).join(', '))
    check(/лаунчер обновлён до 1\.0\.1/.test(logText()), 'the log tells the swap', '')
    if (newPid) { children.push(newPid); killPid(newPid) }
    const second = launch(exe, { KRINIK_LAUNCHER_FEED: f.url })
    check(!!await until(() => !existsSync(exe + '.old'), 20000), 'the second ordinary start removes .old (commit)', readdirSync(dir).join(', '))
    check(/удалён прежний лаунчер/.test(logText()), 'the log tells the commit', '')
    killPid(second)
    return
  }

  // case L5 (epic 55 B2): a launcher swapped in by a self-update twice never reached a settled window while .old is kept → the next start brings the old
  // launcher back (the antivirus-killed-after-the-signal case). a1 — a folder whose exe is the NEW build; a2 — the old exe.
  if (mode === 'revert') {
    const dir = path.resolve(a1), exe = path.join(dir, 'KrinikConanLauncher.exe'), oldExe = path.resolve(a2)
    TMP = path.join(dir, 'tmp'); mkdirSync(TMP, { recursive: true }); writeFileSync(LOG(), '')
    const oldSha = sha(oldExe), newSha = sha(exe)
    writeFileSync(exe + '.old', readFileSync(oldExe))
    writeFileSync(exe + '.starting', '2')
    // --locked (case L8, epic 55 B7 п. 3): .old is held open without sharing (an antivirus scan) — the revert stops half-way; the exe's place must not stay
    // empty: the new one goes back, .old stays as the spare.
    if (flag('--locked')) {
      const holder = spawn('powershell', ['-NoProfile', '-Command',
        `$f = [System.IO.File]::Open('${(exe + '.old').replace(/'/g, "''")}', 'Open', 'Read', 'None'); Start-Sleep -Seconds 25; $f.Close()`], { stdio: 'ignore' })
      children.push(holder.pid)
      await wait(3000)   // PowerShell start: the file must be held before the launcher starts
      const pid = launch(exe, NOFEED)
      check(!!await until(() => /возврат прежнего лаунчера не удался/.test(logText()), 15000), 'the revert failed on the held .old', (logText().match(/возврат прежнего.*/g) || ['no line']).pop()?.slice(0, 160))
      check(/новый лаунчер вернулся на своё место/.test(logText()), 'the log tells the new one went back', '')
      check(existsSync(exe) && sha(exe) === newSha, 'the exe place is not empty — the new launcher is there', existsSync(exe) ? sha(exe).slice(0, 12) : 'MISSING')
      check(!existsSync(exe + '.bad'), 'no .bad left', readdirSync(dir).join(', '))
      check(existsSync(exe + '.old'), '.old kept as the spare', readdirSync(dir).join(', '))
      check(!!await until(() => alive(pid), 5000), 'the launcher runs on (its window)', `pid ${pid}`)
      // judge round 3 R7: the lock goes away, the window passes its 3 s settle — .old and the counter must STAY (keepOld): the run judged bad twice does
      // not commit itself; the next start tries the revert again. Before the fix this same settle deleted .old.
      killPid(holder.pid)
      check(!!await until(() => /встал на полпути/.test(logText()), 15000), 'the settle keeps the spare (keepOld)', (logText().match(/.*встал на полпути.*/g) || ['no line']).pop()?.slice(0, 160))
      await wait(2000)
      check(existsSync(exe + '.old') && existsSync(exe + '.starting'), '.old and the start counter stay after the settle', readdirSync(dir).join(', '))
      killPid(pid)
      return
    }
    const pid = launch(exe, NOFEED)
    check(!!await until(() => existsSync(exe) && sha(exe) === oldSha, 15000), 'the old launcher is back in place', sha(exe).slice(0, 12) + ' vs ' + oldSha.slice(0, 12))
    check(existsSync(exe + '.bad') && !existsSync(exe + '.old') && !existsSync(exe + '.starting'), 'the new one set aside as .bad, no .old / .starting', readdirSync(dir).join(', '))
    const back = await until(() => pidOf(exe, pid), 15000)
    check(!!back && back !== pid, 'the old launcher runs again', `pid ${back}`)
    check(/не дожил до спокойного окна — возвращаю прежний/.test(logText()), 'the log tells the revert', '')
    if (back) { children.push(back); await wait(5000); killPid(back) }
    check(!existsSync(exe + '.bad'), 'the old launcher removed .bad after its window settled', readdirSync(dir).join(', '))
    return
  }

  // case L9 (epic 55 B7 п. 4): «--old-bundle <dir>» offers the delete only for a folder that IS an unpacked bundle — named Krinik_…, no Saved / Content /
  // Binaries inside; the offer's default button is «Нет».
  if (mode === 'oldguard') {
    const dir = path.resolve(a1), exe = path.join(dir, 'KrinikConanLauncher.exe')
    TMP = path.join(dir, 'tmp'); mkdirSync(TMP, { recursive: true })
    const side = path.join(path.dirname(dir), path.basename(dir) + '_side')
    const make = (name, extra) => {
      const d = path.join(side, name)
      mkdirSync(path.join(d, 'pack'), { recursive: true })
      writeFileSync(path.join(d, 'pack', 'modpack.json'), JSON.stringify({ packVersion: '1.0.0' }))
      if (extra) mkdirSync(path.join(d, extra), { recursive: true })
      return d
    }
    for (const [name, extra, why] of [['MyGame', null, 'a folder not named Krinik_…'], ['Krinik_unpacked_here', 'Saved', 'a Krinik_ folder holding Saved'],
                                      ['Krinik_with_content', 'Content', 'a Krinik_ folder holding Content']]) {
      writeFileSync(LOG(), '')
      const d = make(name, extra)
      const pid = launch(exe, NOFEED, ['--old-bundle', d])
      check(noDialog(pid, 8) === null, `no delete offer for ${why}`, '')
      check(/не похожа на распакованный архив/.test(logText()), `the log tells the refusal (${name})`, (logText().match(/папку прежней сборки.*/g) || ['no line']).pop())
      check(existsSync(d), `${name} stays`, '')
      killPid(pid)
    }
    writeFileSync(LOG(), '')
    const ok = make('Krinik_fixture_0_9_0')
    const pid = launch(exe, NOFEED, ['--old-bundle', ok])
    const offer = dialog(pid, '7', 20)
    check(/Папка прежней сборки больше не нужна/.test(offer), 'a real bundle folder gets the offer', offer)
    check(/defbutton=7/.test(offer), 'the default button is «Нет»', (offer.match(/defbutton=\d+/) || ['none'])[0])
    check(!!await until(() => /папку прежней сборки оставили/.test(logText()), 5000) && existsSync(ok), '«Нет» keeps the folder', '')
    killPid(pid)
    return
  }

  // case B16′ (epic 55 B8): the game crashed last time — the next launcher start offers the report. A fake game root (ConanSandbox.exe + Saved\Crashes),
  // the launcher in it, dry (links and the report tool are only logged). C1 the first start only remembers; C2 the same crash — no box; C3 a newer crash —
  // the box, default «Да», «Да» runs collect_report.cmd and opens a new issue; C4 the same — no box; C5 a newer crash, «Нет» — recorded, C6 no box again.
  if (mode === 'crash') {
    const dir = path.resolve(a1), exe = path.join(dir, 'KrinikConanLauncher.exe')
    TMP = path.join(dir, 'tmp'); mkdirSync(TMP, { recursive: true }); writeFileSync(LOG(), '')
    writeFileSync(path.join(dir, 'ConanSandbox.exe'), '')
    writeFileSync(path.join(dir, 'collect_report.cmd'), '@echo off\n')
    const crashes = path.join(dir, 'ConanSandbox', 'Saved', 'Crashes')
    const crash = async name => { mkdirSync(path.join(crashes, name), { recursive: true }); await wait(1100) }
    const env = { ...NOFEED, KRINIK_LAUNCHER_DRY: '1', KRINIK_LAUNCHER_STATE_DIR: path.join(dir, 'state') }
    // judge round 3 R6: the log is cleared per start and the start waits for the offer's own decision line — a launcher that dies early cannot pass a «no box» check
    const start = async () => { writeFileSync(LOG(), ''); const pid = launch(exe, env); check(!!await until(() => /отчёты о падениях:|падение UECC/.test(logText()), 12000), 'the start reached the crash check', (logText().match(/отчёты о падениях.*|падение.*/g) || ['no line']).pop()); return pid }
    await crash('UECC-old')
    let pid = await start()
    check(noDialog(pid, 6) === null, 'C1 the first start asks nothing about an old crash', '')
    check(/запомнил последний \(UECC-old/.test(logText()), 'C1 the first start remembers the newest crash', (logText().match(/отчёты о падениях.*/g) || ['no line']).pop())
    killPid(pid)
    pid = await start()
    check(noDialog(pid, 6) === null, 'C2 the same crash — no box', '')
    killPid(pid)
    await crash('UECC-new')
    pid = await start()
    const box = dialog(pid, '6', 20)
    check(/Игра в прошлый раз закрылась с ошибкой/.test(box), 'C3 a newer crash — the box', box)
    check(/defbutton=6/.test(box), 'C3 the default button is «Да»', box.match(/defbutton=\d+/)?.[0] || 'none')
    // The start goes through the product's Start and carries the game folder (judge 2026-11-18: a Dry-only branch passed without -GameDir).
    check(!!await until(() => logText().includes(`collect_report.cmd -GameDir "${dir}"`), 8000), 'C3 «Да» runs collect_report.cmd with the game folder', (logText().match(/запустил бы.*/g) || ['no line']).pop())
    check(!!await until(() => /открыл бы https:\/\/github\.com\/[^/]+\/[^/]+\/issues\/new\?title=/.test(logText()), 8000), 'C3 «Да» opens a new issue with a title',
      (logText().match(/открыл бы.*/g) || ['no line']).pop())
    killPid(pid)
    pid = await start()
    check(noDialog(pid, 6) === null, 'C4 the reported crash — no box again', '')
    killPid(pid)
    await crash('UECC-newer')
    pid = await start()
    const box2 = dialog(pid, '7', 20)
    check(/закрылась с ошибкой/.test(box2), 'C5 the next crash — the box again', box2)
    check(!!await until(() => /UECC-newer: игрок отказался от отчёта/.test(logText()), 8000), 'C5 «Нет» is logged', '')
    killPid(pid)
    pid = await start()
    check(noDialog(pid, 6) === null, 'C6 a refused crash is not asked again', '')
    killPid(pid)
    return
  }

  // delta (KUMM plan 57 phase 6, cases D1–D8 of testcases/TC_conan_launcher_delta_update_2026-11-21.md): the release carries a per-file manifest
  // (stand.mjs --delta). D1: «Обновить сборку» → the files of the old bundle are hashed → the box names the real download → «Да» → only the changed
  // assets are asked of the feed, the unchanged pak comes from the old bundle by a hardlink, the build is installed, and the new launcher's offer to
  // delete the old bundle names the bytes the deletion frees. Flags: --decline D2 · --stop D3 (the launcher killed by PID mid-asset; the second start
  // resumes it by Range) · --first D4 (no build installed: D4b a first install from zero by the file list, D4a a reinstall over the bundle left in the game) · --corrupt
  // [--volumes] D5 (one asset's bytes never match its hash: the volumes, or a box when the release has none) · --bad-list D6 · --nolinks D7 (the disk
  // gives no hardlinks: the old files are copied and counted) · --outside D8 (the installed bundle lies outside the game folder). [NOT-TESTED]
  if (mode === 'delta') {
    const st = JSON.parse(readFileSync(path.resolve(a1), 'utf8'))
    const W = path.dirname(st.game)
    TMP = path.join(W, 'tmp'); mkdirSync(TMP, { recursive: true }); writeFileSync(LOG(), '')
    const mf = path.join(st.assets, 'manifest.json')
    const man = JSON.parse(readFileSync(mf, 'utf8'))
    const by = name => man.files.find(f => f.path.endsWith('/' + name))
    const same = by('same.pak'), change = by('change.pak'), huge = by('huge.pak')
    const unitSize = n => { for (const e of man.files) { if (e.asset === n) return e.size; for (const p of e.parts || []) if (p.asset === n) return p.size }
      const g = (man.groups || []).find(x => x.asset === n); return g ? g.size : -1 }
    const nb = path.join(st.game, st.stem), staging = nb + '.staging'
    const a = path.join(st.game, 'Mods', 'ModA', 'a.txt'), b = path.join(st.game, 'Mods', 'ModB', 'b.txt')
    const aText = () => existsSync(a) ? readFileSync(a, 'utf8').trim() : 'missing'
    const stagings = () => readdirSync(st.game).filter(n => /\.staging$/i.test(n))
    // «Нужно скачать 7,1 МБ» → 7.1 (MB): the stop-and-resume case compares the two boxes.
    const mbOf = s => { const m = /Нужно скачать ([\d\s ,]+) (Б|КБ|МБ|ГБ)/.exec(s || ''); if (!m) return NaN
      return Number(m[1].replace(/[\s ]/g, '').replace(',', '.')) * { Б: 1 / 1048576, КБ: 1 / 1024, МБ: 1, ГБ: 1024 }[m[2]] }
    // Each case reads only its own requests: D2 and D1 share a stand, and the feed's log was appended across them (D1 then saw D2's manifest download).
    writeFileSync(path.join(TMP, 'feed_delta.log'), '')
    const feedLog = path.join(TMP, 'feed_delta.log')
    const asked = () => (readFileSync(feedLog, 'utf8').match(/GET \/file\/[^ ]+/g) || []).map(s => decodeURIComponent(s.slice('GET /file/'.length)))
    const PLATE = /новейшая 1\.0\.1 \(у нас 1\.0\.0\), для этой игры 1\.0\.1/

    // D4 (plan 57 phase 6 step 6, the owner's answer C 2026-11-21 16:58: one format, the file list): no build installed; the stand's uninstaller runs
    // first; the player's downloaded launcher lies in the game root (the guide: unpack into the game folder).
    // D4b: a first install from ZERO — the old bundle is moved out of the game, so no file can seed — from a manifest-only release: every asset of the
    //      list is downloaded once, the build installs, the journal and the uninstaller are written.
    // D4a: the REINSTALL — the player uninstalls 1.0.1 and installs it again from a release with both sets; the 1.0.1 bundle folder stays in the game,
    //      so the file list takes every file from it: only the list downloads, never the volumes.
    // U-X2 (--leftover, judge round 4, finding 5; bugs/115): the uninstall ran outside the launcher and its console was closed by the X — the uninstaller
    // stays in the clean game with no journal. The launcher must see no installed build (Games.Describe, BuildUpdate.Installed): the first install of D4b
    // runs as for any clean game, and the new install writes its own journal.
    const uninstaller = path.join(st.game, 'uninstall_krinik_build.cmd'), journal = path.join(st.game, '_kumm_backup', 'journal.txt')
    const uninstall = () => execFileSync('cmd.exe', ['/d', '/s', '/c', `""${uninstaller}" < nul"`],
      { stdio: 'ignore', windowsVerbatimArguments: true, env: { ...process.env, KUMM_DESKTOP_DIR: st.desk } })
    if (flag('--first') || flag('--leftover')) {
      const body = readFileSync(uninstaller)
      uninstall()
      check(!existsSync(uninstaller) && !existsSync(a), 'the stand build is uninstalled before the first install', aText())
      if (flag('--leftover')) {
        writeFileSync(uninstaller, body)
        // an old time on the leftover: after the install the uninstaller must be the NEW one (judge round 5, NIT 4: the leftover alone passed the check)
        utimesSync(uninstaller, new Date(2000, 0, 1), new Date(2000, 0, 1))
        check(existsSync(uninstaller) && !existsSync(path.join(st.game, '_kumm_backup')), 'U-X2 the leftover uninstaller lies in the clean game, no journal', '')
      }
      const away = path.join(W, 'away', path.basename(st.bundleOld))
      mkdirSync(path.dirname(away), { recursive: true }); renameSync(st.bundleOld, away)
      const solo = path.join(st.game, 'KrinikConanLauncher.exe')
      copyFileSync(path.join(away, 'KrinikConanLauncher.exe'), solo)
      const allUnits = [...new Set(man.files.flatMap(e => e.asset ? [e.asset] : (e.parts || []).map(p => p.asset)).concat((man.groups || []).map(g => g.asset)))]
      const f0 = feed(['--build', '1.0.1', '--assets', st.assets])
      if (!await ready(f0.url)) { check(false, 'the test feed came up', 'no answer on /ready'); return }
      let pid = launch(solo, { KRINIK_LAUNCHER_FEED: f0.url, KUMM_DESKTOP_DIR: st.desk })
      check(!!await until(() => /новейшая 1\.0\.1 .*для этой игры 1\.0\.1/.test(logText()), 15000), 'D4b the plate saw build 1.0.1 with no build installed', logText().trim().split('\n').pop())
      const screen = await until(() => (logText().match(/экран: found-\S+/) || [null])[0], 15000)
      check(!!screen, 'D4b a manifest-only release is offered for a first install («Установить сборку»)', (logText().match(/экран: \S+/g) || []).join(' → '))
      // judge round 5, defect 1: the screen named «Нужно скачать: 0,1 МБ» for a manifest-only release and no question followed
      check(/Нужно скачать: лаунчер посчитает, когда сверит файлы/.test(screen ? logText().slice(logText().indexOf(screen)) : ''), 'D4b the screen does not name a size before the check', screen || '')
      if (flag('--leftover')) check(!/экран: (installed|update)\b/.test(logText()), 'U-X2 the launcher never shows the leftover as an installed build', (logText().match(/экран: \S+/g) || []).join(' → '))
      click(pid, 'Установить сборку')
      const box0 = dialog(pid, '6', 120)
      check(/Установить сборку 1\.0\.1\?/.test(box0) && /Нужно скачать 15,6 МБ \(файлов: 12\)/.test(box0), 'D4b after the check the box names the real size before downloading', box0)
      const done0 = await until(() => /сборка 1\.0\.1 поставлена/.test(logText()) || null, 180000, 500)
      check(!!done0, 'D4b the first install by the file list finishes', logText().trim().split('\n').slice(-2).join(' | '))
      check(/по списку файлов: первая установка/.test(logText()), flag('--leftover') ? 'U-X2 the update path took the leftover for no installed build (a first install)' : 'D4b the path is a first install',
        (logText().match(/по списку файлов: .*/) || ['no such line'])[0])
      if (flag('--leftover')) check(statSync(uninstaller).mtimeMs > Date.UTC(2001, 0, 1), 'U-X2 the uninstaller in the game is the new install\'s, not the leftover', new Date(statSync(uninstaller).mtimeMs).toISOString())
      const got0 = asked()
      check(got0.filter(n => n === 'manifest.json').length === 1 && allUnits.every(n => got0.includes(n)) && got0.length === allUnits.length + 1,
        'D4b a first install from zero downloads the list and every asset once', `${got0.length} requests for ${allUnits.length} assets`)
      check(/из прежних сборок 0/.test((logText().match(/список 1\.0\.1: .*/) || [''])[0]), 'D4b no file came from a previous bundle', (logText().match(/список 1\.0\.1: .*/) || ['no plan line'])[0])
      for (const e of [same, change, huge]) {
        const g = path.join(st.game, 'Mods', 'ModA', path.basename(e.path))
        check(existsSync(g) && sha(g) === e.sha256, `D4b the game's ${path.basename(e.path)} is the 1.0.1 file`, existsSync(g) ? sha(g).slice(0, 16) : 'missing')
      }
      check(aText() === 'mod A 1.0.1' && existsSync(b), 'D4b the game has build 1.0.1 (ModA 1.0.1, ModB)', aText())
      check(existsSync(journal) && existsSync(uninstaller), 'D4b the install wrote its journal and its uninstaller', `journal ${existsSync(journal)}, uninstaller ${existsSync(uninstaller)}`)
      check(stagings().length === 0, 'D4b no staging folder is left', stagings().join(', ') || 'none')
      const newPid0 = await until(() => pidOf(path.join(nb, 'KrinikConanLauncher.exe')), 15000)
      if (newPid0) killPid(newPid0)
      killPid(pid); killPid(f0.pid)
      await until(() => !alive(pid), 10000)
      if (flag('--leftover')) return
      // D4a: the reinstall over the bundle folder left in the game.
      uninstall()
      check(!existsSync(uninstaller) && !existsSync(a) && existsSync(nb), 'D4a build 1.0.1 is uninstalled, its bundle folder stays in the game', aText())
      writeFileSync(LOG(), ''); writeFileSync(feedLog, '')
      const f1 = feed(['--build', '1.0.1', '--assets', st.assets, '--parts', st.parts])
      if (!await ready(f1.url)) { check(false, 'the second test feed came up', 'no answer on /ready'); return }
      pid = launch(solo, { KRINIK_LAUNCHER_FEED: f1.url, KUMM_DESKTOP_DIR: st.desk })
      check(!!await until(() => /новейшая 1\.0\.1 .*для этой игры 1\.0\.1/.test(logText()), 15000), 'D4a the plate saw build 1.0.1', logText().trim().split('\n').pop())
      click(pid, 'Установить сборку')
      const done = await until(() => /сборка 1\.0\.1 поставлена/.test(logText()) || null, 180000, 500)
      check(!!done, 'D4a the reinstall finishes', logText().trim().split('\n').slice(-2).join(' | '))
      const got = asked()
      check(JSON.stringify(got) === JSON.stringify(['manifest.json']), 'D4a the reinstall downloads only the file list — every file from the bundle left in the game, no volume', got.join(', ') || 'none')
      check(aText() === 'mod A 1.0.1' && existsSync(b) && existsSync(journal), 'D4a the game has build 1.0.1 (ModA 1.0.1, ModB) and its journal', aText())
      const newPid = await until(() => pidOf(path.join(nb, 'KrinikConanLauncher.exe')), 15000)
      if (newPid) killPid(newPid)
      killPid(pid)
      return
    }

    // D6 (--bad-list): the release carries the volumes AND a manifest that does not parse — the update must go by the volumes (judge R9). Judge round 2: the
    // case rewrote the stand's manifest for good, and a later case on the same stand failed — the good list goes back on exit.
    if (flag('--bad-list')) { const good = readFileSync(mf); writeFileSync(mf, '{"format":1}'); process.on('exit', () => writeFileSync(mf, good)) }
    // D8 (--outside): the installed bundle moved out of the game folder — the player unpacked the archive elsewhere and installed from there (judge round 2, R6).
    let oldDir = st.bundleOld
    if (flag('--outside')) { oldDir = path.join(W, 'elsewhere', path.basename(st.bundleOld)); mkdirSync(path.dirname(oldDir), { recursive: true }); renameSync(st.bundleOld, oldDir) }
    const oldFile = n => path.join(oldDir, by(n).path)
    const sums = () => ['same.pak', 'change.pak', 'huge.pak', 'a.txt'].map(n => existsSync(oldFile(n)) ? sha(oldFile(n)) : 'missing')
    const oldSums = sums()
    const exe = path.join(oldDir, 'KrinikConanLauncher.exe')
    const unitsOf = e => e.asset ? [e.asset] : e.parts ? e.parts.map(p => p.asset) : [e.group]

    // D9 (--skip, a stand from stand.mjs --delta --skip; plan 57 criterion 7, the owner 2026-11-21 16:46): the player skipped 1.0.1 — the feed lists 1.0.1
    // and 1.0.2. One press updates 1.0.0 straight to 1.0.2: only the latest release's assets of the files that differ from 1.0.0, nothing of 1.0.1's release.
    if (flag('--skip')) {
      const f9 = feed(['--build', st.latest, '--assets', st.assets, '--older', `${st.older.version}:${st.older.assets}`])
      if (!await ready(f9.url)) { check(false, 'the test feed came up', 'no answer on /ready'); return }
      const pid9 = launch(exe, { KRINIK_LAUNCHER_FEED: f9.url, KUMM_DESKTOP_DIR: st.desk })
      check(!!await until(() => /новейшая 1\.0\.2 \(у нас 1\.0\.0\), для этой игры 1\.0\.2/.test(logText()), 15000), 'D9 the plate offers the latest 1.0.2 over 1.0.0',
        (logText().match(/лента: .*/) || [logText().trim().split('\n').pop()])[0])
      click(pid9, 'Обновить сборку')
      const ask9 = dialog(pid9, '6', 120)
      check(/Обновить сборку с 1\.0\.0 до 1\.0\.2/.test(ask9) && /Нужно скачать \d/.test(ask9), 'D9 one box updates 1.0.0 straight to 1.0.2', ask9)
      const done9 = await until(() => /сборка 1\.0\.2 поставлена/.test(logText()) || null, 180000, 500)
      check(!!done9, 'D9 the log says build 1.0.2 is installed', logText().trim().split('\n').slice(-2).join(' | '))
      const got = asked()
      check(!got.some(n => n.startsWith(`v${st.older.version}/`)), 'D9 nothing of the skipped release 1.0.1 was downloaded', got.join(', '))
      check(!unitsOf(same).some(n => got.includes(n)), 'D9 the pak unchanged since 1.0.0 was NOT downloaded', unitsOf(same).join(', '))
      check([change, huge].every(e => unitsOf(e).every(n => got.includes(n))), 'D9 the pak changed in 1.0.1 and the pak changed in 1.0.2 came from 1.0.2', [change, huge].map(e => unitsOf(e).join('+')).join(', '))
      check(got.length === new Set(got).size, 'D9 no asset was downloaded twice', `${got.length} requests`)
      for (const e of [same, change, huge]) {
        const g = path.join(st.game, 'Mods', 'ModA', path.basename(e.path))
        check(existsSync(g) && sha(g) === e.sha256, `D9 the game's ${path.basename(e.path)} is the 1.0.2 file`, existsSync(g) ? sha(g).slice(0, 16) : 'missing')
      }
      check(aText() === 'mod A 1.0.2' && existsSync(b), 'D9 the game has build 1.0.2 (ModA 1.0.2, ModB from 1.0.1)', aText())
      const newPid9 = await until(() => pidOf(path.join(nb, 'KrinikConanLauncher.exe')), 15000)
      if (newPid9) killPid(newPid9)
      killPid(pid9)
      return
    }

    // D5c (--digest-off, with the volumes; judge round 3, RISK 1): GitHub's digest of the changed pak differs from the manifest (the asset was re-uploaded after
    // the list) — no download can match, so the launcher goes to the volumes at once and never asks for that asset.
    if (flag('--digest-off')) {
      const f5 = feed(['--build', '1.0.1', '--assets', st.assets, '--parts', st.parts, '--digest-off', 'change.pak'])
      if (!await ready(f5.url)) { check(false, 'the test feed came up', 'no answer on /ready'); return }
      const pid5 = launch(exe, { KRINIK_LAUNCHER_FEED: f5.url, KUMM_DESKTOP_DIR: st.desk })
      check(!!await until(() => PLATE.test(logText()), 15000), 'D5c the plate saw build 1.0.1', logText().trim().split('\n').pop())
      click(pid5, 'Обновить сборку')
      // judge round 4, finding 2: every asset of the plan is compared before the question and before the first download — no «Нужно скачать» box comes
      check(!!await until(() => /путь по списку файлов негоден, обновление идёт частями архива: .*не совпадает со своей записью/.test(logText()), 60000),
        'D5c a digest that differs from the list falls back to the volumes', (logText().match(/путь по списку.*/) || ['no line'])[0])
      const box = dialog(pid5, '6', 60)
      check(/Лаунчер не смог обновить сборку по изменившимся файлам\. Скачать всю сборку 1\.0\.1/.test(box), 'D5c the archive question comes and says why first', box)
      const done5 = await until(() => /сборка 1\.0\.1 поставлена/.test(logText()) || null, 180000, 500)
      check(!!done5, 'D5c the build 1.0.1 is installed from the volumes', logText().trim().split('\n').slice(-2).join(' | '))
      check(!asked().includes(change.asset), 'D5c the asset whose digest differs was never downloaded', asked().filter(n => !/\.zip\.\d{3}$/.test(n)).join(', '))
      check(JSON.stringify(asked().filter(n => !/\.zip\.\d{3}$/.test(n))) === JSON.stringify(['manifest.json']), 'D5c no asset of the list was downloaded at all, only the list',
        asked().filter(n => !/\.zip\.\d{3}$/.test(n)).join(', '))
      check(stagings().length === 0, 'D5c no staging folder is left after the volumes', stagings().join(', ') || 'none')
      check(aText() === 'mod A 1.0.1', 'D5c ModA/a.txt is the 1.0.1 file', aText())
      const newPid5 = await until(() => pidOf(path.join(nb, 'KrinikConanLauncher.exe')), 15000)
      if (newPid5) killPid(newPid5)
      killPid(pid5)
      return
    }

    const withParts = flag('--bad-list') || flag('--volumes')
    const f = feed(['--build', '1.0.1', '--assets', st.assets, ...(withParts ? ['--parts', st.parts] : []), ...(flag('--stop') ? ['--slow', '4000'] : []),
      ...(flag('--corrupt') ? ['--corrupt', 'change.pak'] : [])])
    if (!await ready(f.url)) { check(false, 'the test feed came up', 'no answer on /ready'); return }
    const env = { KRINIK_LAUNCHER_FEED: f.url, KUMM_DESKTOP_DIR: st.desk, ...(flag('--nolinks') ? { KRINIK_LAUNCHER_NO_HARDLINKS: '1' } : {}),
      ...(flag('--outside') ? { KRINIK_LAUNCHER_SEARCH_ROOTS: W } : {}) }
    let pid = launch(exe, env)
    // D8: a launcher outside the game folder searches the drives first, and the feed line is logged before the game is chosen («для этой игры —», first
    // run 2026-11-21 12:23) — the case waits for the chosen game and the update screen instead.
    if (flag('--outside')) check(!!await until(() => /игра выбрана: .*\\game\r?\n[\s\S]*экран: update/.test(logText()), 40000), 'D8 the launcher outside the game folder found the game and offers the update',
      (logText().match(/игра выбрана: .*/) || ['no game chosen'])[0])
    else check(!!await until(() => PLATE.test(logText()), 15000), 'the plate saw build 1.0.1 for this game', logText().trim().split('\n').pop())
    click(pid, 'Обновить сборку')
    if (flag('--bad-list')) {
      check(!!await until(() => /путь по списку файлов негоден, обновление идёт частями архива/.test(logText()), 30000), 'a broken manifest falls back to the volumes', (logText().match(/путь по списку.*/) || ['no line'])[0])
      // judge round 2, defect 1: the fallback asks the archive question (with the archive's size) before the first part; round 3: it says why, first
      const box = dialog(pid, '6', 60)
      check(/Скачать всю сборку 1\.0\.1/.test(box), 'the fallback asks the archive question before downloading', box)
      check(/Лаунчер не смог обновить сборку по изменившимся файлам\. Скачать всю сборку/.test(box), 'the archive question says first why the whole archive is needed', '')
      const done = await until(() => /сборка 1\.0\.1 поставлена/.test(logText()) || null, 180000, 500)
      check(!!done, 'the build 1.0.1 is installed from the volumes', logText().trim().split('\n').slice(-2).join(' | '))
      check(aText() === 'mod A 1.0.1', 'ModA/a.txt is the 1.0.1 file', aText())
      // Judge round 3: a bad list runs Tidy before FALLBACK, which already removes the empty staging; this line holds the end state only — D5a is the
      // case whose staging held assembled files when the volumes took over.
      check(stagings().length === 0, 'no staging folder is left after the volumes', stagings().join(', ') || 'none')
      // waited like every other case: the new launcher starts a moment after the «поставлена» line, and a lookup at once missed it — it stayed running
      // after the case and held its exe (the cleanup of 2026-11-21 17:2x hit EPERM on r6\B)
      const newPid = await until(() => pidOf(path.join(nb, 'KrinikConanLauncher.exe')), 15000)
      if (newPid) killPid(newPid)
      killPid(pid)
      return
    }
    const ask = dialog(pid, flag('--decline') ? '7' : '6', 120)
    check(/Обновить сборку с 1\.0\.0 до 1\.0\.1/.test(ask) && /Нужно скачать \d/.test(ask), 'the box after the check names both versions and the download', ask)
    if (flag('--decline')) {
      check(!!await until(() => /отказался от обновления после сверки/.test(logText()), 20000), 'the log says the player declined after the check', logText().trim().split('\n').pop())
      await wait(1500)
      check(JSON.stringify(asked()) === JSON.stringify(['manifest.json']), 'only the manifest was downloaded', asked().join(', '))
      check(aText() === 'mod A 1.0.0', 'the old build stays in the game', aText())
      check(alive(pid), 'the launcher stays open', '')
      // judge R11: «alive» is true under an error box too — no other box may follow the «Нет», and the log carries no update error
      check(noDialog(pid, 5) === null, 'no other box follows the «Нет»', '')
      check(!/обновление сборки:/.test(logText()), 'the log carries no update error', '')
      // judge round 2: the downloaded list stayed in <bundle>.staging\.dl after «Нет»
      check(!existsSync(staging), 'nothing of the update is left after «Нет» (no staging folder)', existsSync(staging) ? readdirSync(staging, { recursive: true }).join(', ') : 'none')
      killPid(pid)
      return
    }
    if (flag('--corrupt')) {
      const tries = () => asked().filter(n => n === change.asset).length
      if (flag('--volumes')) {
        check(!!await until(() => /путь по списку файлов негоден, обновление идёт частями архива/.test(logText()), 60000),
          'D5a an asset failing its hash twice falls back to the volumes', (logText().match(/путь по списку.*/) || ['no line'])[0])
        const box = dialog(pid, '6', 60)
        check(/Лаунчер не смог обновить сборку по изменившимся файлам\. Скачать всю сборку 1\.0\.1/.test(box), 'D5a the archive question comes and says why first', box)
        const done = await until(() => /сборка 1\.0\.1 поставлена/.test(logText()) || null, 180000, 500)
        check(!!done, 'D5a the build 1.0.1 is installed from the volumes', logText().trim().split('\n').slice(-2).join(' | '))
        check(aText() === 'mod A 1.0.1', 'D5a ModA/a.txt is the 1.0.1 file', aText())
        check(tries() === 2, 'D5a the broken asset was tried twice', `${tries()} requests`)
        check(stagings().length === 0, 'D5a no staging folder is left after the volumes', stagings().join(', ') || 'none')
        // judge round 4, finding 5: the end state alone was already true by the cleanup after the unpack — the staging must go after «Да» and before the parts
        const L = logText(), gone = L.indexOf('убрана папка прежней попытки обновления'), firstPart = L.search(/хвост архива/)
        check(gone >= 0 && firstPart > gone, 'D5a the staging with the assembled files went after «Да», before the volumes', gone >= 0 ? L.slice(gone, gone + 120) : 'no such line')
        check(JSON.stringify(sums()) === JSON.stringify(oldSums), 'D5a the old bundle\'s files are untouched', sums().map(s => s.slice(0, 8)).join(' '))
        const newPid = await until(() => pidOf(path.join(nb, 'KrinikConanLauncher.exe')), 15000)
        if (newPid) killPid(newPid)
      } else {
        const box = dialog(pid, 'first', 60)
        check(/дважды скачался с ошибкой/.test(box), 'D5b with no volumes the box says the file failed twice', box)
        check(tries() === 2, 'D5b the broken asset was tried twice', `${tries()} requests`)
        check(aText() === 'mod A 1.0.0', 'D5b the game keeps build 1.0.0', aText())
        check(alive(pid), 'D5b the launcher stays open', '')
        check(JSON.stringify(sums()) === JSON.stringify(oldSums), 'D5b the old bundle\'s files are untouched', sums().map(s => s.slice(0, 8)).join(' '))
      }
      killPid(pid)
      return
    }
    // D3 (--stop, plan 57 phase 6 criterion 4): the launcher is killed by PID in the feed's pause inside the first asset — a half file stays in
    // <bundle>.staging\.dl and the old bundle is untouched; the second start names what is left, asks for the rest by Range and finishes.
    let half = null
    if (flag('--stop')) {
      half = await until(() => asked().find(n => n !== 'manifest.json'), 60000, 100)
      await wait(1500)
      killPid(pid)
      await until(() => !alive(pid), 10000)
      const part = half ? path.join(staging, '.dl', half) : ''
      const got = part && existsSync(part) ? statSync(part).size : -1
      check(got > 0 && got < unitSize(half), 'D3 the kill left a half asset in the staging folder', `${half}: ${got} of ${unitSize(half)} B`)
      check(JSON.stringify(sums()) === JSON.stringify(oldSums), 'D3 the old bundle is untouched after the kill', sums().map(s => s.slice(0, 8)).join(' '))
      check(aText() === 'mod A 1.0.0', 'D3 the game keeps build 1.0.0 after the kill', aText())
      writeFileSync(LOG(), '')
      pid = launch(exe, env)
      check(!!await until(() => PLATE.test(logText()), 15000), 'D3 the second start saw build 1.0.1', logText().trim().split('\n').pop())
      click(pid, 'Обновить сборку')
      const again = dialog(pid, '6', 120)
      check(mbOf(again) < mbOf(ask), 'D3 the second box names only what is left to download', `${mbOf(ask)} MB → ${mbOf(again)} MB`)
      const plan2 = (logText().match(/список 1\.0\.1: .*/) || ['no plan line'])[0]
      check(/уже собрано [1-9]/.test(plan2), 'D3 the second plan keeps what the first start assembled', plan2)
    }
    const done = await until(() => /сборка 1\.0\.1 поставлена/.test(logText()) || null, 180000, 500)
    check(!!done, 'the log says build 1.0.1 is installed', logText().trim().split('\n').slice(-3).join(' | '))
    const got = asked()
    const units = e => e.asset ? [e.asset] : e.parts ? e.parts.map(p => p.asset) : [e.group]
    check(!units(same).some(n => got.includes(n)), 'the unchanged pak was NOT downloaded', got.join(', '))
    check(!!change.asset && got.includes(change.asset), 'the changed 2 MB pak was downloaded as its one asset', units(change).join(', '))
    check(!!huge.parts && huge.parts.length === 2 && units(huge).every(n => got.includes(n)), 'the changed 5 MB pak was downloaded in its two parts', units(huge).join(', '))
    check(got.includes(man.groups[0].asset), 'the group of the small files was downloaded', man.groups[0].asset)
    if (half) {
      // D3: the half asset is asked twice — whole, then the rest by Range from where the kill left it; every other asset once.
      const ranged = readFileSync(feedLog, 'utf8').match(new RegExp(`GET /file/${encodeURIComponent(half).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')} .*range=bytes=[1-9]\\d*-`)) || null
      check(!!ranged, 'D3 the half asset was resumed by Range', ranged ? ranged[0].slice(0, 160) : 'no Range request')
      // The manifest is downloaded afresh on every start by design (judge round 1, Д2): once per start, two starts.
      const others = got.filter(n => n !== half && n !== 'manifest.json')
      check(others.length === new Set(others).size, 'D3 no other asset was downloaded twice', `${got.length} requests`)
      check(got.filter(n => n === 'manifest.json').length === 2, 'D3 the file list was downloaded once per start', `${got.filter(n => n === 'manifest.json').length} times`)
    } else check(got.length === new Set(got).size, 'no asset was downloaded twice', `${got.length} requests`)
    const plan = (logText().match(/список 1\.0\.1: .*/) || ['no plan line'])[0]
    check(/из прежних сборок [1-9]|уже собрано [1-9]/.test(plan), 'the plan took files from the old bundle', plan)
    for (const e of [same, change, huge]) {
      const g = path.join(st.game, 'Mods', 'ModA', path.basename(e.path))
      check(existsSync(g) && sha(g) === e.sha256, `the game's ${path.basename(e.path)} is the 1.0.1 file`, existsSync(g) ? sha(g).slice(0, 16) : 'missing')
    }
    check(aText() === 'mod A 1.0.1', 'ModA/a.txt is the 1.0.1 file', aText())
    check(existsSync(b), 'ModB (new in 1.0.1) is in the game', String(existsSync(b)))
    const ino = f2 => existsSync(f2) ? statSync(f2, { bigint: true }).ino : -1n
    const newSame = path.join(nb, same.path), oldSame = path.join(oldDir, same.path)
    if (flag('--nolinks')) {
      // D7: no hardlink is possible — the unchanged pak is a COPY (another file id, the same bytes), and the plan counted the copies.
      check(/копий [1-9]/.test(plan), 'D7 the plan counted copies of the old files', plan)
      check(ino(newSame) !== -1n && ino(newSame) !== ino(oldSame) && existsSync(newSame) && sha(newSame) === same.sha256, 'D7 the unchanged pak of the new bundle is a copy with the same bytes',
        `${ino(newSame)} vs ${ino(oldSame)}`)
    } else {
      // judge R11: the SAME file as the old bundle's (one file id), not merely «some second link»
      check(ino(newSame) !== -1n && ino(newSame) === ino(oldSame), 'the new bundle\'s unchanged pak IS the old bundle\'s file (one file id)', `${ino(newSame)} vs ${ino(oldSame)}`)
    }
    check(!existsSync(staging), 'the staging folder is gone (renamed into the bundle)', '')
    check(JSON.stringify(sums()) === JSON.stringify(oldSums), 'the old bundle\'s files are untouched', sums().map(s => s.slice(0, 8)).join(' '))
    const newPid = await until(() => pidOf(path.join(nb, 'KrinikConanLauncher.exe')), 15000)
    check(!!newPid, 'the new bundle\'s launcher runs', `pid ${newPid}`)
    if (newPid) {
      // Judge round 2: the offer named the folder's size (13.7 GB) while the deletion frees only the files no other bundle shares. The box must name the
      // bytes of the old bundle's files with one name, and say the shared files stay — or, with copies (D7), the whole size and no such line.
      const offer = dialog(newPid, '7', 30)
      const files = readdirSync(oldDir, { recursive: true }).map(n => path.join(oldDir, n)).filter(p => statSync(p).isFile())
      const freed = files.filter(p => statSync(p).nlink === 1).reduce((s, p) => s + statSync(p).size, 0) / 1048576
      const shown = (() => { const m = /освободится ([\d\s ,]+) (Б|КБ|МБ|ГБ)/.exec(offer); return m ? Number(m[1].replace(/[\s ]/g, '').replace(',', '.')) * { Б: 1 / 1048576, КБ: 1 / 1024, МБ: 1, ГБ: 1024 }[m[2]] : NaN })()
      check(Math.abs(shown - freed) <= Math.max(0.06, freed * 0.06), 'the delete offer names the bytes the deletion frees', `shown ${shown} MB, files with one name ${freed.toFixed(2)} MB`)
      const sharedLine = /ими пользуется новая сборка/.test(offer)
      check(flag('--nolinks') ? !sharedLine : sharedLine, flag('--nolinks') ? 'D7 the offer has no shared-files line (nothing is shared)' : 'the offer says the shared files stay in the new bundle', offer)
      killPid(newPid)
    }
    killPid(pid)
    return
  }

  // U-X (KUMM bugs/115, issue #46): the player closes the uninstaller's console by its X at its last «pause» — its self-delete (the line after the pause)
  // never runs. The screen must offer «Установить сборку» again, and the leftover uninstaller must go. a2 — another launcher exe (the control run).
  if (mode === 'uninstall') {
    const st = JSON.parse(readFileSync(path.resolve(a1), 'utf8'))
    const exe = a2 && !a2.startsWith('--') ? path.resolve(a2) : path.join(st.bundleOld, 'KrinikConanLauncher.exe')
    TMP = path.join(path.dirname(st.game), 'tmp'); mkdirSync(TMP, { recursive: true }); writeFileSync(LOG(), '')
    const cmd = path.join(st.game, 'uninstall_krinik_build.cmd'), backup = path.join(st.game, '_kumm_backup'), modA = path.join(st.game, 'Mods', 'ModA', 'a.txt')
    const last = () => logText().trim().split('\n').pop()
    const pid = launch(exe, { ...NOFEED, KUMM_DESKTOP_DIR: st.desk })
    check(!!await until(() => /экран: installed/.test(logText()), 20000), 'U-X the launcher shows the installed build', last())
    click(pid, 'Удалить сборку')
    const ask = dialog(pid, '6', 30)
    check(/Удалить сборку Krinik/.test(ask), 'U-X the uninstall box asks and «Да» is pressed', ask)
    check(!!await until(() => !existsSync(backup) && !existsSync(modA), 60000, 500), 'U-X the uninstaller restored the game (no _kumm_backup, no ModA)', `backup ${existsSync(backup)}, ModA ${existsSync(modA)}`)
    const name = path.basename(cmd).replace(/'/g, "''")
    const consoles = await until(() => {
      const o = execFileSync('powershell', ['-NoProfile', '-Command', `Get-CimInstance Win32_Process -Filter "Name='cmd.exe'" | Where-Object { $_.CommandLine -like '*${name}*' } | ForEach-Object { $_.ProcessId }`], { encoding: 'utf8' }).trim()
      return o ? o.split(/\s+/).map(Number) : null
    }, 10000, 500)
    await wait(3000)   // the shortcut line and «Готово» run before the last pause
    check(!!consoles && existsSync(cmd), 'U-X the console waits at its last pause and the uninstaller file is still there', `console ${consoles}, cmd ${existsSync(cmd)}`)
    for (const c of consoles || []) killPid(c)   // the player's X on the console
    check(!!await until(() => /окно удаления сборки закрыто/.test(logText()), 15000), 'U-X the launcher saw the uninstall window close', last())
    await wait(3000)
    const screens = logText().match(/экран: \S+/g) || []
    const now = screens.length ? screens[screens.length - 1].slice('экран: '.length) : 'none'
    check(now === 'found-files', 'U-X after the X the screen offers «Установить сборку» (found-files), not «installed»', `screens ${screens.join(' → ')}`)
    check(!existsSync(cmd), 'U-X the leftover uninstaller is gone from the game root', existsSync(cmd) ? 'still there' : (logText().match(/оставшийся деинсталлятор.*/) || ['gone'])[0])
    killPid(pid)
    return
  }

  if (mode === 'build') {
    const st = JSON.parse(readFileSync(path.resolve(a1), 'utf8'))
    const exe = path.join(st.bundleOld, 'KrinikConanLauncher.exe')
    TMP = path.join(path.dirname(st.game), 'tmp'); mkdirSync(TMP, { recursive: true }); writeFileSync(LOG(), '')
    // --drop-last (case B5′, epic 55 B5): the release lacks its last part — the launcher must refuse before downloading anything.
    if (flag('--drop-last')) {
      const parts = readdirSync(st.parts).filter(n => /\.zip\.\d{3}$/.test(n)).sort()
      renameSync(path.join(st.parts, parts[parts.length - 1]), path.join(path.dirname(st.parts), parts[parts.length - 1] + '.held'))
    }
    // --stop: the feed pauses mid-file (feed.mjs --slow), so the stop leaves a half part for the Range resume
    const f = feed(['--build', '1.0.1', '--parts', st.parts, ...(flag('--stop') || flag('--close') || flag('--game-starts') ? ['--slow', '400'] : [])])
    if (!await ready(f.url)) { check(false, 'the test feed came up', 'no answer on /ready'); return }
    const env = { KRINIK_LAUNCHER_FEED: f.url, KUMM_DESKTOP_DIR: st.desk }
    // --half-bundle (case B15′, judge B7 round 2 R2/R3): the bundle folder of 1.0.1 holds install.ps1 and pack\modpack.json of 1.0.1 but no unpack marker —
    // what a manual 7-Zip extraction leaves after its first seconds (both files come before the mods in the archive). It must NOT be offered as ready.
    const halfDir = path.join(st.game, st.stem)
    if (flag('--half-bundle')) {
      mkdirSync(path.join(halfDir, 'pack'), { recursive: true })
      writeFileSync(path.join(halfDir, 'install.ps1'), '# half\n')
      writeFileSync(path.join(halfDir, 'pack', 'modpack.json'), JSON.stringify({ packVersion: '1.0.1', mods: [] }))
    }
    // judge B7 round 2 C5: the fake game is compiled BEFORE the update starts — compiling it mid-download let a fast stand pass the second game check.
    const fake = flag('--game-starts') ? stub(path.join(path.dirname(st.game), 'fakegame', 'ConanSandbox.exe'), 'hang') : null
    const pid = launch(exe, env)
    // Since KUMM plans/57 the feed line reads «лента: сборок N, новейшая 1.0.1 (у нас 1.0.0), для этой игры 1.0.1, …»: the release must match the game's CL too.
    check(!!await until(() => /новейшая 1\.0\.1 \(у нас 1\.0\.0\), для этой игры 1\.0\.1/.test(logText()), 15000), 'the plate saw build 1.0.1 for this game over the bundle 1.0.0', logText().trim().split('\n').pop())
    click(pid, 'Обновить сборку')
    if (flag('--half-bundle')) {
      const half = dialog(pid, '7')
      check(/Скачать сборку 1\.0\.1/.test(half) && !/уже скачана и распакована/.test(half), 'a half-unpacked folder without the marker is not offered as ready', half)
      killPid(pid)
      return
    }
    const ask = dialog(pid, '6')
    check(/Скачать сборку 1\.0\.1/.test(ask), 'the confirm box names the version and the size', ask)
    check(/после распаковки его части удалятся/.test(ask), 'the confirm box says the parts go after the unpack', '')
    if (flag('--drop-last')) {
      const box = dialog(pid, 'first')
      check(/не хватает частей/.test(box), 'a release without its last part is refused', box)
      check(!existsSync(path.join(st.game, `${st.stem}_parts`)), 'nothing was downloaded (no parts folder)', '')
      check(alive(pid), 'the old launcher stays open', '')
      killPid(pid)
      return
    }
    // --broken (case B4): the new build's deploy fails its check — the launcher must say so, keep the parts and stay open.
    if (flag('--broken')) {
      const box = dialog(pid, 'first')
      check(/встала не полностью \(код 1\)/.test(box), 'a partial install is not reported as success', box)
      check(alive(pid), 'the old launcher stays open', '')
      // since epic 55 B5 the parts go right after a good unpack; a failed install is retried from the unpacked bundle (its install.cmd)
      check(!existsSync(path.join(st.game, `${st.stem}_parts`)) && existsSync(path.join(st.game, st.stem, 'install.cmd')), 'the parts are gone after the unpack; the unpacked bundle stays for a retry', '')
      check(!/поставлена из/.test(logText()), 'the log does not claim the build installed', logText().trim().split('\n').slice(-2).join(' | '))
      // epic 55 B7 п. 2: the retry does not download 13 GB again — the unpacked bundle of this version is installed as it is.
      click(pid, 'Обновить сборку')
      const retry = dialog(pid, '7')
      check(/уже скачана и распакована/.test(retry), 'the retry offers the unpacked bundle', retry)
      killPid(pid)
      return
    }
    // --game-starts (case B7′, epic 55 B7 п. 2): the player starts the game while the parts download — the update refuses AFTER the unpack and keeps the
    // parts (nothing it says is a lie); with the game closed the next press installs from the unpacked bundle without a single new download.
    if (flag('--game-starts')) {
      const partsDir = path.join(st.game, `${st.stem}_parts`)
      await until(() => existsSync(partsDir) && readdirSync(partsDir).length > 1, 60000, 50)
      const game = spawn(fake, [], { stdio: 'ignore' })
      children.push(game.pid)
      const box = dialog(pid, 'first', 120)
      check(/Игра запущена/.test(box) && /уже скачана и распакована/.test(box), 'the running game is refused after the unpack', box)
      const kept = existsSync(partsDir) ? readdirSync(partsDir).length : 0
      check(kept === st.volumes, 'every part is kept after the refusal', `${kept} of ${st.volumes}`)
      // judge B7 round 2 R3: the manifest exists after any unpack; the marker exists only after a WHOLE one (Unpack writes it last).
      check(existsSync(path.join(st.game, st.stem, 'pack', '.krinik_unpacked')), 'the bundle is unpacked whole (its marker written last)', '')
      killPid(game.pid)
      await until(() => !alive(game.pid), 10000)
      const asked = (readFileSync(f.log, 'utf8').match(/GET \/file\//g) || []).length
      click(pid, 'Обновить сборку')
      const again = dialog(pid, '6')
      check(/уже скачана и распакована/.test(again), 'the second press offers the unpacked bundle', again)
      check(!!await until(() => /уже распакован .* скачивание и распаковка пропущены/.test(logText()), 20000), 'the log says download and unpack were skipped', '')
      f.askedBefore = asked
    }
    // --close (case B5): the player closes the window mid-download — the window must refuse and the update must go on.
    if (flag('--close')) {
      const partsDir = path.join(st.game, `${st.stem}_parts`)
      await until(() => existsSync(partsDir) && readdirSync(partsDir).length > 1, 60000, 50)
      execFileSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(HERE, 'click.ps1'), '-ProcessId', String(pid), '-Close'], { encoding: 'utf8' })
      const box = dialog(pid, 'first')
      check(/Идёт обновление/.test(box), 'closing mid-update is refused with a box', box)
      check(alive(pid), 'the window is still open after the close', '')
    }
    if (flag('--stop')) {
      // Stop as soon as the first part is on disk, then press again: the second run must ask the feed for the rest (Range).
      const partsDir = path.join(st.game, `${st.stem}_parts`)
      await until(() => existsSync(partsDir) && readdirSync(partsDir).length > 1, 60000, 50)
      click(pid, 'Остановить')
      const stopped = dialog(pid, 'first')
      check(/остановлено/.test(stopped), 'the stop leaves the downloaded parts', stopped)
      click(pid, 'Обновить сборку')
      const again = dialog(pid, '6')
      check(/Уже скачано/.test(again), 'the second confirm says what is already downloaded', again)
    }
    const newExe = path.join(st.game, st.stem, 'KrinikConanLauncher.exe')
    const done = await until(() => /сборка 1\.0\.1 поставлена/.test(logText()) || null, flag('--big') ? 900000 : 180000, 500)
    check(!!done, 'the log says build 1.0.1 is installed', logText().trim().split('\n').slice(-3).join(' | '))
    // judge 2026-11-17: the last-part check must have READ the tail (a server without Range would leave it unchecked — logged, not refused)
    check(/хвост архива проверен/.test(logText()), 'the archive tail was checked before the download', (logText().match(/хвост архива.*/g) || ['no line']).pop())
    if (f.askedBefore !== undefined) {
      const after = (readFileSync(f.log, 'utf8').match(/GET \/file\//g) || []).length
      check(after === f.askedBefore, 'no part was downloaded again after the game closed', `${f.askedBefore} → ${after} file requests`)
    }
    const a = path.join(st.game, 'Mods', 'ModA', 'a.txt'), b = path.join(st.game, 'Mods', 'ModB', 'b.txt')
    check(existsSync(a) && readFileSync(a, 'utf8').trim() === 'mod A 1.0.1', 'ModA is the 1.0.1 file', existsSync(a) ? readFileSync(a, 'utf8').trim() : 'missing')
    check(existsSync(b), 'ModB (new in 1.0.1) is in the game', String(existsSync(b)))
    check(existsSync(path.join(st.game, 'uninstall_krinik_build.cmd')), 'the new uninstaller is in the game root', '')
    check(!existsSync(path.join(st.game, `${st.stem}_parts`)), 'the parts folder is gone', '')
    check(existsSync(path.join(st.desk, 'Krinik fixture.lnk')), 'the stand desktop has the shortcut again', readdirSync(st.desk).join(', '))
    if (flag('--big')) {
      for (const n of ['c1.bin', 'c2.bin', 'c3.bin']) {
        const g = path.join(st.game, 'Mods', 'ModC', n)
        check(existsSync(g) && statSync(g).size === 1600 * 1024 * 1024, `ModC/${n} — 1.6 GB`, existsSync(g) ? String(statSync(g).size) : 'missing')
      }
      const tail = path.join(st.game, 'Mods', 'ModC', 'z_tail.txt')
      check(existsSync(tail) && readFileSync(tail, 'utf8') === st.tail, 'the entry past the 4 GB mark reads byte for byte', existsSync(tail) ? JSON.stringify(readFileSync(tail, 'utf8')) : 'missing')
    }
    const newPid = await until(() => pidOf(newExe), 15000)
    check(!!newPid, 'the new bundle\'s launcher runs', `pid ${newPid}`)
    check(!!await until(() => !alive(pid), 10000), 'the old launcher closed', '')
    // epic 55 B5: the new launcher offers to delete the previous bundle folder (the spent shipment); «Да» — the folder goes, the game stays.
    if (newPid && !flag('--big')) {
      const offer = dialog(newPid, '6')
      check(/Папка прежней сборки больше не нужна/.test(offer), 'the new launcher offers to delete the previous bundle folder', offer)
      check(/defbutton=7/.test(offer), 'the delete offer defaults to «Нет»', (offer.match(/defbutton=\d+/) || ['none'])[0])
      check(!!await until(() => !existsSync(st.bundleOld), 20000), 'the previous bundle folder is deleted', String(existsSync(st.bundleOld)))
      check(existsSync(path.join(st.game, 'ConanSandbox.exe')) && existsSync(newExe), 'the game and the new bundle stay', '')
    }
    if (newPid) killPid(newPid)
    // The FILE request must carry Range — the /download/ one before the 302 always does; only /file/ proves the resume survived the redirect (judge 2).
    const range = readFileSync(f.log, 'utf8').match(/GET \/file\/\S+ .*range=bytes=\d+-/g) || []
    if (flag('--stop')) check(range.length > 0, 'a resumed part was asked by Range', range.join(' '))
    return
  }
  console.log('usage: see the header'); process.exit(2)
}
function alive(pid) {
  try { return execFileSync('tasklist', ['/FI', `PID eq ${pid}`, '/NH'], { encoding: 'utf8' }).includes(` ${pid} `) } catch { return false }
}

// The owner's real launcher state folder: no stand case may create or change it (checked after every case; the stand's own state lives in TMP).
const OWNER_STATE = path.join(process.env.LOCALAPPDATA || '', 'KrinikConanLauncher')
const ownerState = () => existsSync(OWNER_STATE) ? readdirSync(OWNER_STATE).sort().join(',') : 'absent'
const ownerBefore = ownerState()
main().then(() => {
  check(ownerState() === ownerBefore, "the owner's %LOCALAPPDATA%\\KrinikConanLauncher is untouched", `${ownerBefore} -> ${ownerState()}`)
  console.log(failed ? `${failed} FAILED` : 'ALL PASS'); process.exit(failed ? 1 : 0)
})
