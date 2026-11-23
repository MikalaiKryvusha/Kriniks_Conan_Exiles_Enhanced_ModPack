// upload_progress.mjs -- a local page that shows how far a GitHub release upload has got: the share of the release's files and bytes already on the
// release page, the speed over the last minute, time left and elapsed, draft or published. The owner 2026-11-23 00:21 asked for an HTML tool to watch
// the uploads of our releases (KUMM chronicle; HOUSE_RULES_REFERENCE §6). Zero dependencies, Node >= 22, listens on 127.0.0.1 only.
//
//   node _config/release/upload_progress.mjs --tag v0.9.1-RC4 --dir D:/work/ai_sandbox/KUMM/.work/rc4_release/release [--repo <owner/name>] [--port 8765]
//
// Where the numbers come from (KUMM researches/efficient-code/EFFICIENT_CODE.md §1):
//   1. Trigger: the page asks /status every 5 s; one computation is shared by every request that arrives while it runs or within 4 s after it.
//   2. Inputs: the release (found once in the releases list by tag_name -- a draft has no tag endpoint -- then polled by its id), the gh.exe processes
//      whose command line uploads this tag, the local files (sizes and SHA256SUMS.txt read once at start: a release dir does not change after the build).
//   3. N per event: one GitHub call and one process query, whatever the number of files.
//   4. Bytes in flight: what each uploader process has read, minus the files of ITS command line already on GitHub and created during its life
//      (gh reads a file while it sends it; gh 2.95 retries an asset up to 3 times on a network or 5xx error and reads it again on every attempt, so
//      «Загружено» runs ahead by the re-read bytes, capped at the total, until that process exits; at the cap the page says «GitHub принимает
//      последние файлы» while gh may still be re-sending one). Two uploaders of one tag are shown as a warning:
//      they race on the same assets (EXP-0616).
//   5. Budget: at most 720 GitHub calls an hour while the page is open (the limit for a signed-in user is 5000); the page stops asking when the release is
//      published, complete and no upload runs.
//   6. Measurement: each /status carries `tookMs`; one slower than 2 s is logged to the console.
// The page asks every 5 s while an upload runs and every 30 s while none does (a draft waiting for the publication word).
// [TESTED: 2026-11-23 · cases T1–T6 on real releases and a real 150 MiB draft upload — KUMM testcases/reports/2026-11-23_conan-release-upload-progress-page.md]
import http from 'node:http'
import { execFile } from 'node:child_process'
import { readdirSync, statSync, readFileSync, existsSync } from 'node:fs'
import path from 'node:path'

const arg = (k, d) => { const i = process.argv.indexOf('--' + k); return i > 0 ? process.argv[i + 1] : d }
const REPO = arg('repo', 'MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack')
const TAG = arg('tag'), DIR = arg('dir'), PORT = Number(arg('port', '8765'))
if (!TAG || !DIR || !existsSync(DIR)) { console.error('usage: node upload_progress.mjs --tag <tag> --dir <existing release dir> [--repo <owner/name>] [--port 8765]'); process.exit(2) }

const CACHE_MS = 4000          // a finished /status serves every request for 4 s: the page asks every 5 s
const SPEED_WINDOW_MS = 60000  // speed over the last minute: one 5 s sample jumps with the packet sizes
const SLOW_STATUS_MS = 2000    // a slower /status is logged
const START_SLACK_MS = 60000   // an asset created up to 1 min before a process's start still counts as its own (clock skew is seconds)
const CALL_TIMEOUT_MS = 20000  // a hung gh or WMI call fails after 20 s instead of holding every /status

// The local files, once: name -> size, and the expected SHA-256 from SHA256SUMS.txt when the dir has one (a stale asset with the same name and size --
// the old volumes of EXP 2026-11-18 -- shows as «другой файл»).
const local = readdirSync(DIR).filter(n => statSync(path.join(DIR, n)).isFile()).sort().map(n => ({ name: n, size: statSync(path.join(DIR, n)).size }))
const TOTAL = local.reduce((s, f) => s + f.size, 0)
const SUMS = new Map()
if (existsSync(path.join(DIR, 'SHA256SUMS.txt')))
  for (const line of readFileSync(path.join(DIR, 'SHA256SUMS.txt'), 'utf8').split(/\r?\n/)) {
    const m = line.match(/^([0-9a-f]{64})\s+\*?(.+)$/i); if (m) SUMS.set(path.basename(m[2].trim()), m[1].toLowerCase())
  }

const run = (cmd, args) => new Promise(res => execFile(cmd, args, { maxBuffer: 16 << 20, windowsHide: true, timeout: CALL_TIMEOUT_MS },
  (err, out, errOut) => res({ ok: !err, out: String(out), err: String(errOut || (err && err.message) || '') })))
const parse = s => { try { return JSON.parse(s) } catch { return undefined } }

