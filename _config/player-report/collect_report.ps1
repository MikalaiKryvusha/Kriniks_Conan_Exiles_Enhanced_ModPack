# collect_report.ps1 — отчёт игрока о падении или ошибке: журналы игры, отчёты о падениях и журнал Lua-модов в один zip на рабочий стол,
# без опознавателей компьютера и аккаунта. Запускается из collect_report.cmd в корне архива сборки.
#
# Зачем (KUMM план 35 Г13 / план 36 п. 5, слово владельца 2026-10-26: «сборка умеет логи об крешах и ошибках писать в файл? чтобы от игроков
# фидбек сорать»): игра пишет журналы сама, но игрок не знает, что прислать, а в отчёте о падении лежат MachineId, LoginId, EpicAccountId.
#
# Что обезличивается (разведка 2026-10-26 на падении UECC-…D5516A09…, 18:03): строки журнала «LogInit: Computer:» и «LogInit: User:»,
# «MachineId=…», теги и поля MachineId / LoginId / EpicAccountId, пути профиля «Users\<имя>», имя компьютера целым словом, SteamID, почта,
# IPv4 в сетевых строках. ИМЯ ПОЛЬЗОВАТЕЛЯ ОТДЕЛЬНЫМ СЛОВОМ НЕ ЗАМЕНЯЕТСЯ: у автора сборки оно — начало имён модов (Krinik…), и подстановка
# по всему тексту испортила бы журнал. Дамп памяти (UEMinidump.dmp) не берётся: в нём память процесса, обезличить его нельзя.
# В конце — самопроверка: настоящие значения опознавателей, прочитанные из исходных файлов, ищутся в готовом zip; нашлось — zip удаляется.
#
# Файл в UTF-8 С BOM: Windows PowerShell 5.1 читает .ps1 без BOM как ANSI, и русские строки испортились бы.
#   collect_report.ps1 [-GameDir <папка игры>] [-OutDir <куда положить zip>] [-Feedback]
# -Feedback — запуск кнопкой «ОТЗЫВ» в меню игры (KUMM план 36 W37, слово владельца 2026-10-31: «чтобы они легко могли мне на почтку отправлять
# логи и крешлитику»): готовый zip показывается в Проводнике, открывается письмо автору с темой и текстом. Приложить zip письмо по ссылке mailto
# не умеет — игрок перетаскивает файл сам, текст письма это и говорит. [NOT-TESTED] -Feedback
# [TESTED: 2026-10-30 · run on the owner machine with the game open: zip of 21 files, an independent scan found 0 identifiers · KUMM plans/36 W35]

param([string]$GameDir = '', [string]$OutDir = '', [switch]$Feedback)
$AUTHOR_MAIL = 'kotkrinik@yandex.ru'

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$exeRel = 'ConanSandbox\Binaries\Win64\ConanSandbox-Win64-Shipping.exe'
$LOG_BACKUPS = 3          # прошлых запусков, кроме текущего журнала
$CRASH_DAYS = 7           # падения за последние дни
$CRASH_MAX = 5            # и не больше стольких самых свежих

function Test-Game([string]$p) { return ($p -and (Test-Path (Join-Path $p $exeRel))) }

