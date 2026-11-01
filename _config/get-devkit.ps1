<#
    get-devkit.ps1 -- консольный загрузчик Conan Exiles Enhanced Dev Kit.

    ПОЧЕМУ НЕ ПРОСТО СКАЧАТЬ ПО ССЫЛКЕ. Прямого URL у Epic нет: раздача идёт
    через их сервис, файл собирается из тысяч кусков по манифесту. Поэтому
    качает legendary - открытый консольный клиент Epic (derrod/legendary),
    он же и показывает проценты, скорость и оставшееся время.

    ⚠️ ФАЙЛ СОХРАНЁН С BOM НАМЕРЕННО. Windows PowerShell 5.1 читает .ps1 без
    BOM как ANSI (кодовая страница 1251 на этой машине), и кириллица портится
    ДО запуска. Правишь файл - сохраняй как UTF-8 с BOM.

    ЗАПУСК:  .\get-devkit.ps1
             .\get-devkit.ps1 -Path F:\CEDevKit
             .\get-devkit.ps1 -Resume     (продолжить прерванную загрузку)
#>

param(
    [string]$Path = 'F:\CEDevKit',
    # Код приложения можно назвать явно. Умолчание - тот, что нашёлся в
    # библиотеке владельца 2026-09-10; если Epic его сменит, скрипт всё равно
    # найдёт комплект по названию (см. ниже).
    # ⚠️ ИМЯ НЕ '$App'. В PowerShell имена переменных НЕ различают регистр, и
    # $App с локальной $app оказались бы ОДНОЙ переменной: присваивание
    # '$app = $null' ниже стёрло бы параметр, и в legendary ушло бы пустое имя
    # приложения. Ровно это и случилось 2026-09-10 - окно открывалось, доходило
    # до "найден: []" и падало на 'the following arguments are required'.
    [string]$AppId = '912a768dddac4142b862ad0fc2ad98df',
    [switch]$Resume,
    # Сколько потоков качают. По умолчанию legendary берёт своё значение;
    # здесь ручка на случай, если канал будет упираться.
    [int]$Workers = 0
)

# ⚠️ НЕ 'Stop', И ЭТО НЕ НЕБРЕЖНОСТЬ. В Windows PowerShell 5.1 перенаправление
# 2>&1 от НАТИВНОЙ программы заворачивает каждую её строку в ErrorRecord, и при
# ErrorActionPreference='Stop' скрипт обрывается на первом же INFO. legendary
# печатает свои сообщения именно в stderr, поэтому со 'Stop' этот скрипт не
# доживал до загрузки: окно открывалось и молча закрывалось.
# Все проверки ниже явные - по тексту вывода и по $LASTEXITCODE.
$ErrorActionPreference = 'Continue'

# Консоль должна печатать UTF-8, иначе вывод ниже станет кракозябрами
# независимо от того, как сохранён сам файл.
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$host.UI.RawUI.WindowTitle = 'Загрузка Conan Exiles Enhanced Dev Kit'

function Say($t)  { Write-Host $t }
function Head($t) { Write-Host ''; Write-Host ('=== ' + $t) -ForegroundColor Cyan }
function Ok($t)   { Write-Host ('  [ок]   ' + $t) -ForegroundColor Green }
function Warn($t) { Write-Host ('  [!]    ' + $t) -ForegroundColor Yellow }
function Bad($t)  { Write-Host ('  [нет]  ' + $t) -ForegroundColor Red }

# legendary ставится через winget как псевдоним и в текущем сеансе PATH
# может ещё не обновиться - собираем PATH заново из реестра.
$env:PATH = [Environment]::GetEnvironmentVariable('PATH','Machine') + ';' +
            [Environment]::GetEnvironmentVariable('PATH','User')

Head 'Проверка окружения'

$leg = Get-Command legendary -ErrorAction SilentlyContinue
if (-not $leg) {
    Bad 'legendary не найден. Поставить: winget install --id derrod.legendary'
    Read-Host 'Enter - закрыть'
    exit 1
}
Ok ('legendary: ' + $leg.Source)

# Диск: упереться в место на 80-м проценте - худший способ узнать про размер.
# Числа СНЯТЫ, а не взяты из сети: legendary info 2026-09-10 -
# скачать 145.87 ГиБ, на диске 168.54 ГиБ, 147 967 файлов, 169 506 кусков.
# В сети гуляла оценка 192-250 ГБ - она завышена почти вдвое.
$drive = (Split-Path -Qualifier $Path)
$free = (Get-PSDrive -Name $drive.TrimEnd(':')).Free / 1GB
Ok ('свободно на ' + $drive + ' ' + [math]::Round($free,1) + ' ГБ')
if ($free -lt 185) {
    Warn 'На диске нужно ~169 ГиБ (скачать ~146 ГиБ). Места впритык - следи за прогрессом.'
}

# Длинные пути ломают сборку модов - об этом прямо предупреждает разведка
# пака (docs/02). Путь к комплекту держим коротким.
if ($Path.Length -gt 20) {
    Warn ('Путь длинноват (' + $Path.Length + ' символов). Сборка модов на длинных путях ломается.')
}

