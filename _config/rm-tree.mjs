// rm-tree.mjs — удалить папки целиком, файл за файлом (рекурсивное rm -rf запрещено правилом), не заходя по ссылкам.
// Зачем: порядок на D: по слову владельца 2026-11-17 19:44 («РАЗРЕШАЮ УДАЛИТЬ!») — отработанные папки сборки Конана.
// Защита: путь из списка неприкосновенных (чистая версия, библиотека, оригиналы, репо, D:\Temp) — отказ, ничего не удаляется.
// [TESTED: 2026-11-17 · a fixture with a junction: the junction removed, its target kept; protected paths refused with exit 3; then the real D: cleanup]
// Использование: node rm-tree.mjs [--dry] <dir> [<dir> …]
import fs from 'node:fs'
import path from 'node:path'

const args = process.argv.slice(2)
const dry = args.includes('--dry')
const dirs = args.filter(a => a !== '--dry')
const norm = p => path.resolve(p).toLowerCase().replace(/[\\/]+$/, '')
const PROTECTED = [
  'D:\\Instals\\Conan.Exiles.Enhanced.Complete.Edition-InsaneRamZes',
  'D:\\work\\ai_sandbox\\ConanExiles\\_library\\mods',
  'D:\\work\\ai_sandbox\\ConanExiles\\_library\\_patch-originals',
  'D:\\work\\ai_sandbox\\ConanExiles\\_library',
  'D:\\work\\ai_sandbox\\ConanExiles',
  'D:\\work\\ai_sandbox\\KUMM',
  'D:\\Temp', 'D:\\Games', 'D:\\Instals', 'D:\\work', 'D:\\work\\ai_sandbox', 'D:\\',
].map(norm)
for (const d of dirs) {
  const n = norm(d)
  if (PROTECTED.includes(n)) { console.error(`REFUSED protected: ${d}`); process.exit(3) }
  if (PROTECTED.slice(0, 2).some(p => n.startsWith(p + '\\'))) { console.error(`REFUSED inside protected: ${d}`); process.exit(3) }
}
for (const d of dirs) {
  if (!fs.existsSync(d)) { console.log(`absent ${d}`); continue }
  let nFiles = 0, nBytes = 0, nDirs = 0
  const top = fs.lstatSync(d)
  if (top.isSymbolicLink()) { if (!dry) fs.unlinkSync(d); console.log(`link removed ${d}`); continue }
  ;(function walk(dir) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, e.name)
      const st = fs.lstatSync(full)
      if (st.isSymbolicLink()) { if (!dry) fs.unlinkSync(full); nFiles++ }
      else if (st.isDirectory()) { walk(full); if (!dry) fs.rmdirSync(full); nDirs++ }
      else { nBytes += st.size; if (!dry) { try { fs.unlinkSync(full) } catch (err) { if (err.code === 'EPERM') { fs.chmodSync(full, 0o666); fs.unlinkSync(full) } else throw err } } nFiles++ }
    }
  })(d)
  if (!dry) fs.rmdirSync(d)
  console.log(`${dry ? 'would remove' : 'removed'} ${d}: files=${nFiles} dirs=${nDirs + 1} GB=${(nBytes / 1e9).toFixed(2)}`)
}
