# HideClaude

Excludes the Claude Desktop window from Windows screen-capture APIs so it
is invisible to Discord screen share, OBS, Teams, Snipping Tool and
`Win+G`. The user keeps seeing the window normally; any capture of that
monitor or window renders a black rectangle where Claude is.

## Why injection

`SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE)` only works
when called from the thread that owns `hwnd`. Calling it on another
process's window returns `ERROR_ACCESS_DENIED`, even from an elevated
process. Claude Desktop ships as an MSIX from the Microsoft Store, so
there is no way to patch its binary; the only option is to run the call
inside its process.

`hider.dll` does exactly that: once loaded into `claude.exe`, it polls
its own top-level windows and sets `WDA_EXCLUDEFROMCAPTURE` on each one.
`inject.exe` is a tiny watcher that scans for `claude.exe` and loads
`hider.dll` into every instance via `CreateRemoteThread(LoadLibraryW)`.
Admin rights are required to open an MSIX process for injection, so the
watcher is wired up as a scheduled task with `HighestAvailable` run
level that starts at logon.

Requires Windows 10 build 19041 (2004) or later — that is when
`WDA_EXCLUDEFROMCAPTURE` was introduced.

## Build

Visual Studio 2022 (Community or Build Tools) with the C++ workload.
From a normal cmd prompt:

```
build.cmd
```

Outputs `build\inject.exe` and `build\hider.dll`.

## Install

```
install.cmd
```

UAC prompts once. The script closes Claude (so `hider.dll` from a prior
install releases), copies `inject.exe` + `hider.dll` to
`%LOCALAPPDATA%\HideClaude`, registers a scheduled task named
`HideClaude` that runs the watcher at logon with the highest available
privileges, and starts it. Launch Claude again; within ~2 seconds its
window drops out of every capture.

Check:

```
schtasks /Query /TN HideClaude /V /FO LIST
```

## Uninstall

```
uninstall.cmd
```

Already-running `claude.exe` instances keep `hider.dll` resident until
they are restarted. The next launch is clean.

## Targeting other apps

`inject.exe` accepts a list of process names:

```
inject.exe hider.dll claude.exe cursor.exe
```

Edit the `<Arguments>` line in `install.cmd` (or the generated task XML)
to pass more names.

## Limits

- Hardware HDMI capture cards and anything that scrapes outside DWM
  (older XSplit modes, specific VNC servers) ignore
  `WDA_EXCLUDEFROMCAPTURE`. Software capture — Discord, OBS, Teams,
  Snipping Tool, Win+G, Windows Graphics Capture — honors it.
- If Microsoft tightens AppContainer isolation on Claude's MSIX in a
  future release, remote injection may be blocked. Right now the
  package is full-trust and injection works.
