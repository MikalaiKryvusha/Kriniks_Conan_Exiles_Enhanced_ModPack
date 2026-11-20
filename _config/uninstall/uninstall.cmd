@echo off
chcp 65001 >nul
echo Удаление сборки Krinik: игра вернётся в тот вид, в каком была до установки сборки.
echo Закройте игру перед удалением.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0{BACKUP}\Deploy-ModPack.ps1" -Restore -GameDir "%~dp0."
if errorlevel 1 (
  echo.
  echo Удаление не завершено: папка копий {BACKUP} и этот файл оставлены. Пришлите автору сборки снимок этого окна.
  pause
  exit /b 1
)
if not "{SHORTCUT}"=="" powershell -NoProfile -Command "Remove-Item -LiteralPath (Join-Path $(if ($env:KUMM_DESKTOP_DIR) {$env:KUMM_DESKTOP_DIR} else {[Environment]::GetFolderPath('Desktop')}) '{SHORTCUT}.lnk') -ErrorAction SilentlyContinue"
echo.
echo Готово: сборка удалена, файлы игры вернулись на место.
pause
(goto) 2>nul & del "%~f0"
