#ifdef _WIN32

#include "console.h"

#include <windows.h>
#include <stdbool.h>
#include <Psapi.h>
#include <tlhelp32.h>

DWORD getParentPID(DWORD pid)
{
    HANDLE handle = NULL;
    PROCESSENTRY32 entry = { 0 };
    DWORD parent_pid = 0;
    entry.dwSize = sizeof(PROCESSENTRY32);
    handle = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (Process32First(handle, &entry)) {
        do {
            if (entry.th32ProcessID == pid) {
                parent_pid = entry.th32ParentProcessID;
                break;
            }
        } while (Process32Next(handle, &entry));
    }
    CloseHandle(handle);
    return (parent_pid);
}

int getProcessName(DWORD pid, char* fname, DWORD size)
{
    HANDLE handle = NULL;
    handle = OpenProcess(
        PROCESS_QUERY_INFORMATION | PROCESS_VM_READ,
        FALSE,
        pid
    );
    if (handle) {
        GetModuleBaseNameA(handle, NULL, fname, size);
        CloseHandle(handle);
    }
}

int getCurrentProcessName(char* fname, DWORD size) {
    DWORD pid, parent_pid;
    pid = GetCurrentProcessId();
    parent_pid = getParentPID(pid);
    return getProcessName(parent_pid, fname, size);
}

void hideConsoleIfNotNeeded() {
    char fname[MAX_PATH] = { 0 };
    getCurrentProcessName(fname, MAX_PATH);
    
    if (strncasecmp(fname, "cmd.exe", MAX_PATH) && strncasecmp(fname, "powershell.exe", MAX_PATH)) {
        // We are not launched from cmd or powershell, going to hide console window...
        ShowWindow(GetConsoleWindow(), SW_HIDE);
    }

    return;
}

#endif