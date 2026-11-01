// Съёмщик макетов лаунчера: каждое окно `.win[data-v]` из mockups.html — отдельный кадр 3840×2160 (окно 960×540 при масштабе 4,
// то есть как на 4K-телевизоре владельца), плюс лист всех вариантов для глаза агента. Кадры — WebP 90 (правило проекта: PNG никогда).
// Playwright берётся из ndim (там он уже стоит), браузер — системный Chrome.
// Запуск: node shoot.mjs <папка для кадров> [--only 1,3]
// [NOT-TESTED]
import { resolve, join } from 'node:path'
import { pathToFileURL } from 'node:url'
import { mkdirSync } from 'node:fs'
import { execFileSync } from 'node:child_process'

const PW = 'file:///D:/work/ai_sandbox/ndim/node_modules/playwright/index.mjs'
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe'
const WIN_W = 960, WIN_H = 540, SCALE = 4

const out = resolve(process.argv[2] || 'shots')
const onlyAt = process.argv.indexOf('--only')
const only = onlyAt > -1 ? process.argv[onlyAt + 1].split(',') : null
// --query metal=3 — дописать к адресу окна (&metal=3) и к имени кадра (_metal3): варианты одного окна без копий разметки.
const queryAt = process.argv.indexOf('--query')
const query = queryAt > -1 ? process.argv[queryAt + 1] : ''
const tag = query ? '_' + query.replace('=', '') : ''
mkdirSync(out, { recursive: true })

const { chromium } = await import(PW)
const browser = await chromium.launch({ executablePath: CHROME })
const page = await browser.newPage({ viewport: { width: WIN_W + 80, height: WIN_H + 80 }, deviceScaleFactor: SCALE })
const url = pathToFileURL(resolve(import.meta.dirname, 'mockups.html')).href
await page.goto(url)
await page.evaluate(() => document.fonts.ready)
const ids = await page.$$eval('.win[data-v]', ws => ws.map(w => w.dataset.v))
const jpgs = []
for (const v of ids) {
  if (only && !only.includes(v)) continue
  await page.goto(`${url}?v=${v}${query ? '&' + query : ''}`)
  await page.evaluate(() => document.fonts.ready)
  await page.waitForTimeout(300)
  const el = await page.$(`.win[data-v="${v}"]`)
  const box = await el.boundingBox()
  if (Math.round(box.width) !== WIN_W || Math.round(box.height) !== WIN_H) throw new Error(`окно ${v}: ${box.width}x${box.height}, ждали ${WIN_W}x${WIN_H}`)
  const f = join(out, `variant_${v.padStart(2, '0')}${tag}.jpg`)
  await el.screenshot({ path: f, type: 'jpeg', quality: 95 })
  jpgs.push(f)
  console.log('shot', f)
}
await browser.close()
// JPEG → WebP 90 и лист вариантов (две колонки, по 960 на кадр) — одним вызовом Python.
execFileSync('python', ['-X', 'utf8', join(import.meta.dirname, 'to_webp_sheet.py'), out, ...jpgs], { stdio: 'inherit' })
