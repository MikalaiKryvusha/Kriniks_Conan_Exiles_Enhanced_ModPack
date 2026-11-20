// feed.mjs — a local stand-in for the GitHub Releases feed of the Krinik launcher (KUMM plan 54, cases in KUMM testcases/TC_conan_launcher_updates_2026-11-17.md).
// It answers GET /releases with the same fields the launcher reads from api.github.com (tag_name, html_url, draft, prerelease, assets[name, size, digest,
// browser_download_url]) and serves the assets the way GitHub does: the download URL answers 302 to the file, the file honours Range (resume).
// The launcher is pointed at it by KRINIK_LAUNCHER_FEED=http://127.0.0.1:<port>/releases — never set on a player's machine.
//
//   node feed.mjs --port 8765 [--build 1.0.1 --parts <dir with <stem>.zip.NNN>] [--launcher 1.0.1 --exe <file>] [--forge] [--refuse] [--log <file>]
//     --forge   the launcher asset's digest is wrong (the self-update must refuse it)
//     --refuse  every request answers 503 (the «feed did not answer» case)
//     --game "3.1.1 CL-383549"  the build release's body carries the game marker «<!-- krinik-game: 3.1.1 CL-383549 -->» the launcher matches by (KUMM
//               plans/57; default as shown, «none» — no marker); --cut <bytes>  the FIRST file response is broken off after so many bytes (the network
//               failure of criterion 8); later requests are whole; --rate <bytes/s>  every file is sent no faster than that (the progress frames)
//     --status <code>[,<code>…]  the first whole-file requests (no Range) for any part but .001 answer these codes, one each in turn — part .001 is
//               saved first, so the window has something kept to resume: 429 «too many requests» and 408 «request timeout» pass by themselves, and the
//               launcher must treat them as a broken connection (the judge 2026-11-18, round 2, finding 8)
//     --range416  the first Range request for the file --cut broke answers 416: the launcher must drop the part and fetch it whole (same finding)
// Every request is one line in --log (or stdout): the case reads what the launcher asked for. Zero dependencies (node: only).
// [NOT-TESTED]
import { createServer } from 'node:http'
import { createHash } from 'node:crypto'
import { createReadStream, readdirSync, statSync, appendFileSync } from 'node:fs'
import { Transform } from 'node:stream'
import path from 'node:path'

const args = process.argv.slice(2)
const opt = name => { const i = args.indexOf('--' + name); return i >= 0 ? args[i + 1] : undefined }
const flag = name => args.includes('--' + name)
const port = Number(opt('port') || 8765)
const base = `http://127.0.0.1:${port}`
const logFile = opt('log')
const log = line => { const s = `${new Date().toISOString()} ${line}`; if (logFile) appendFileSync(logFile, s + '\n'); else console.log(s) }

const files = new Map() // name -> absolute path
// Streamed: the build's parts are 2 GB each — reading them whole held the feed back long enough for the launcher to ask a closed port (B3, 15:13).
const sha = file => new Promise((ok, no) => {
  const h = createHash('sha256')
  createReadStream(file).on('data', d => h.update(d)).on('end', () => ok(h.digest('hex'))).on('error', no)
})
const asset = async (file, forge = false) => {
  const name = path.basename(file)
  files.set(name, file)
  const digest = forge ? '0'.repeat(64) : await sha(file)
  return { name, size: statSync(file).size, digest: 'sha256:' + digest, browser_download_url: `${base}/download/${encodeURIComponent(name)}` }
}