// The release: found once in the list by tag_name, then polled by id. The last good answer is kept and marked stale when GitHub fails.
let relId = null, lastRel = null
async function release() {
  const r = await run('gh', ['api', relId ? `repos/${REPO}/releases/${relId}` : `repos/${REPO}/releases?per_page=20`])
  // The polled release was deleted (or deleted and created anew): forget it and look it up by tag again.
  if (relId && !r.ok && /HTTP 404/.test(r.err)) { relId = null; lastRel = null; return release() }
  const j = r.ok ? parse(r.out) : undefined
  const rel = j === undefined ? undefined : relId ? j : (Array.isArray(j) ? j.find(x => x.tag_name === TAG) : undefined)
  if (j === undefined) return lastRel ? { ...lastRel, stale: 'GitHub не ответил: ' + (r.err.trim() || 'ответ не JSON').slice(0, 160) } : { error: (r.err.trim() || 'ответ не JSON').slice(0, 200) }
  if (!rel) { relId = null; return { missing: true } }
  relId = rel.id
  lastRel = { draft: rel.draft, url: rel.html_url, assets: rel.assets.map(a => ({ name: a.name, size: a.size, state: a.state, created: Date.parse(a.created_at), digest: (a.digest || '').replace(/^sha256:/, '') })) }
  return lastRel
}

