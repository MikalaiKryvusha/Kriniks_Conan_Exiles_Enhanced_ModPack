# watch-weather.ps1 -- снимает кадр раз в минуту, пока не кончится время.
#
# ASCII-ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY. Rain in Conan is random weather. The owner wants to SEE the widened rain
# mask (OrthoWidth 4096 -> 12288, docs/11), and the only honest way is to catch
# an actual downpour. Observed 2026-09-09: rain twice within one hour.
#
# Deliberately dumb: no rain detection, no cleverness. It just leaves a numbered
# frame per minute; a human (or the agent) looks at them. A detector guessing
# "is this rain" would be one more thing that can lie.
#
#   .\watch-weather.ps1 -Minutes 30 -Out C:\tmp\weather

param(
  [int]$Minutes = 30,
  [Parameter(Mandatory = $true)][string]$Out,
  [int]$Width = 640
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$capture = Join-Path $here 'capture.ps1'
$input_ps = Join-Path $here 'input.ps1'

if (-not (Test-Path $Out)) { $null = New-Item -ItemType Directory -Path $Out -Force }

for ($i = 0; $i -lt $Minutes; $i++) {
  if (-not (Get-Process -Name 'ConanSandbox-Win64-Shipping' -ErrorAction SilentlyContinue)) {
    Write-Output ("[{0}] the game is gone - stopping" -f (Get-Date -Format HH:mm:ss))
    break
  }
  # СБРОС ОБЛЁТА. В простое Конан сам крутит камеру вокруг героя, и кадры,
  # снятые раз в минуту, оказываются под разными углами - сравнивать их
  # бессмысленно. Замечено владельцем 09.09.2026. Крошечный сдвиг мыши туда и
  # обратно отменяет облёт, не меняя ни положения камеры, ни игрового состояния.
  & $input_ps -Look "6,0" | Out-Null
  & $input_ps -Look "-6,0" | Out-Null
  Start-Sleep -Milliseconds 400

  $path = Join-Path $Out ("m{0:d3}.png" -f $i)
  & $capture -Out $path -Width $Width | Out-Null
  Write-Output ("[{0}] {1}" -f (Get-Date -Format HH:mm:ss), (Split-Path $path -Leaf))
  Start-Sleep -Seconds 60
}
Write-Output 'watch finished'
