#include <windows.h>

#ifndef WDA_EXCLUDEFROMCAPTURE
#define WDA_EXCLUDEFROMCAPTURE 0x00000011
#endif

static DWORD g_pid;

static BOOL CALLBACK enum_cb(HWND hwnd, LPARAM lp)
{
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid != g_pid || !IsWindowVisible(hwnd)) return TRUE;

    DWORD cur = 0;
    GetWindowDisplayAffinity(hwnd, &cur);
    if (cur != WDA_EXCLUDEFROMCAPTURE)
        SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE);
    return TRUE;
}

static DWORD WINAPI worker(LPVOID p)
{
    g_pid = GetCurrentProcessId();
    for (;;) {
        EnumWindows(enum_cb, 0);
        Sleep(1200);
    }
}

BOOL WINAPI DllMain(HINSTANCE h, DWORD reason, LPVOID r)
{
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(h);
        HANDLE t = CreateThread(NULL, 0, worker, NULL, 0, NULL);
        if (t) CloseHandle(t);
    }
    return TRUE;
}
