@echo off
rem Ridmi (putevoditel 3.0.1) -> PDF i launcher -> exe. Ssylki avtora - iz author_links.txt ryadom.
chcp 65001 >nul
python "%~dp0_config\release\build-docs.py" %*
echo.
pause
