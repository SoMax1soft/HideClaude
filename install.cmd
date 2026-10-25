@echo off
%SystemRoot%\System32\fltmc.exe >nul 2>&1
if errorlevel 1 (
    %SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

setlocal
set REG=%SystemRoot%\System32\reg.exe
set TK=%SystemRoot%\System32\taskkill.exe
set SC=%SystemRoot%\System32\schtasks.exe

set SRC_EXE=%~dp0build\inject.exe
set SRC_DLL=%~dp0build\hider.dll
if not exist "%SRC_EXE%" (echo build\inject.exe missing - run build.cmd first & pause & exit /b 1)
if not exist "%SRC_DLL%" (echo build\hider.dll  missing - run build.cmd first & pause & exit /b 1)

set DST_DIR=%LOCALAPPDATA%\HideClaude
set DST_EXE=%DST_DIR%\inject.exe
set DST_DLL=%DST_DIR%\hider.dll
set XML=%DST_DIR%\HideClaude.xml
if not exist "%DST_DIR%" mkdir "%DST_DIR%"

"%SC%" /End /TN "HideClaude" >nul 2>&1
"%TK%" /IM inject.exe /F >nul 2>&1
echo Closing Claude so the loaded hider.dll releases...
"%TK%" /IM claude.exe /F >nul 2>&1
"%SystemRoot%\System32\timeout.exe" /T 2 /NOBREAK >nul 2>&1

copy /Y "%SRC_EXE%" "%DST_EXE%" >nul || (echo copy inject failed & pause & exit /b 1)
copy /Y "%SRC_DLL%" "%DST_DLL%" >nul || (echo copy hider failed - is Claude still open? & pause & exit /b 1)

> "%XML%" (
    echo ^<?xml version="1.0" encoding="UTF-16"?^>
    echo ^<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
    echo   ^<RegistrationInfo^>^<Description^>Inject hider.dll into claude.exe so it hides itself from screen capture.^</Description^>^</RegistrationInfo^>
    echo   ^<Triggers^>^<LogonTrigger^>^<Enabled^>true^</Enabled^>^<UserId^>%USERDOMAIN%\%USERNAME%^</UserId^>^</LogonTrigger^>^</Triggers^>
    echo   ^<Principals^>^<Principal id="Author"^>^<UserId^>%USERDOMAIN%\%USERNAME%^</UserId^>^<LogonType^>InteractiveToken^</LogonType^>^<RunLevel^>HighestAvailable^</RunLevel^>^</Principal^>^</Principals^>
    echo   ^<Settings^>
    echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
    echo     ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
    echo     ^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>
    echo     ^<AllowHardTerminate^>true^</AllowHardTerminate^>
    echo     ^<StartWhenAvailable^>true^</StartWhenAvailable^>
    echo     ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
    echo     ^<Enabled^>true^</Enabled^>
    echo     ^<Hidden^>false^</Hidden^>
    echo     ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
    echo     ^<Priority^>7^</Priority^>
    echo     ^<RestartOnFailure^>^<Interval^>PT1M^</Interval^>^<Count^>99^</Count^>^</RestartOnFailure^>
    echo   ^</Settings^>
    echo   ^<Actions Context="Author"^>^<Exec^>^<Command^>%DST_EXE%^</Command^>^<Arguments^>"%DST_DLL%" claude.exe^</Arguments^>^<WorkingDirectory^>%DST_DIR%^</WorkingDirectory^>^</Exec^>^</Actions^>
    echo ^</Task^>
)

"%SC%" /Delete /TN "HideClaude" /F >nul 2>&1
"%SC%" /Create /TN "HideClaude" /XML "%XML%" /F || (echo schtasks /Create failed & pause & exit /b 1)
"%SC%" /Run /TN "HideClaude" >nul

echo.
echo Installed. Start Claude again and the window will be excluded from screen capture.
echo.
pause
