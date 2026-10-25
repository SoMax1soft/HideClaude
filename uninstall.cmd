@echo off
%SystemRoot%\System32\fltmc.exe >nul 2>&1
if errorlevel 1 (
    %SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
setlocal
set TK=%SystemRoot%\System32\taskkill.exe
set SC=%SystemRoot%\System32\schtasks.exe
"%SC%" /End /TN "HideClaude" >nul 2>&1
"%SC%" /Delete /TN "HideClaude" /F >nul 2>&1
"%TK%" /IM inject.exe /F >nul 2>&1
rmdir /S /Q "%LOCALAPPDATA%\HideClaude" >nul 2>&1
echo Uninstalled. Already-injected claude.exe keeps hider.dll loaded until restart.
pause