// The uploader processes of this tag: `gh release create|upload … <tag> …` (flags may stand before the tag); the files each one sends are read off its
// command line by name — a mask (`release/*`, expanded by gh itself when no shell did) or no name at all means the whole dir. A failed query returns
// null: the caller keeps the last list and says so.
let lastProcs = []
async function uploaders() {
  const tag = TAG.replace(/'/g, "''")
  const ps = `Get-CimInstance Win32_Process -Filter "Name='gh.exe'" | Where-Object { $_.CommandLine -match 'release (create|upload) ' -and $_.CommandLine -match ('(^| )' + [regex]::Escape('${tag}') + '( |$)') } | ` +
    `ForEach-Object { [pscustomobject]@{ pid = $_.ProcessId; start = $_.CreationDate.ToUniversalTime().ToString('o'); read = $_.ReadTransferCount; cmd = $_.CommandLine } } | ConvertTo-Json -Compress`
  const r = await run('powershell', ['-NoProfile', '-NonInteractive', '-Command', ps])
  if (!r.ok) return null
  const j = r.out.trim() ? parse(r.out) : []
  if (j === undefined) return null
  const all = new Set(local.map(f => f.name))
  return (Array.isArray(j) ? j : [j]).map(p => {
    const toks = p.cmd.split(/[\s"]+/).filter(Boolean).map(t => t.split(/[\\/]/).pop())  // the file names of the arguments, by basename
    const named = local.filter(f => toks.includes(f.name)).map(f => f.name)
    return { pid: p.pid, start: Date.parse(p.start), read: Number(p.read), files: named.length && !toks.some(t => /[*?]/.test(t) && !t.startsWith('-')) ? new Set(named) : all }
  })
}

const samples = []      // [{ at, done }] over the last minute, for the speed
let cache = null, pending = null, firstStart = null, lastSeen = null, wasRunning = false

async function compute() {
  const t0 = Date.now()
  const [rel, found] = await Promise.all([release(), uploaders()])
  const procs = found ?? lastProcs
  if (found) lastProcs = found
  const up = new Map((rel.assets || []).filter(a => a.state === 'uploaded').map(a => [a.name, a]))
  const wrong = new Set(local.filter(f => { const a = up.get(f.name); return a && a.digest && SUMS.has(f.name) && a.digest !== SUMS.get(f.name) }).map(f => f.name))
  const isUp = f => up.has(f.name) && !wrong.has(f.name)
  const uploadedBytes = local.reduce((s, f) => s + (isUp(f) ? f.size : 0), 0)
  let inflight = 0
  for (const p of procs) {
    const doneByProc = local.filter(f => p.files.has(f.name) && up.has(f.name) && up.get(f.name).created >= p.start - START_SLACK_MS).reduce((s, f) => s + f.size, 0)
    inflight += Math.max(0, p.read - doneByProc)
  }
  inflight = Math.min(inflight, TOTAL - uploadedBytes)
  const done = uploadedBytes + inflight
  if (procs.length && !wasRunning) samples.length = 0  // a new upload: the idle minute does not dilute its speed
  wasRunning = procs.length > 0
  samples.push({ at: t0, done })
  while (samples.length > 1 && t0 - samples[0].at > SPEED_WINDOW_MS) samples.shift()
  const first = samples[0]
  const speed = procs.length && t0 > first.at ? Math.max(0, (done - first.done) / ((t0 - first.at) / 1000)) : 0  // no uploader, no speed
  if (procs.length) { firstStart = Math.min(firstStart ?? Infinity, ...procs.map(p => p.start)); lastSeen = t0 }
  const filesUp = local.filter(isUp).length
  const body = {
    tag: TAG, repo: REPO, url: rel.url || null, error: rel.error || null, stale: rel.stale || null, missing: !!rel.missing, draft: rel.draft ?? null,
    procStale: found ? null : 'Список процессов не прочитан, показан прежний.',
    files: local.length, filesUp, wrong: wrong.size, total: TOTAL, done, speed,
    left: speed > 0 ? Math.round((TOTAL - done) / speed) : null, elapsed: firstStart ? Math.round((lastSeen - firstStart) / 1000) : null,
    running: procs.map(p => p.pid), finishing: procs.length > 0 && filesUp < local.length && TOTAL - done < 1 ? local.length - filesUp : 0,
    rows: local.map(f => ({ name: f.name, size: f.size, state: wrong.has(f.name) ? 'wrong' : isUp(f) ? 'up' : 'wait' })),
    at: new Date(t0).toISOString(), tookMs: Date.now() - t0
  }
  if (body.tookMs > SLOW_STATUS_MS) console.log(`slow /status: ${body.tookMs} ms`)
  cache = { at: Date.now(), body }
  return body
}
// One computation at a time; requests during it wait for the same promise.
function status() {
  if (cache && Date.now() - cache.at < CACHE_MS) return Promise.resolve(cache.body)
  return pending ??= compute().finally(() => { pending = null })
}

// The page: large type in rem (the owner's 4K screen at 300 %), a refresh every 5 s, each file's state in a word and a colour.
const PAGE = `<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Загрузка выпуска</title><style>
:root{--bg:#17130f;--panel:#231c16;--text:#efe4d2;--dim:#b5a68f;--gold:#d9a441;--ok:#7fb069;--wait:#8a7d6a;--bad:#d9634c}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:1.1rem/1.5 "Segoe UI",system-ui,sans-serif;padding:2rem 1rem}
main{max-width:60rem;margin:0 auto}h1{font-size:1.8rem;margin:0 0 .3rem}.sub{color:var(--dim);margin:0 0 1.5rem}
.panel{background:var(--panel);border-radius:.6rem;padding:1.4rem 1.6rem;margin-bottom:1.2rem}
.bar{height:1.6rem;background:#0f0c09;border-radius:.8rem;overflow:hidden}.fill{height:100%;background:var(--gold);width:0;transition:width .6s}
.pct{font-size:2.6rem;font-weight:600;margin:.6rem 0 .2rem}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(11rem,1fr));gap:.8rem;margin-top:1rem}
.k{color:var(--dim);font-size:.95rem}.v{font-size:1.3rem;font-weight:600}.state{font-size:1.2rem;font-weight:600}.note{margin-top:.6rem;color:var(--bad)}
table{width:100%;border-collapse:collapse;font-size:1rem}td{padding:.35rem .5rem;border-top:1px solid #33291f}td.s{text-align:right;white-space:nowrap;color:var(--dim)}
td.n{word-break:break-all}.up{color:var(--ok)}.wait{color:var(--wait)}.err,td.wrong{color:var(--bad)}a{color:var(--gold)}
</style></head><body><main>
<h1>Загрузка выпуска <span id="tag"></span></h1><p class="sub" id="sub">Страница обновляется каждые 5 секунд.</p>
<div class="panel"><div class="state" id="state">Чтение состояния выпуска…</div><div class="note" id="note"></div><div class="pct" id="pct">—</div>
<div class="bar"><div class="fill" id="fill"></div></div><div class="grid">
<div><div class="k">Загружено</div><div class="v" id="done">—</div></div><div><div class="k">Файлов на GitHub</div><div class="v" id="files">—</div></div>
<div><div class="k">Скорость</div><div class="v" id="speed">—</div></div><div><div class="k">Осталось времени</div><div class="v" id="left">—</div></div>
<div><div class="k">Прошло времени</div><div class="v" id="elapsed">—</div></div></div></div>
<div class="panel"><table id="rows"></table></div></main><script>
const num = (x, d) => x.toLocaleString('ru-RU', { minimumFractionDigits: d, maximumFractionDigits: d })
const size = b => b >= 1e9 ? num(b / 1e9, 1) + ' ГБ' : b >= 1e6 ? num(b / 1e6, 1) + ' МБ' : num(b / 1e3, 0) + ' КБ'
const dur = s => s == null ? '—' : s < 60 ? s + ' с' : s < 3600 ? Math.floor(s / 60) + ' мин ' + (s % 60) + ' с' : Math.floor(s / 3600) + ' ч ' + Math.floor(s % 3600 / 60) + ' мин'
const esc = t => t.replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c])
const WORD = { up: 'на GitHub', wait: 'ещё не загружен', wrong: 'на GitHub другой файл' }
const $ = id => document.getElementById(id)
let shown = ''
const FAST_MS = 5000, IDLE_MS = 30000 // every 5 s while an upload runs, every 30 s while none does
const plural = (n, one, few, many) => { const t = n % 100, u = n % 10; return t > 10 && t < 20 ? many : u === 1 ? one : u > 1 && u < 5 ? few : many }
function state(text, cls) { $('state').textContent = text; $('state').className = 'state ' + cls }
async function tick() {
  let s
  try { const r = await fetch('/status'); s = await r.json(); if (!r.ok || !s.rows) throw new Error(s.error || ('HTTP ' + r.status)) }
  catch (e) { state('Сервер страницы не отвечает.', 'err'); setTimeout(tick, FAST_MS); return }
  $('tag').textContent = s.tag
  const pct = s.total ? Math.min(100, s.done / s.total * 100) : 0
  $('fill').style.width = pct.toFixed(1) + '%'
  $('pct').textContent = num(pct, 1) + ' %'
  $('done').textContent = size(s.done) + ' из ' + size(s.total)
  $('files').textContent = s.filesUp + ' из ' + s.files
  $('speed').textContent = s.speed > 0 ? size(s.speed) + '/с' : '—'
  $('left').textContent = s.filesUp === s.files ? '0 с' : s.finishing === 1 ? 'GitHub принимает последний файл' : s.finishing ? 'GitHub принимает последние файлы' : dur(s.left)
  $('elapsed').textContent = dur(s.elapsed)
  const run = s.running.length, all = s.filesUp === s.files, done = !s.draft && !run && all && !s.error && !s.missing
  if (s.error) state('GitHub не ответил, выпуск прочитать не удалось.', 'err')
  else if (s.missing) state('Выпуска ' + s.tag + ' на GitHub нет.', 'wait')
  else if (s.draft) state(run ? 'Идёт загрузка. Пока выпуск остаётся черновиком, игроки его не видят.' : all ? 'Все файлы на GitHub. Черновик ждёт публикации.' : 'Загрузка не идёт, а часть файлов ещё не на GitHub.', run || all ? '' : 'err')
  else { $('state').innerHTML = (run ? 'Выпуск опубликован, загрузка ещё идёт. ' : 'Выпуск опубликован. ') + '<a href="' + esc(s.url) + '">Открыть страницу выпуска</a>'; $('state').className = 'state up' }
  $('note').textContent = [s.stale ? 'GitHub не ответил, показано прежнее состояние выпуска.' : '', s.procStale,
    run > 1 ? 'Этот выпуск грузят сразу ' + run + ' ' + plural(run, 'процесс', 'процесса', 'процессов') + ' gh, они мешают друг другу.' : '',
    s.wrong ? 'Файлов, которые на GitHub отличаются от местных: ' + s.wrong + '.' : ''].filter(Boolean).join(' ')
  $('sub').textContent = 'Обновлено в ' + new Date(s.at).toLocaleTimeString('ru-RU') + '. ' + (done ? 'Загрузка закончена, страница больше не обновляется.' : run ? 'Страница обновляется каждые 5 секунд.' : 'Пока загрузка не идёт, страница обновляется раз в 30 секунд.')
  const key = s.rows.map(r => r.state).join()
  if (key !== shown) { // the table is rebuilt only when a file's state changed
    shown = key
    const order = { wrong: 0, wait: 1, up: 2 }
    $('rows').innerHTML = s.rows.slice().sort((a, b) => order[a.state] - order[b.state] || b.size - a.size).map(r =>
      '<tr><td class="n">' + esc(r.name) + '</td><td class="s">' + size(r.size) + '</td><td class="s ' + r.state + '">' + WORD[r.state] + '</td></tr>').join('')
  }
  if (!done) setTimeout(tick, run ? FAST_MS : IDLE_MS)
}
tick()
</script></body></html>`

const server = http.createServer(async (req, res) => {
  if (req.url === '/status') {
    try { const b = await status(); res.writeHead(200, { 'content-type': 'application/json; charset=utf-8' }); res.end(JSON.stringify(b)) }
    catch (e) { res.writeHead(500, { 'content-type': 'application/json; charset=utf-8' }); res.end(JSON.stringify({ error: String(e.message || e) })) }
    return
  }
  if (req.url !== '/') { res.writeHead(404); res.end(); return }
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }); res.end(PAGE)
})
server.on('error', e => { console.error(e.code === 'EADDRINUSE' ? `port ${PORT} is busy: pass --port <another>` : String(e)); process.exit(1) })
server.listen(PORT, '127.0.0.1', () => console.log(`upload progress of ${TAG}: http://127.0.0.1:${PORT}/ (${local.length} files, ${(TOTAL / 1e9).toFixed(2)} GB)`))