Head 'Вход в учётную запись Epic'

$status = & legendary status 2>&1 | Out-String
if ($status -match 'not logged in') {
    Bad 'Не выполнен вход в Epic.'
    Say ''
    Say '  Два способа, любой на выбор:'
    Say '    1) Открыть Epic Games Launcher, войти, ЗАКРЫТЬ его,'
    Say '       потом здесь:  legendary auth --import'
    Say '    2) Прямо в консоли:  legendary auth'
    Say '       (откроется браузер; из ответа скопировать authorizationCode)'
    Say ''
    Read-Host 'Enter - закрыть'
    exit 1
}
$acct = ($status -split "`n" | Where-Object { $_ -match 'Epic account' }) -join ''
Ok $acct.Trim()

Head 'Поиск комплекта в библиотеке'

# Ищем по названию, а не по заранее вписанному коду приложения: код у Epic
# меняется между изданиями, а название - нет.
$found = $null
$foundTitle = ''

# Список библиотеки берём ОДИН раз простым текстом: --json у legendary
# печатает и служебные строки, и разбор их ломает.
$plain = & legendary list 2>&1 | Out-String

# 1) Код назван явно и он в библиотеке - берём без поиска.
if ($AppId -and ($plain -match [regex]::Escape($AppId))) {
    $found = $AppId
    $foundTitle = 'Conan Exiles Enhanced Dev Kit'
}

# 2) Иначе ищем по НАЗВАНИЮ: код у Epic может смениться между изданиями, а
#    название - нет. Строка списка выглядит так:
#      * Conan Exiles Enhanced Dev Kit (App name: 912a... | Version: 374980)
if (-not $found) {
    foreach ($line in ($plain -split "`n")) {
        if ($line -match 'Dev ?Kit' -and $line -match 'App name:\s*([0-9a-zA-Z_]+)') {
            $found = $Matches[1]
            $foundTitle = ($line -replace '^\s*\*\s*','' -replace '\s*\(App name.*$','').Trim()
            break
        }
    }
}

if (-not $found) {
    Bad 'Комплект не найден в библиотеке Epic.'
    Say ''
    Say '  Его надо СНАЧАЛА ЗАБРАТЬ - он бесплатный, но должен лежать в библиотеке:'
    Say '    https://store.epicgames.com/p/conan-exiles-enhanced-dev-kit'
    Say '  Нажать "Получить", потом запустить этот скрипт снова.'
    Say ''
    Say '  Что вообще видно в библиотеке:'
    Say $plain
    Say ''
    Read-Host 'Enter - закрыть'
    exit 1
}
Ok ('найден: ' + $foundTitle + '  [' + $found + ']')

Head 'Загрузка'
Say ('  куда:    ' + $Path)
Say ('  прервать: Ctrl+C - продолжится с этого места при следующем запуске')
Say ''

if (-not (Test-Path $Path)) { $null = New-Item -ItemType Directory -Path $Path -Force }

$dlArgs = @('install', $found, '--base-path', $Path, '--yes')
if ($Workers -gt 0) { $dlArgs += @('--max-workers', "$Workers") }

# Сторож против дефекта, который здесь уже был: пустое имя приложения уходило
# в legendary, и тот падал на разборе аргументов, сообщая о СЕБЕ, а не о причине.
if (-not $found -or $found.Trim() -eq '') {
    Bad 'код приложения пуст - запускать нечего. Это дефект скрипта, а не библиотеки.'
    Read-Host 'Enter - закрыть'
    exit 1
}

# ---------------------------------------------------------------- ПАНЕЛЬ
#
# ЗАЧЕМ. legendary печатает прогресс НОВЫМИ СТРОКАМИ - раз в секунду по пять
# штук, и за час это десятки тысяч строк бегущей простыни. Слово владельца:
# «я думал, ты красивый прогресс бар сделаешь, и статично, а не всё в новые
# строки». Поэтому строки не показываем, а РАЗБИРАЕМ и перерисовываем на месте.
#
# ⚠️ ОТКАТ НА ПРОСТЫЕ СТРОКИ ОБЯЗАТЕЛЕН. Управление курсором работает только в
# настоящем окне консоли; при перенаправлении вывода в файл или в чужой процесс
# SetCursorPosition бросает исключение. Тогда панель молча выключается, а
# загрузка идёт как шла - терять её из-за красоты нельзя.
$fancy = $true
try { $null = [Console]::CursorTop } catch { $fancy = $false }
if ($Host.Name -notmatch 'ConsoleHost') { $fancy = $false }

$st = @{
    pct = 0.0; cur = 0; total = 0
    dl = ''; wr = ''
    rawMbs = 'считаю...'
    elapsed = ''; eta = ''
    note = ''
}