// --rate: a pipe that lets through at most <rate> bytes per second, in 50 ms slices.
const rate = Number(opt('rate') || 0)
const send = (src, res, opts) => {
  if (!rate) return src.pipe(res, opts)
  const slice = Math.max(1, Math.floor(rate / 20))
  const gate = new Transform({ transform(chunk, enc, done) {
    const parts = []
    for (let i = 0; i < chunk.length; i += slice) parts.push(chunk.subarray(i, i + slice))
    const next = () => { if (!parts.length) return done(); this.push(parts.shift()); setTimeout(next, 50) }
    next()
  } })
  return src.pipe(gate).pipe(res, opts)
}
const releases = []
let cutDone = false, cutFile = null, range416Done = false
const statuses = (opt('status') || '').split(',').filter(Boolean).map(Number)
if (opt('launcher')) {
  const v = opt('launcher')
  releases.push({ tag_name: `launcher-v${v}`, name: `Krinik launcher ${v}`, draft: false, prerelease: false,
    html_url: `${base}/page/launcher-v${v}`, assets: opt('exe') ? [await asset(path.resolve(opt('exe')), flag('forge'))] : [] })
}
if (opt('build')) {
  const v = opt('build'), dir = opt('parts') ? path.resolve(opt('parts')) : null
  const parts = []
  if (dir) for (const n of readdirSync(dir).filter(n => /\.zip\.\d{3}$/.test(n)).sort()) parts.push(await asset(path.join(dir, n)))
  const game = opt('game') || '3.1.1 CL-383549'
  releases.push({ tag_name: `v${v}`, name: `Krinik Mod Pack ${v}`, draft: false, prerelease: false, html_url: `${base}/page/v${v}`, assets: parts,
    body: game === 'none' ? 'Krinik Mod Pack' : `Krinik Mod Pack ${v}

<!-- krinik-game: ${game} -->
` })
}
// A draft and a prerelease with higher numbers: the launcher must ignore both.
releases.push({ tag_name: 'v99.0.0', draft: true, prerelease: false, html_url: `${base}/page/draft`, assets: [] })
releases.push({ tag_name: 'launcher-v99.0.0', draft: false, prerelease: true, html_url: `${base}/page/pre`, assets: [] })

createServer((req, res) => {
  // The stand's own «is it up» probe: 200 even in --refuse mode (curl --retry would retry a 503 for ten seconds).
  if (req.url === '/ready') { res.writeHead(200); return res.end('ok') }
  log(`${req.method} ${req.url} ua=${req.headers['user-agent'] || '-'} range=${req.headers.range || '-'}`)
  if (flag('refuse')) { res.writeHead(503); return res.end() }
  const url = new URL(req.url, base)
  if (url.pathname === '/releases') {
    res.writeHead(200, { 'content-type': 'application/json; charset=utf-8' })
    return res.end(JSON.stringify(releases))
  }
  // GitHub's browser_download_url answers 302 to the storage; the launcher must follow it and keep the Range header.
  if (url.pathname.startsWith('/download/')) {
    res.writeHead(302, { location: `${base}/file/${url.pathname.slice('/download/'.length)}` })
    return res.end()
  }
  if (url.pathname.startsWith('/file/')) {
    const name = decodeURIComponent(url.pathname.slice('/file/'.length)), file = files.get(name)
    if (!file) { res.writeHead(404); return res.end() }
    const size = statSync(file).size
    const m = /^bytes=(\d+)-$/.exec(req.headers.range || '')
    if (flag('range416') && !range416Done && m && name === cutFile) {
      range416Done = true
      log(`answered 416 to ${name}`)
      res.writeHead(416, { 'content-range': `bytes */${size}` })
      return res.end()
    }
    if (!req.headers.range && statuses.length && !name.endsWith('.001')) {
      const code = statuses.shift()
      log(`answered ${code} to ${name}`)
      res.writeHead(code)
      return res.end()
    }
    if (m && Number(m[1]) < size) {
      const from = Number(m[1])
      res.writeHead(206, { 'content-length': size - from, 'content-range': `bytes ${from}-${size - 1}/${size}` })
      return send(createReadStream(file, { start: from }), res)
    }
    res.writeHead(200, { 'content-length': size })
    // --cut <bytes>: the first whole-file answer stops after so many bytes and the socket is destroyed — the launcher sees a broken connection.
    const cut = Number(opt('cut') || 0)
    if (cut > 0 && !cutDone && size > cut) {
      cutDone = true; cutFile = name
      log(`cut after ${cut} bytes`)
      createReadStream(file, { end: cut - 1 }).on('end', () => setTimeout(() => res.destroy(), 100)).pipe(res, { end: false })
      return
    }
    // --slow <ms>: the first half of the file, a pause, the rest — a stop pressed in the pause leaves a half file, and the next run must ask for the
    // rest by Range (case B2).
    const slow = Number(opt('slow') || 0)
    if (slow > 0 && size > 1) {
      const half = Math.floor(size / 2)
      createReadStream(file, { end: half - 1 }).on('end', () => setTimeout(() => createReadStream(file, { start: half }).pipe(res), slow)).pipe(res, { end: false })
      return
    }
    return send(createReadStream(file), res)
  }
  res.writeHead(404)
  res.end()
}).listen(port, '127.0.0.1', () => log(`feed ready ${base}/releases · ${releases.map(r => r.tag_name).join(', ')}`))
