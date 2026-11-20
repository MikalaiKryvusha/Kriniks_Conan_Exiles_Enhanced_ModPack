// strings.mjs — criterion 10 of KUMM plans/57: no player-visible Russian literal in the launcher outside the language table (KrinikConanText.cs).
// Reads every launcher .cs but the table and BuildInfo.g.cs (generated from author_links.txt; its one Russian label is translated by Ui.LinkText), drops
// comments, removes the calls whose text only the developer reads — the log (Log / MetalWindow.Log / SelfUpdate.Settle, which logs its reason) — across
// lines, by balanced parentheses, and lists every string literal left with a Cyrillic letter. Exception messages are NOT skipped: `ex.Message` reaches the
// player through «u.failed» / «s.failed» (the judge 2026-11-18: Russian of two exceptions showed in the English window while this guard passed them).
// A line may carry «// ui-ok: <reason>» for a literal that is data, not text (a state-file stamp). Exit 0 — none; 1 — the list.
// English literals are not judged by this script (they look like code); the frames in both languages are.
//   node strings.mjs [<folder with the .cs files> — the guard's own red test]
// [NOT-TESTED]
import { readFileSync, readdirSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const DIR = process.argv[2] ? path.resolve(process.argv[2]) : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const SKIP = new Set(['KrinikConanText.cs', 'BuildInfo.g.cs'])
const CYR = /[А-Яа-яЁё]/
const CALLS = /(?:MetalWindow\.)?Log\(|Settle\(/g
const hits = []

// One file as code: comments out (outside strings), «ui-ok» lines blanked; positions keep their line numbers.
function code(text) {
  return text.split(/\r?\n/).map(raw => {
    if (/ui-ok:/.test(raw)) return ''
    let out = '', inStr = false
    for (let k = 0; k < raw.length; k++) {
      const c = raw[k]
      if (!inStr && c === '/' && raw[k + 1] === '/') break
      if (c === '"' && raw[k - 1] !== '\\') inStr = !inStr
      out += c
    }
    return out
  }).join('\n')
}

// Blank a call from its name to its balanced closing parenthesis (strings may hold parentheses; newlines are kept).
function blankCalls(t) {
  let res = t
  for (const m of t.matchAll(CALLS)) {
    let depth = 0, inStr = false, end = m.index + m[0].length - 1
    for (let k = end; k < t.length; k++) {
      const c = t[k]
      if (c === '"' && t[k - 1] !== '\\') inStr = !inStr
      if (inStr) continue
      if (c === '(') depth++
      if (c === ')' && --depth === 0) { end = k; break }
    }
    res = res.slice(0, m.index) + t.slice(m.index, end + 1).replace(/[^\n]/g, ' ') + res.slice(end + 1)
  }
  return res
}

for (const f of readdirSync(DIR).filter(n => n.endsWith('.cs') && !SKIP.has(n))) {
  const lines = blankCalls(code(readFileSync(path.join(DIR, f), 'utf8'))).split('\n')
  lines.forEach((l, i) => { for (const m of l.matchAll(/\$?@?"(?:[^"\\]|\\.)*"/g)) if (CYR.test(m[0])) hits.push(`${f}:${i + 1}: ${m[0]}`) })
}
if (hits.length) { console.log(hits.join('\n')); console.log(`${hits.length} Russian literal(s) outside the table`); process.exit(1) }
console.log('no Russian literal outside the table')
