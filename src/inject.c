#include <windows.h>
#include <tlhelp32.h>
#include <wchar.h>

#define MAX_TARGETS   16
#define MAX_INJECTED  1024

static wchar_t  g_dll[MAX_PATH];
static wchar_t *g_targets[MAX_TARGETS];
static int      g_targetCount;
static DWORD    g_injected[MAX_INJECTED];
static int      g_injectedCount;

static int already_injected(DWORD pid)
{
    for (int i = 0; i < g_injectedCount; i++)
        if (g_injected[i] == pid) return 1;
    return 0;
}

static int is_target(const wchar_t *name)
{
    for (int i = 0; i < g_targetCount; i++)
        if (_wcsicmp(name, g_targets[i]) == 0) return 1;
    return 0;
}

static void enable_debug_priv(void)
{
    HANDLE t;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, &t)) return;
    TOKEN_PRIVILEGES tp = { .PrivilegeCount = 1 };
    tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    if (LookupPrivilegeValueW(NULL, L"SeDebugPrivilege", &tp.Privileges[0].Luid))
        AdjustTokenPrivileges(t, FALSE, &tp, 0, NULL, NULL);
    CloseHandle(t);
}

static int inject_pid(DWORD pid)
{
    HANDLE p = OpenProcess(
        PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION |
        PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ,
        FALSE, pid);
    if (!p) return 0;

    SIZE_T bytes = (wcslen(g_dll) + 1) * sizeof(wchar_t);
    LPVOID remote = VirtualAllocEx(p, NULL, bytes, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (!remote) { CloseHandle(p); return 0; }

    if (!WriteProcessMemory(p, remote, g_dll, bytes, NULL)) {
        VirtualFreeEx(p, remote, 0, MEM_RELEASE); CloseHandle(p); return 0;
    }

    LPTHREAD_START_ROUTINE loader = (LPTHREAD_START_ROUTINE)
        GetProcAddress(GetModuleHandleW(L"kernel32.dll"), "LoadLibraryW");
    if (!loader) { VirtualFreeEx(p, remote, 0, MEM_RELEASE); CloseHandle(p); return 0; }

    HANDLE th = CreateRemoteThread(p, NULL, 0, loader, remote, 0, NULL);
    if (!th) { VirtualFreeEx(p, remote, 0, MEM_RELEASE); CloseHandle(p); return 0; }

    WaitForSingleObject(th, 5000);
    CloseHandle(th);
    VirtualFreeEx(p, remote, 0, MEM_RELEASE);
    CloseHandle(p);
    return 1;
}

static void sweep(void)
{
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;

    PROCESSENTRY32W pe = { .dwSize = sizeof(pe) };
    if (Process32FirstW(snap, &pe)) {
        do {
            if (is_target(pe.szExeFile) && !already_injected(pe.th32ProcessID)) {
                if (inject_pid(pe.th32ProcessID) && g_injectedCount < MAX_INJECTED)
                    g_injected[g_injectedCount++] = pe.th32ProcessID;
            }
        } while (Process32NextW(snap, &pe));
    }
    CloseHandle(snap);

    int w = 0;
    for (int i = 0; i < g_injectedCount; i++) {
        HANDLE h = OpenProcess(SYNCHRONIZE, FALSE, g_injected[i]);
        if (h) {
            if (WaitForSingleObject(h, 0) == WAIT_TIMEOUT)
                g_injected[w++] = g_injected[i];
            CloseHandle(h);
        }
    }
    g_injectedCount = w;
}

int wmain(int argc, wchar_t **argv)
{
    if (argc < 2) {
        MessageBoxW(NULL, L"Usage: inject.exe <hider.dll> [proc1.exe ...]", L"inject", MB_OK);
        return 1;
    }
    if (!GetFullPathNameW(argv[1], MAX_PATH, g_dll, NULL) ||
        GetFileAttributesW(g_dll) == INVALID_FILE_ATTRIBUTES) {
        MessageBoxW(NULL, L"DLL not found", L"inject", MB_OK);
        return 1;
    }

    if (argc > 2) {
        for (int i = 2; i < argc && g_targetCount < MAX_TARGETS; i++)
            g_targets[g_targetCount++] = argv[i];
    } else {
        static wchar_t def[] = L"claude.exe";
        g_targets[g_targetCount++] = def;
    }

    enable_debug_priv();

    CreateMutexW(NULL, TRUE, L"Global\\HideClaude_inject_v1");
    if (GetLastError() == ERROR_ALREADY_EXISTS) return 0;

    for (;;) {
        sweep();
        Sleep(2000);
    }
}
