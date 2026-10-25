@echo off
setlocal
set "PATH=C:\Program Files (x86)\Microsoft Visual Studio\Installer;C:\Windows\System32;C:\Windows\System32\WindowsPowerShell\v1.0;%PATH%"
set VCVARS=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat
if not exist "%VCVARS%" set VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat
if not exist "%VCVARS%" (echo MSVC vcvars64.bat not found & exit /b 1)
call "%VCVARS%" >nul || (echo vcvars64 failed & exit /b 1)

cd /d "%~dp0"
if not exist build mkdir build

cl /nologo /O2 /MT /W3 src\hider.c  /LD /Fo:build\ /Fe:build\hider.dll  /link user32.lib kernel32.lib || exit /b 1
cl /nologo /O2 /MT /W3 src\inject.c      /Fo:build\ /Fe:build\inject.exe /link /SUBSYSTEM:WINDOWS /ENTRY:wmainCRTStartup user32.lib kernel32.lib advapi32.lib || exit /b 1

del /q build\*.obj build\*.exp build\*.lib >nul 2>&1
dir /b build\hider.dll build\inject.exe
