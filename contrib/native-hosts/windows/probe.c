/* Fixed native negative-test probe. It has no policy or authority constructor. */
#define _WIN32_WINNT 0x0A00
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <bcrypt.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <strsafe.h>
#include "probe.h"
#include "isolation.h"
#include "channels.h"

static void record(WRIT_PROBE_REPORT *report, unsigned int bit, BOOL success, DWORD error)
{
    unsigned int index = 0, copy = bit;
    while (copy > 1) { copy >>= 1; ++index; }
    if (index >= ARRAYSIZE(report->errors)) ExitProcess(90);
    report->errors[index] = error;
    if (success) report->passed |= bit; else report->failed |= bit;
}

static BOOL report_to_broker(HANDLE output, HANDLE ready, HANDLE proceed,
    WRIT_PROBE_REPORT *report, BOOL wait)
{
    DWORD written = 0;
    if (!WriteFile(output, report, sizeof(*report), &written, NULL) || written != sizeof(*report) ||
        !SetEvent(ready)) return FALSE;
    return !wait || WaitForSingleObject(proceed, 60000) == WAIT_OBJECT_0;
}

static BOOL sha256_matches(const BYTE *bytes, DWORD count, const wchar_t *expected)
{
    BCRYPT_ALG_HANDLE algorithm = NULL;
    BCRYPT_HASH_HANDLE hash = NULL;
    BYTE digest[32];
    BOOL ok = FALSE;
    static const wchar_t hex[] = L"0123456789abcdef";
    if (wcslen(expected) != 64 ||
        BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, NULL, 0) < 0 ||
        BCryptCreateHash(algorithm, &hash, NULL, 0, NULL, 0, 0) < 0 ||
        BCryptHashData(hash, (PUCHAR)bytes, count, 0) < 0 ||
        BCryptFinishHash(hash, digest, sizeof(digest), 0) < 0) goto done;
    ok = TRUE;
    for (unsigned int i = 0; i < 32; ++i)
        if (expected[2 * i] != hex[digest[i] >> 4] || expected[2 * i + 1] != hex[digest[i] & 15]) ok = FALSE;
done:
    if (hash) BCryptDestroyHash(hash);
    if (algorithm) BCryptCloseAlgorithmProvider(algorithm, 0);
    return ok;
}

static BOOL network_denied(int family, int type, unsigned short port, DWORD *error)
{
    SOCKET socket_handle = socket(family, type, type == SOCK_STREAM ? IPPROTO_TCP : IPPROTO_UDP);
    if (socket_handle == INVALID_SOCKET) { *error = WSAGetLastError(); return *error == WSAEACCES; }
    SOCKADDR_STORAGE destination;
    int length;
    ZeroMemory(&destination, sizeof(destination));
    if (family == AF_INET) {
        SOCKADDR_IN *address = (SOCKADDR_IN *)&destination;
        address->sin_family = AF_INET; address->sin_port = htons(port);
        address->sin_addr.s_addr = htonl(INADDR_LOOPBACK); length = sizeof(*address);
    } else {
        SOCKADDR_IN6 *address = (SOCKADDR_IN6 *)&destination;
        address->sin6_family = AF_INET6; address->sin6_port = htons(port);
        address->sin6_addr = in6addr_loopback; length = sizeof(*address);
    }
    static const char canary[] = "writ-public-egress-canary";
    int result;
    u_long nonblocking = 1;
    if (ioctlsocket(socket_handle, FIONBIO, &nonblocking) == SOCKET_ERROR) {
        *error = WSAGetLastError(); closesocket(socket_handle); return FALSE;
    }
    if (type == SOCK_DGRAM) {
        result = sendto(socket_handle, canary, sizeof(canary), 0, (SOCKADDR *)&destination, length);
        *error = result == SOCKET_ERROR ? WSAGetLastError() : 0;
    } else {
        result = connect(socket_handle, (SOCKADDR *)&destination, length);
        *error = result == SOCKET_ERROR ? WSAGetLastError() : 0;
        if (*error == WSAEWOULDBLOCK || *error == WSAEINPROGRESS) {
            fd_set writable, exceptional;
            TIMEVAL timeout = { 2, 0 };
            FD_ZERO(&writable); FD_ZERO(&exceptional);
            FD_SET(socket_handle, &writable); FD_SET(socket_handle, &exceptional);
            result = select(0, NULL, &writable, &exceptional, &timeout);
            if (result > 0) {
                int value = 0, size = sizeof(value);
                if (!getsockopt(socket_handle, SOL_SOCKET, SO_ERROR, (char *)&value, &size)) *error = (DWORD)value;
                else *error = WSAGetLastError();
            } else *error = result == 0 ? WSAETIMEDOUT : WSAGetLastError();
        }
        if (!*error) send(socket_handle, canary, sizeof(canary), 0);
    }
    closesocket(socket_handle);
    return *error == WSAEACCES;
}