# ---------- кнопка «ОТЗЫВ»: игру — свернуть СРАЗУ, показать, что идёт работа, второй сборщик не запускать
# Владелец 2026-10-31 11:06 (нажал «Отзыв» в меню паузы): `[OWNER]` «нажатие на ОТЗЫВ в меню паузы не сворачивает игру на рабочий стол - а
# надо бы? чтобы игрок видел? что что-то происходит». Журнал того нажатия: сборка шла 22 с при игре на весь экран, игра сворачивалась
# только в самом конце; игрок нажал второй раз, и второй сборщик пошёл параллельно в тот же файл. Замер без игры — 13,4 с (обезличивание
# 18,8 МБ журналов). [TESTED: 2026-10-31 · реальный щелчок в главном меню при 1080p: игра свёрнута сразу, окно ожидания в центре, второй сборщик выходит · KUMM testcases/reports/2026-10-31_conan-feedback-minimize-first.md]
$progress = $null
if ($Feedback) {
    $one = New-Object System.Threading.Mutex($false, 'Local\KrinikConanFeedback')
    if (-not $one.WaitOne(0)) { exit 0 }        # сборщик уже работает — его окно на экране
    Add-Type -Namespace KR -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr h, int c);
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
'@
    Get-Process ConanSandbox-Win64-Shipping -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } |
        ForEach-Object { [void][KR.Win]::ShowWindow($_.MainWindowHandle, 6) }   # 6 = SW_MINIMIZE
    # Окно ожидания — чёткое при любом масштабе Windows (HOUSE_RULES KUMM §1 п. 17: у владельца 300 %): процесс объявлен DPI-aware,
    # размеры — от шрифта в пунктах, окно подгоняется под текст.
    [void][KR.Win]::SetProcessDPIAware()
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $progress = New-Object Windows.Forms.Form
    $progress.Text = 'Отзыв о сборке Krinik Mod Pack'
    $progress.FormBorderStyle = 'FixedDialog'; $progress.ControlBox = $false; $progress.TopMost = $true
    $progress.ShowInTaskbar = $true
    $progress.Font = New-Object Drawing.Font('Segoe UI', 12)
    # Отступ и размер — от высоты шрифта в пикселях (при 300 % она втрое больше), окно — по тексту и в центре рабочей области:
    # прогон 11:13 с Padding формы и AutoSize — текст прижат к левому краю (Padding формы действует только на пристыкованные элементы),
    # окно не в центре (CenterScreen считает место до подгонки размера).
    $pad = [int]($progress.Font.Height * 1.2)
    $msg = New-Object Windows.Forms.Label
    $msg.AutoSize = $true
    $msg.Text = "Собираем журналы игры для отзыва.`r`nПодождите немного: окно закроется само."
    $msg.Location = New-Object Drawing.Point($pad, $pad)
    $progress.Controls.Add($msg)
    $sz = $msg.PreferredSize
    $progress.ClientSize = New-Object Drawing.Size(($sz.Width + 2 * $pad), ($sz.Height + 2 * $pad))
    $wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $progress.StartPosition = 'Manual'
    $progress.Location = New-Object Drawing.Point(($wa.X + [int](($wa.Width - $progress.Width) / 2)), ($wa.Y + [int](($wa.Height - $progress.Height) / 2)))
    $progress.Show()
    # Игра запускает сборщик через `start "" /min` (консоль не мелькает), и Windows отдаёт это «свёрнуто» первому показанному окну процесса:
    # прогон 2026-10-31 11:12 — окно ожидания живо, но IsIconic = True, на экране его нет. Развернуть явно.
    $progress.WindowState = 'Normal'
    [void][KR.Win]::ShowWindow($progress.Handle, 9)   # 9 = SW_RESTORE
    $progress.Activate()
    [Windows.Forms.Application]::DoEvents()
}

# Чтение файла, который игра держит открытым: ReadAllText просит монопольный доступ и падает, пока игра запущена или висит
# («The process cannot access the file … ConanSandbox.log», первый прогон 2026-10-30 13:0x при открытой игре) — а игрок
# собирает отчёт как раз тогда. Общий доступ на чтение и запись, как у Блокнота.
function Read-Shared([string]$path) {
    $fs = New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try { $sr = New-Object IO.StreamReader($fs, $true); return $sr.ReadToEnd() } finally { $fs.Dispose() }
}

# Папка игры — как у install.ps1: рядом с папкой сборки или в ней самой, иначе спросить.
if (-not (Test-Game $GameDir)) {
    $GameDir = ''
    foreach ($c in @((Split-Path $here -Parent), $here)) { if (Test-Game $c) { $GameDir = $c; break } }
}
while (-not (Test-Game $GameDir)) {
    if ($GameDir) { Write-Host "Здесь нет игры (не найден $exeRel): $GameDir" -ForegroundColor Yellow }
    $answer = Read-Host 'Папка игры Conan Exiles (та, где лежит папка ConanSandbox)'
    if (-not $answer) { exit 2 }
    $GameDir = $answer.Trim().Trim('"')
}

$saved = Join-Path $GameDir 'ConanSandbox\Saved'
if (-not $OutDir) { $OutDir = [Environment]::GetFolderPath('Desktop') }
$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm'
$name = "Conan-report-$stamp"
$work = Join-Path $env:TEMP $name
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null

# ---------- что берём
$take = New-Object System.Collections.ArrayList   # пары: исходный файл → путь внутри отчёта
$logs = Join-Path $saved 'Logs'
if (Test-Path (Join-Path $logs 'ConanSandbox.log')) { [void]$take.Add(@((Join-Path $logs 'ConanSandbox.log'), 'Logs\ConanSandbox.log')) }
Get-ChildItem $logs -Filter 'ConanSandbox-backup-*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending |
    Select-Object -First $LOG_BACKUPS | ForEach-Object { [void]$take.Add(@($_.FullName, "Logs\$($_.Name)")) }
