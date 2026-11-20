@echo off
rem build_player.cmd - builds krinik_music_player.exe from src\ and vendor\ (miniaudio 0.11.26 + stb_vorbis, public domain / MIT-0).
rem Needs Visual Studio 2022 (Build Tools or Community) with the C++ workload. One command, no other tools.
rem A GUI-subsystem program: no console window of its own; output - State\player.log.
setlocal
set HERE=%~dp0
set VCVARS=
for %%E in (Community Professional Enterprise BuildTools) do (
  if exist "%ProgramFiles%\Microsoft Visual Studio\2022\%%E\VC\Auxiliary\Build\vcvars64.bat" set "VCVARS=%ProgramFiles%\Microsoft Visual Studio\2022\%%E\VC\Auxiliary\Build\vcvars64.bat"
  if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\%%E\VC\Auxiliary\Build\vcvars64.bat" set "VCVARS=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\%%E\VC\Auxiliary\Build\vcvars64.bat"
)
if "%VCVARS%"=="" ( echo Visual Studio 2022 C++ tools not found & exit /b 2 )
call "%VCVARS%" >nul
rem Intermediates go to TEMP: an obj\ beside the exe would be shipped by the deploy (it copies the mod folder whole).
set OBJ=%TEMP%\krinik_music_player_obj
if not exist "%OBJ%" mkdir "%OBJ%"
cl /nologo /O2 /W3 /MT /utf-8 /D_CRT_SECURE_NO_WARNINGS /DUNICODE /D_UNICODE /Brepro ^
   /Fo"%OBJ%\\" "%HERE%src\krinik_music_player.c" ^
   /link /SUBSYSTEM:WINDOWS /Brepro /OUT:"%HERE%krinik_music_player.exe" user32.lib shell32.lib ole32.lib
if errorlevel 1 ( echo BUILD FAILED & exit /b 1 )
echo built %HERE%krinik_music_player.exe
endlocal