static void network_checks(WRIT_PROBE_REPORT *report, unsigned short *ports)
{
    WSADATA data;
    int initialized = WSAStartup(MAKEWORD(2,2), &data);
    const int families[4] = { AF_INET, AF_INET6, AF_INET, AF_INET6 };
    const int types[4] = { SOCK_STREAM, SOCK_STREAM, SOCK_DGRAM, SOCK_DGRAM };
    const unsigned int bits[4] = { WRIT_PROBE_TCP4, WRIT_PROBE_TCP6, WRIT_PROBE_UDP4, WRIT_PROBE_UDP6 };
    for (unsigned int i = 0; i < 4; ++i) {
        DWORD error = (DWORD)initialized;
        BOOL denied = initialized == 0 && network_denied(families[i], types[i], ports[i], &error);
        record(report, bits[i], denied, error);
    }
    if (!initialized) WSACleanup();
}

static void child_check(WRIT_PROBE_REPORT *report, BOOL positive)
{
    wchar_t image[32768], command[32768];
    STARTUPINFOW startup = {0};
    PROCESS_INFORMATION child = {0};
    startup.cb = sizeof(startup);
    DWORD length = GetModuleFileNameW(NULL, image, ARRAYSIZE(image)), error = ERROR_INVALID_PARAMETER;
    BOOL success = FALSE;
    if (!length || length >= ARRAYSIZE(image) ||
        FAILED(StringCchPrintfW(command, ARRAYSIZE(command), L"\"%s\" --exit", image))) goto done;
    BOOL created = CreateProcessW(image, command, NULL, NULL, FALSE,
        DETACHED_PROCESS | CREATE_SUSPENDED, NULL, NULL, &startup, &child);
    error = created ? ERROR_SUCCESS : GetLastError();
    if (!created) {
        success = !positive && (error == ERROR_ACCESS_DENIED || error == ERROR_CHILD_PROCESS_BLOCKED);
        goto done;
    }
    if (positive) {
        DWORD exit_code = 1;
        success = ResumeThread(child.hThread) != (DWORD)-1 &&
            WaitForSingleObject(child.hProcess, 10000) == WAIT_OBJECT_0 &&
            GetExitCodeProcess(child.hProcess, &exit_code) && exit_code == 0;
        error = success ? ERROR_SUCCESS : (exit_code ? exit_code : GetLastError());
    }
    TerminateProcess(child.hProcess, ERROR_OPERATION_ABORTED);
    WaitForSingleObject(child.hProcess, 5000);
    CloseHandle(child.hThread); CloseHandle(child.hProcess);
done:
    record(report, WRIT_PROBE_CHILD, success, error);
}

static int positive_channels(HANDLE output)
{
    WRIT_PROBE_REPORT report = {0};
    report.magic = WRIT_PROBE_MAGIC; report.phase = 4;
    child_check(&report, TRUE);
    WRIT_CHANNEL_RESULT clipboard = writ_clipboard_attempt();
    WRIT_CHANNEL_RESULT com = writ_com_attempt();
    report.clipboard_stage = clipboard.stage; report.com_stage = com.stage;
    record(&report, WRIT_PROBE_CLIPBOARD, clipboard.stage == 4 && clipboard.result == S_OK, (DWORD)clipboard.result);
    record(&report, WRIT_PROBE_COM, com.stage == 4 && com.result == S_OK, (DWORD)com.result);
    DWORD written = 0;
    BOOL sent = WriteFile(output, &report, sizeof(report), &written, NULL) && written == sizeof(report);
    CloseHandle(output);
    return sent && !report.failed && report.passed == WRIT_PROBE_POSITIVE_MASK ? 0 : 87;
}