$crashRoot = Join-Path $saved 'Crashes'
$crashes = @(Get-ChildItem $crashRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-$CRASH_DAYS) } |
    Sort-Object LastWriteTime -Descending | Select-Object -First $CRASH_MAX)
foreach ($c in $crashes) {
    Get-ChildItem $c.FullName -File | Where-Object { $_.Extension -ne '.dmp' } |
        ForEach-Object { [void]$take.Add(@($_.FullName, "Crashes\$($c.Name)\$($_.Name)")) }
}
$ue4ss = Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ue4ss\UE4SS.log'
if (Test-Path $ue4ss) { [void]$take.Add(@($ue4ss, 'UE4SS.log')) }
$modlist = Join-Path $GameDir 'ConanSandbox\Mods\modlist.txt'
if (Test-Path $modlist) { [void]$take.Add(@($modlist, 'modlist.txt')) }

# ---------- настоящие значения опознавателей — для самопроверки в конце (в отчёт они не попадают)
$secrets = New-Object System.Collections.Generic.HashSet[string]
$idRe = '(?i)(?:MachineId|LoginId|EpicAccountId)(?:\s*[=:]\s*|>)([0-9A-Za-z|\-]{8,})'
$userName = $env:USERNAME
$computer = $env:COMPUTERNAME
foreach ($pair in $take) {
    $t = Read-Shared $pair[0]
    foreach ($m in [regex]::Matches($t, $idRe)) { [void]$secrets.Add($m.Groups[1].Value) }
}
if ($userName) { [void]$secrets.Add("Users\$userName"); [void]$secrets.Add("Users/$userName") }

