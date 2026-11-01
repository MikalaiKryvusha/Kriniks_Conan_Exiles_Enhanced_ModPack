@echo off
rem Collects the game logs and crash reports into one zip on the desktop, without computer and account ids (collect_report.ps1).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0collect_report.ps1" %*
echo.
pause