static int diagnostic_channels(HANDLE output, unsigned short ports[4])
{
    /* This entry point has no mount/input parameter and never opens a data
       object. It only exercises the fixed no-data diagnostic API surface. */
    WRIT_PROBE_REPORT report = {0};
    report.magic = WRIT_PROBE_MAGIC; report.phase = 5;
    network_checks(&report, ports);
    child_check(&report, FALSE);
    WRIT_CHANNEL_RESULT clipboard = writ_clipboard_attempt();
    WRIT_CHANNEL_RESULT com = writ_com_attempt();
    report.clipboard_stage = clipboard.stage; report.com_stage = com.stage;
    record(&report, WRIT_PROBE_CLIPBOARD, writ_clipboard_denied(clipboard), (DWORD)clipboard.result);
    record(&report, WRIT_PROBE_COM, writ_com_denied(com), (DWORD)com.result);
    DWORD written = 0;
    BOOL sent = WriteFile(output, &report, sizeof(report), &written, NULL) && written == sizeof(report);
    CloseHandle(output);
    return sent && !report.failed && report.passed == WRIT_PROBE_DIAGNOSTIC_MASK ? 0 : 88;
}

static void confinement_checks(WRIT_PROBE_REPORT *report, const wchar_t *public_path, DWORD broker_pid)
{
    DWORD error;
    HANDLE file = CreateFileW(public_path, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    error = file == INVALID_HANDLE_VALUE ? GetLastError() : 0;
    if (file != INVALID_HANDLE_VALUE) {
        static const char canary[] = "writ-public-egress-canary";
        DWORD written;
        WriteFile(file, canary, sizeof(canary), &written, NULL);
        CloseHandle(file);
    }
    record(report, WRIT_PROBE_PUBLIC_FILE, file == INVALID_HANDLE_VALUE && error == ERROR_ACCESS_DENIED, error);

    child_check(report, FALSE);

    HANDLE console = CreateFileW(L"CONOUT$", GENERIC_WRITE, FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
    error = console == INVALID_HANDLE_VALUE ? GetLastError() : 0;
    BOOL no_standard = (!GetStdHandle(STD_OUTPUT_HANDLE) || GetStdHandle(STD_OUTPUT_HANDLE) == INVALID_HANDLE_VALUE) &&
        (!GetStdHandle(STD_ERROR_HANDLE) || GetStdHandle(STD_ERROR_HANDLE) == INVALID_HANDLE_VALUE);
    if (console != INVALID_HANDLE_VALUE) CloseHandle(console);
    record(report, WRIT_PROBE_CONSOLE, no_standard && console == INVALID_HANDLE_VALUE, error);

    HANDLE broker = OpenProcess(PROCESS_VM_READ | PROCESS_DUP_HANDLE | WRITE_DAC, FALSE, broker_pid);
    error = broker ? 0 : GetLastError();
    if (broker) CloseHandle(broker);
    record(report, WRIT_PROBE_BROKER, !broker && error == ERROR_ACCESS_DENIED, error);

    WRIT_CHANNEL_RESULT clipboard = writ_clipboard_attempt();
    WRIT_CHANNEL_RESULT com = writ_com_attempt();
    report->clipboard_stage = clipboard.stage; report->com_stage = com.stage;
    record(report, WRIT_PROBE_CLIPBOARD, writ_clipboard_denied(clipboard), (DWORD)clipboard.result);
    record(report, WRIT_PROBE_COM, writ_com_denied(com), (DWORD)com.result);
}

int wmain(int argc, wchar_t **argv)
{
    if (argc == 2 && !wcscmp(argv[1], L"--exit")) return 0;
    if (argc == 3 && !wcscmp(argv[1], L"--positive"))
        return positive_channels((HANDLE)(uintptr_t)_wcstoui64(argv[2], NULL, 10));
    if (argc == 7 && !wcscmp(argv[1], L"--lpac-diagnostic")) {
        unsigned short ports[4];
        for (int i = 0; i < 4; ++i) {
            wchar_t *end = NULL;
            unsigned long port = wcstoul(argv[3+i], &end, 10);
            if (!port || port > 65535 || !end || *end) return 89;
            ports[i] = (unsigned short)port;
        }
        return diagnostic_channels((HANDLE)(uintptr_t)_wcstoui64(argv[2], NULL, 10), ports);
    }
    if (argc > 1 && !wcscmp(argv[1], L"--outsider")) return writ_outsider_probe(argc, argv);
    if (argc != 14) return 80;
    const wchar_t *mount = argv[1], *expected_hash = argv[2];
    DWORD expected_size = wcstoul(argv[3], NULL, 10);
    HANDLE report_pipe = (HANDLE)(uintptr_t)_wcstoui64(argv[4], NULL, 10);
    HANDLE ready = (HANDLE)(uintptr_t)_wcstoui64(argv[5], NULL, 10);
    HANDLE proceed = (HANDLE)(uintptr_t)_wcstoui64(argv[6], NULL, 10);
    BOOL lpac = !wcscmp(argv[7], L"lpac");
    DWORD broker_pid = wcstoul(argv[8], NULL, 10);
    const wchar_t *public_path = argv[9];
    unsigned short ports[4];
    for (int i = 0; i < 4; ++i) ports[i] = (unsigned short)wcstoul(argv[10+i], NULL, 10);
    if (expected_size > 65536) return 81;
    wchar_t path[32768], wildcard[32768], alternate[32768];
    if (FAILED(StringCchPrintfW(path, ARRAYSIZE(path), L"%s\\data", mount)) ||
        FAILED(StringCchPrintfW(wildcard, ARRAYSIZE(wildcard), L"%s\\*", mount))) return 82;
    WRIT_PROBE_REPORT report = {0};
    report.magic = WRIT_PROBE_MAGIC; report.phase = 1;
    BYTE *bytes = _aligned_malloc(65536, 4096);
    if (!bytes) return 83;
    HANDLE file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
        FILE_FLAG_NO_BUFFERING, NULL);
    DWORD got = 0, error = file == INVALID_HANDLE_VALUE ? GetLastError() : 0;
    BOOL read_ok = file != INVALID_HANDLE_VALUE && ReadFile(file, bytes, 65536, &got, NULL);
    if (!read_ok && !error) error = GetLastError();
    if (!expected_size && file != INVALID_HANDLE_VALUE && error == ERROR_HANDLE_EOF) {
        read_ok = TRUE; got = 0;
    }
    record(&report, WRIT_PROBE_READ, read_ok && got == expected_size && sha256_matches(bytes, got, expected_hash), error);
    LARGE_INTEGER location;
    HANDLE range = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    BYTE range_bytes[17];
    location.QuadPart = expected_size > 4 ? 4 : expected_size;
    got = 0;
    BOOL range_ok = range != INVALID_HANDLE_VALUE && SetFilePointerEx(range, location, NULL, FILE_BEGIN) &&
        ReadFile(range, range_bytes, sizeof(range_bytes), &got, NULL);
    error = range_ok ? 0 : GetLastError();
    DWORD remaining = expected_size - (DWORD)location.QuadPart;
    DWORD wanted = remaining < sizeof(range_bytes) ? remaining : sizeof(range_bytes);
    if (!wanted && range != INVALID_HANDLE_VALUE && error == ERROR_HANDLE_EOF) {
        range_ok = TRUE; got = 0;
    }
    record(&report, WRIT_PROBE_RANGE, read_ok && range_ok && got == wanted &&
        !memcmp(range_bytes, bytes + (DWORD)location.QuadPart, got), error);
    if (range != INVALID_HANDLE_VALUE) CloseHandle(range);

    /* Compare the range before reusing the full-file buffer for the EOF probe. */
    location.QuadPart = 65536;
    got = 99;
    BOOL eof = file != INVALID_HANDLE_VALUE && SetFilePointerEx(file, location, NULL, FILE_BEGIN) &&
        ReadFile(file, bytes, 4096, &got, NULL);
    error = eof ? 0 : GetLastError();
    record(&report, WRIT_PROBE_EOF, (eof && got == 0) || error == ERROR_HANDLE_EOF, error);

    WIN32_FIND_DATAW entry;
    HANDLE enumeration = FindFirstFileW(wildcard, &entry);
    DWORD entries = 0;
    BOOL names_ok = TRUE;
    error = enumeration == INVALID_HANDLE_VALUE ? GetLastError() : 0;
    if (enumeration != INVALID_HANDLE_VALUE) {
        do { if (wcscmp(entry.cFileName, L".") && wcscmp(entry.cFileName, L"..")) {
            ++entries; if (wcscmp(entry.cFileName, L"data")) names_ok = FALSE;
        }} while (FindNextFileW(enumeration, &entry));
        if (GetLastError() != ERROR_NO_MORE_FILES) names_ok = FALSE;
        FindClose(enumeration);
    }
    record(&report, WRIT_PROBE_DIRECTORY, enumeration != INVALID_HANDLE_VALUE && entries == 1 && names_ok, error);
    HANDLE forbidden = CreateFileW(path, GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    error = forbidden == INVALID_HANDLE_VALUE ? GetLastError() : 0;
    if (forbidden != INVALID_HANDLE_VALUE) CloseHandle(forbidden);
    record(&report, WRIT_PROBE_WRITE, forbidden == INVALID_HANDLE_VALUE &&
        (error == ERROR_ACCESS_DENIED || error == ERROR_WRITE_PROTECT), error);
    StringCchPrintfW(alternate, ARRAYSIZE(alternate), L"%s:other", path);
    forbidden = CreateFileW(alternate, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    error = forbidden == INVALID_HANDLE_VALUE ? GetLastError() : 0;
    if (forbidden != INVALID_HANDLE_VALUE) CloseHandle(forbidden);
    record(&report, WRIT_PROBE_STREAM, forbidden == INVALID_HANDLE_VALUE, error);
    StringCchPrintfW(alternate, ARRAYSIZE(alternate), L"%s\\new", mount);
    forbidden = CreateFileW(alternate, GENERIC_WRITE, 0, NULL, CREATE_NEW, 0, NULL);
    error = forbidden == INVALID_HANDLE_VALUE ? GetLastError() : 0;
    if (forbidden != INVALID_HANDLE_VALUE) CloseHandle(forbidden);
    record(&report, WRIT_PROBE_NEW_FILE, forbidden == INVALID_HANDLE_VALUE, error);
    if (lpac) { network_checks(&report, ports); confinement_checks(&report, public_path, broker_pid); }
    if (!report_to_broker(report_pipe, ready, proceed, &report, TRUE)) return 84;

    ZeroMemory(&report, sizeof(report)); report.magic = WRIT_PROBE_MAGIC; report.phase = 2;
    if (lpac) network_checks(&report, ports);
    if (!report_to_broker(report_pipe, ready, proceed, &report, TRUE)) return 85;

    ZeroMemory(&report, sizeof(report)); report.magic = WRIT_PROBE_MAGIC; report.phase = 3;
    forbidden = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    error = forbidden == INVALID_HANDLE_VALUE ? GetLastError() : 0;
    if (forbidden != INVALID_HANDLE_VALUE) CloseHandle(forbidden);
    record(&report, WRIT_PROBE_REVOKED_OPEN, forbidden == INVALID_HANDLE_VALUE && error == ERROR_ACCESS_DENIED, error);
    location.QuadPart = 0;
    got = 0;
    BOOL subsequent = file != INVALID_HANDLE_VALUE && SetFilePointerEx(file, location, NULL, FILE_BEGIN) &&
        ReadFile(file, bytes, 4096, &got, NULL);
    error = subsequent ? 0 : GetLastError();
    record(&report, WRIT_PROBE_REVOKED_READ, !subsequent && error == ERROR_ACCESS_DENIED, error);
    if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
    SecureZeroMemory(bytes, 65536); _aligned_free(bytes);
    BOOL reported = report_to_broker(report_pipe, ready, proceed, &report, FALSE);
    CloseHandle(report_pipe); CloseHandle(ready); CloseHandle(proceed);
    return reported && !report.failed ? 0 : 86;
}