# ---------- обезличивание
function Scrub([string]$t) {
    $t = [regex]::Replace($t, '(?m)(LogInit:\s*Computer:\s*)\S+', '$1<COMPUTER>')
    $t = [regex]::Replace($t, '(?m)(LogInit:\s*User:\s*)\S+', '$1<USER>')
    $t = [regex]::Replace($t, '(?i)((?:MachineId|LoginId|EpicAccountId)\s*[=:]\s*)[0-9A-Za-z|\-]+', '$1<ID>')
    $t = [regex]::Replace($t, '(?i)(<(MachineId|LoginId|EpicAccountId)>)[^<]*(</\2>)', '$1<ID>$3')
    $t = [regex]::Replace($t, '(?i)([\\/]Users[\\/])[^\\/"<>\r\n]+', '$1<USER>')
    if ($script:computer) { $t = [regex]::Replace($t, '(?i)\b' + [regex]::Escape($script:computer) + '\b', '<COMPUTER>') }
    $t = [regex]::Replace($t, '\b7656119\d{10}\b', '<STEAMID>')
    $t = [regex]::Replace($t, '[\w.+-]+@[\w-]+\.[\w.-]+', '<EMAIL>')
    # IPv4 — только в сетевых строках: версии библиотек (2.0.2.68) того же вида и нужны для разбора
    $t = [regex]::Replace($t, '(?im)^.*(?:LogNet|LogOnline|IpNetDriver|Socket|IPv4|address|Trying ).*$', [Text.RegularExpressions.MatchEvaluator]{
        param($line) [regex]::Replace($line.Value, '(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])', '<IP>') })
    return $t
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($pair in $take) {
    $dst = Join-Path $work $pair[1]
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    [IO.File]::WriteAllText($dst, (Scrub (Read-Shared $pair[0])), $utf8)
}

# ---------- сводка: сборка, игра, видеокарта — то, без чего отчёт не разобрать
$info = New-Object System.Collections.ArrayList
$pj = Join-Path $here 'pack\modpack.json'
if (Test-Path $pj) {
    $m = Get-Content $pj -Raw -Encoding UTF8 | ConvertFrom-Json
    [void]$info.Add("Сборка: $($m.packName) $($m.packVersion)")
    [void]$info.Add("Для игры: $($m.builtFor)")
}
[void]$info.Add("Собран: $(Get-Date -Format 'yyyy-MM-dd HH:mm zzz')")
try { [void]$info.Add("Windows: $((Get-CimInstance Win32_OperatingSystem).Caption) $([Environment]::OSVersion.Version)") } catch { }
try { Get-CimInstance Win32_VideoController | ForEach-Object { [void]$info.Add("Видеокарта: $($_.Name), драйвер $($_.DriverVersion)") } } catch { }
[void]$info.Add("Падений в отчёте: $($crashes.Count) (за $CRASH_DAYS дней, не больше $CRASH_MAX); дампы памяти не включены")
[void]$info.Add("Журналов игры: $(@($take | Where-Object { $_[1] -like 'Logs\*' }).Count)")
[IO.File]::WriteAllText((Join-Path $work 'report.txt'), (($info -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))

# ---------- zip и самопроверка
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$zip = Join-Path $OutDir "$name.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($work, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)

$leaks = @()
$z = [IO.Compression.ZipFile]::OpenRead($zip)
try {
    foreach ($e in $z.Entries) {
        $sr = New-Object IO.StreamReader($e.Open())
        $t = $sr.ReadToEnd(); $sr.Close()
        foreach ($s in $secrets) { if ($s -and $t.IndexOf($s, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $leaks += "$($e.FullName)" } }
        # имя компьютера — целым словом, как при замене: у компьютера «PC» подстрокой нашлось бы «PCallStack»
        if ($computer -and [regex]::IsMatch($t, '(?i)\b' + [regex]::Escape($computer) + '\b')) { $leaks += "$($e.FullName)" }
    }
} finally { $z.Dispose() }
Remove-Item $work -Recurse -Force
if ($progress) { $progress.Close() }

if ($leaks.Count) {
    Remove-Item $zip -Force
    Write-Host 'Отчёт НЕ собран: в нём осталось что-то, что выдаёт компьютер или аккаунт. Файлы:' -ForegroundColor Red
    $leaks | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" }
    exit 4
}
Write-Host ''
Write-Host "Готово: $zip" -ForegroundColor Green
Write-Host 'Отправьте этот файл автору сборки на почту kotkrinik@yandex.ru или в личные сообщения на PlayGround (https://users.playground.ru/4580431/)'
Write-Host 'и опишите, что происходило в игре перед падением или ошибкой.'
Write-Host 'Номера компьютера и аккаунта, имя пользователя и дамп памяти в отчёт не попали.'
if ($Feedback) {
    # Полноэкранная игра закрывает собой Проводник и письмо (прогон 2026-10-31 01:32: оба открылись ЗА игрой) — она свёрнута в начале;
    # здесь — ещё раз, на случай, если игрок развернул её, пока шла сборка.
    Get-Process ConanSandbox-Win64-Shipping -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } |
        ForEach-Object { [void][KR.Win]::ShowWindow($_.MainWindowHandle, 6) }   # 6 = SW_MINIMIZE
    Start-Process explorer.exe "/select,`"$zip`""
    # Почтовой программы может не быть или она просит войти (прогон 2026-10-31 01:34: mailto открыл Outlook на экране входа, а подсказка
    # оказалась ПОД ним) — поэтому сначала подсказка с адресом поверх всех окон, письмо — после «OK».
    # Поверх всех — флагом самого окна MB_TOPMOST: невидимая TopMost-форма-владелец его не передаёт (прогон 2026-10-31 07:47: подсказка
    # topmost=False ушла под VS Code, когда фокус забрало другое окно, и письмо ждало «OK» за чужими окнами).
    Add-Type -Namespace KR -Name Box -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int MessageBoxW(System.IntPtr h, string text, string caption, uint type);'
    $MB_OK_INFO_TOPMOST = 0x0 -bor 0x40 -bor 0x10000 -bor 0x40000   # MB_OK · MB_ICONINFORMATION · MB_SETFOREGROUND · MB_TOPMOST
    [void][KR.Box]::MessageBoxW([IntPtr]::Zero,
        "Журналы игры собраны в файл на рабочем столе:`r`n$(Split-Path $zip -Leaf)`r`n`r`nОтправьте его автору сборки на почту $AUTHOR_MAIL`r`nи напишите пару слов: что понравилось, что сломалось.`r`n`r`nНомера компьютера и аккаунта и имя пользователя в файл не попали.",
        'Отзыв о сборке Krinik Mod Pack', $MB_OK_INFO_TOPMOST)
    $subject = 'Отзыв о сборке Krinik Mod Pack'
    $body = "Здравствуйте!`r`n`r`nМой отзыв:`r`n`r`n`r`nЖурналы игры собраны в файл $(Split-Path $zip -Leaf) на рабочем столе — перетащите его в это письмо.`r`n"
    Start-Process ("mailto:{0}?subject={1}&body={2}" -f $AUTHOR_MAIL, [uri]::EscapeDataString($subject), [uri]::EscapeDataString($body))
}
exit 0
