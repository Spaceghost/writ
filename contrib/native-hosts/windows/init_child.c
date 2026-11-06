/* Fixed no-data child. The controlled launcher provides only a report pipe. */
#define _WIN32_WINNT 0x0A00
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <windows.h>
#include <stdint.h>
#include <errno.h>
#include <stdlib.h>
#include <wchar.h>
#include "init_report.h"

static uint32_t loaded_modules(void)
{
    return (GetModuleHandleW(L"user32.dll") ? 1u : 0u) |
        (GetModuleHandleW(L"ole32.dll") ? 2u : 0u);
}

static DWORD load_error(const wchar_t *name, uint32_t *failures, uint32_t bit,
    uint32_t *cleanup_failures, uint32_t cleanup_bit)
{
    HMODULE library = LoadLibraryExW(name, NULL, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!library) {
        DWORD error = GetLastError();
        *failures |= bit;
        return error;
    }
    if (!FreeLibrary(library)) *cleanup_failures |= cleanup_bit;
    return ERROR_SUCCESS;
}

int wmain(int argc, wchar_t **argv)
{
    wchar_t *end = NULL;
    unsigned long long value;
    if (argc != 2 || !argv[1][0]) return 2;
    for (const wchar_t *p = argv[1]; *p; ++p) if (*p < L'0' || *p > L'9') return 2;
    errno = 0;
    value = _wcstoui64(argv[1], &end, 10);
    if (errno == ERANGE || !end || *end || !value || (unsigned long long)(ULONG_PTR)value != value) return 2;
    HANDLE output = (HANDLE)(ULONG_PTR)value;
    if (GetFileType(output) != FILE_TYPE_PIPE) return 2;
    WRIT_INIT_REPORT report = {0};
    report.magic = WRIT_INIT_MAGIC;
    report.version = WRIT_INIT_VERSION;
    report.size = sizeof(report);
    report.initial_modules = loaded_modules();
    WSADATA data;
    int result = WSAStartup(MAKEWORD(2, 2), &data);
    report.winsock = (uint32_t)result;
    if (!result && WSACleanup() != 0) report.cleanup_failures |= 1;
    report.after_winsock_modules = loaded_modules();
    report.user32 = load_error(L"user32.dll", &report.load_failures, 1, &report.cleanup_failures, 2);
    report.pre_ole32_modules = loaded_modules();
    report.ole32 = load_error(L"ole32.dll", &report.load_failures, 2, &report.cleanup_failures, 4);
    DWORD written = 0;
    BOOL ok = WriteFile(output, &report, sizeof(report), &written, NULL) && written == sizeof(report);
    if (!CloseHandle(output)) ok = FALSE;
    return ok ? 0 : 1;
}