function Render-Panel {
    if (-not $fancy) { return }
    $w = 44
    $filled = [int][Math]::Round($w * $st.pct / 100.0)
    if ($filled -lt 0) { $filled = 0 }
    if ($filled -gt $w) { $filled = $w }
    $bar = ('#' * $filled) + ('.' * ($w - $filled))

    $lines = @(
        ''
        ('   ' + $foundTitle)
        ('   -> ' + $Path)
        ''
        ('   [' + $bar + ']  ' + $st.pct.ToString('0.00') + ' %')
        ''
        ('   частей      ' + $st.cur + ' / ' + $st.total)
        ('   скачано     ' + $st.dl + '   записано ' + $st.wr)
        ('   скорость    ' + $st.rawMbs)
        ('   прошло      ' + $st.elapsed + '   осталось ~' + $st.eta)
        ''
        ('   ' + $st.note)
        ''
    )
    try {
        [Console]::SetCursorPosition(0, $script:panelTop)
        foreach ($l in $lines) {
            $pad = $l.PadRight([Math]::Max(0, [Console]::WindowWidth - 1))
            [Console]::WriteLine($pad)
        }
    } catch { $script:fancy = $false }
}

if ($fancy) {
    try { $script:panelTop = [Console]::CursorTop } catch { $fancy = $false }
}

$started = Get-Date

# ⚠️ ПАНЕЛЬ НЕ ИМЕЕТ ПРАВА МОЛЧАТЬ. Первая её редакция обновлялась ТОЛЬКО на
# строках прогресса, и когда legendary вышел, не начав качать, владелец увидел
# пустое окно: программа сказала «скачивать нечего», а панель это проглотила.
# Поэтому здесь три страховки: последние строки копятся всегда; ошибки рисуются
# сразу; а если строк прогресса не было ВООБЩЕ - в конце печатается хвост
# сырого вывода. Класс отказа старый: тишина неотличима от успеха.
$rawTail = New-Object System.Collections.Generic.Queue[string]
$sawProgress = $false

# Разбираем ТЕКСТ вывода. Числа берём как есть, вместе с единицами: пересчёт
# MiB/GiB своими руками - лишняя сущность и лишний источник ошибок.
& legendary @dlArgs 2>&1 | ForEach-Object {
    $line = $_.ToString()

    $rawTail.Enqueue($line)
    while ($rawTail.Count -gt 25) { $null = $rawTail.Dequeue() }

    if ($line -match 'Progress:\s*([\d.]+)%\s*\((\d+)/(\d+)\)') {
        $st.pct = [double]$Matches[1]; $st.cur = $Matches[2]; $st.total = $Matches[3]
        $sawProgress = $true
    }
    if ($line -match 'Running for\s*([\d:]+)') { $st.elapsed = $Matches[1] }
    if ($line -match 'ETA:\s*([\d:]+)')        { $st.eta = $Matches[1] }
    if ($line -match 'Downloaded:\s*([\d.]+\s*\w+),\s*Written:\s*([\d.]+\s*\w+)') {
        $st.dl = $Matches[1]; $st.wr = $Matches[2]
    }
    # ⚠️ СКОРОСТЬ СЧИТАЕМ САМИ, А НЕ РАЗБИРАЕМ ЧУЖУЮ СТРОКУ. Первая редакция
    # ловила строку legendary про скорость регулярным выражением - и поля
    # молча оставались пустыми, потому что формат оказался другим. Своя
    # арифметика по уже разобранному объёму не зависит от чужого оформления
    # и не может разойтись с ним: это ОДНО число, а не пара, которую надо
    # сторожить. Занижение в первые секунды - цена, и она видна честно.
    if ($st.dl -match '([\d.]+)\s*(\w+)') {
        $val = [double]$Matches[1]
        $mib = switch ($Matches[2]) {
            'GiB' { $val * 1024 }
            'KiB' { $val / 1024 }
            default { $val }
        }
        $now = Get-Date
        if ($script:prevMib -ne $null) {
            $dt = ($now - $script:prevAt).TotalSeconds
            if ($dt -ge 1) {
                $st.rawMbs = ([math]::Round(($mib - $script:prevMib) / $dt, 1)).ToString() + ' MiB/s'
                $script:prevMib = $mib; $script:prevAt = $now
            }
        } else {
            $script:prevMib = $mib; $script:prevAt = $now
        }
    }

    if ($line -match 'ERROR|WARNING|Failure|Traceback|Exiting') {
        $st.note = ($line -replace '^\[[^\]]+\]\s*', '').Trim()
        if ($fancy) { Render-Panel } else { Write-Host $line -ForegroundColor Yellow }
    }
    elseif ($line -match 'Progress:') {
        Render-Panel
        if (-not $fancy) { Write-Host $line }
    }
    elseif (-not $sawProgress) {
        # До первой строки прогресса показываем ВСЁ: там подготовка, выбор CDN
        # и вся диагностика, ради которой окно и открыто.
        Write-Host ('  ' + $line) -ForegroundColor DarkGray
        if ($fancy) { try { $script:panelTop = [Console]::CursorTop } catch { } }
    }
}
$code = $LASTEXITCODE
$took = (Get-Date) - $started

Say ''
Read-Host 'Enter - закрыть окно'
