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
//     --corrupt <text>  every whole answer for a file whose name holds the text has one flipped byte; its digest stays real (case D5)
//     --slow <ms>  each whole-file answer sends half the file, pauses, then the rest (a stop or a kill in the pause leaves a half file)
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
// key — the request path of the file (/file/<key>): the assets of an older release (--older) are keyed «v<version>/<name>», so a request names its release
// even when both releases carry an asset of the same name. --digest-off <text>: the listed digest of every file whose name holds the text is another hash
// (the asset was re-uploaded after the manifest was made — judge 2026-11-21 round 3, RISK 1, case D5c); the bytes served stay real.
const asset = async (file, forge = false, key = path.basename(file)) => {
  const name = path.basename(file)
  files.set(key, file)
  const off = opt('digest-off') && name.includes(opt('digest-off'))
  const digest = forge ? '0'.repeat(64) : off ? '1'.repeat(64) : await sha(file)
  return { name, size: statSync(file).size, digest: 'sha256:' + digest, browser_download_url: `${base}/download/${encodeURIComponent(key)}` }
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
  // --assets <dir> (KUMM plan 57 phase 6): every file of the folder make_manifest.py wrote — manifest.json, the per-file assets, the parts, the group zip.
  if (opt('assets')) for (const n of readdirSync(path.resolve(opt('assets'))).sort()) parts.push(await asset(path.join(path.resolve(opt('assets')), n)))
  const game = opt('game') || '3.1.1 CL-383549'
  releases.push({ tag_name: `v${v}`, name: `Krinik Mod Pack ${v}`, draft: false, prerelease: false, html_url: `${base}/page/v${v}`, assets: parts,
    body: game === 'none' ? 'Krinik Mod Pack' : `Krinik Mod Pack ${v}

<!-- krinik-game: ${game} -->
` })
}
// --older <version>:<assets dir> (case D9, KUMM plan 57 criterion 7): an older build release the player skipped, listed with its own per-file assets.
if (opt('older')) {
  const [v, dir] = [opt('older').slice(0, opt('older').indexOf(':')), path.resolve(opt('older').slice(opt('older').indexOf(':') + 1))]
  const list = []
  for (const n of readdirSync(dir).sort()) list.push(await asset(path.join(dir, n), false, `v${v}/${n}`))
  releases.push({ tag_name: `v${v}`, name: `Krinik Mod Pack ${v}`, draft: false, prerelease: false, html_url: `${base}/page/v${v}`, assets: list,
    body: `Krinik Mod Pack ${v}\n\n<!-- krinik-game: ${opt('game') || '3.1.1 CL-383549'} -->\n` })
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
    // --corrupt <text> (KUMM plan 57 phase 6, case D5): every whole answer for a file whose name holds the text carries its first byte flipped, while the
    // listed digest stays the real one — the launcher must see the checksum fail on both tries.
    const corrupt = opt('corrupt')
    if (corrupt && name.includes(corrupt)) {
      log(`corrupted ${name}`)
      let first = true
      const flip = new Transform({ transform(chunk, enc, done) {
        if (first && chunk.length) { chunk = Buffer.from(chunk); chunk[0] ^= 0xff; first = false }
        done(null, chunk)
      } })
      return send(createReadStream(file).pipe(flip), res)
    }
    // --cut <bytes>: the first whole-file answer stops after so many bytes and the socket is destroyed — the launcher sees a broken connection.
    const cut = Number(opt('cut') || 0)
    if (cut > 0 && !cutDone && size > cut) {
      cutDone = true; cutFile = name
      log(`cut after ${cut} bytes`)
      createReadStream(file, { end: cut - 1 }).on('end', () => setTimeout(() => res.destroy(), 100)).pipe(res, { end: false })
      return
    }
    // --slow <ms>: the first part of the file, a pause, the rest — a stop pressed in the pause leaves a part file, and the next run must ask for the
    // rest by Range (case B2). The pause comes before the last 64 KiB (at least half the file): the launcher writes through a 1 MiB FileStream buffer,
    // and half of a 2 MiB asset sat whole in that buffer at a kill — 0 bytes on disk, case D3 red on the stand 2026-11-21 17:12 (run 11) once the asset
    // order put a 2 MiB asset first. A kill loses at most the buffer; the resume starts from the bytes on disk.
    const slow = Number(opt('slow') || 0)
    if (slow > 0 && size > 1) {
      const half = Math.max(Math.floor(size / 2), size - 65536)
      createReadStream(file, { end: half - 1 }).on('end', () => setTimeout(() => createReadStream(file, { start: half }).pipe(res), slow)).pipe(res, { end: false })
      return
    }
    return send(createReadStream(file), res)
  }
  res.writeHead(404)
  res.end()
}).listen(port, '127.0.0.1', () => log(`feed ready ${base}/releases · ${releases.map(r => r.tag_name).join(', ')}`))
