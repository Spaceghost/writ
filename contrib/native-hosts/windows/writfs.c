/* Native WinFsp presentation for the bounded Bend public-canary profile. */
#define _WIN32_WINNT 0x0A00
#define WIN32_LEAN_AND_MEAN
#include <winfsp/winfsp.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <sddl.h>
#include <strsafe.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "policy_pipe.h"
#include "worker.h"
#include "probe.h"

typedef struct {
    DWORD actor, handle;
    BOOL root;
} WRIT_OPEN;

typedef struct {
    FSP_FILE_SYSTEM *filesystem;
    WRIT_POLICY_PIPE policy;
    WRIT_WORKER worker;
    CRITICAL_SECTION lock;
    BOOL lock_ready, failed;
    DWORD sequence, audit_count, byte_count;
    BYTE *bytes;
    PSECURITY_DESCRIPTOR security;
    DWORD security_size;
    UINT64 created;
    char digest[65];
} WRIT_HOST;

typedef struct { DWORD value; char detail[96]; BOOL allowed; } WRIT_REPLY;

static BOOL decimal(const char *text, DWORD *value)
{
    uint64_t n = 0;
    if (!*text || (text[0] == '0' && text[1])) return FALSE;
    for (const unsigned char *p = (const unsigned char *)text; *p; ++p) {
        if (*p < '0' || *p > '9') return FALSE;
        n = n * 10 + *p - '0';
        if (n > MAXDWORD) return FALSE;
    }
    *value = (DWORD)n;
    return TRUE;
}

static BOOL rpc_locked(WRIT_HOST *host, const char *operation, DWORD actor,
    DWORD handle, DWORD offset, DWORD count, const char *argument, WRIT_REPLY *reply)
{
    char *request = NULL, response[256], *fields[5];
    BOOL ok = FALSE;
    DWORD sequence;
    ZeroMemory(reply, sizeof(*reply));
    if (host->failed || host->sequence == MAXDWORD) goto done;
    size_t capacity = strlen(argument) + 128;
    if (capacity > WRIT_POLICY_FRAME_MAX) goto done;
    request = malloc(capacity);
    if (!request) goto done;
    int size = snprintf(request, capacity, "WRITFS1\t%s\t%lu\t%lu\t%lu\t%lu\t%s\n",
        operation, actor, handle, offset, count, argument);
    if (size < 0 || (size_t)size >= capacity ||
        !writ_policy_exchange(&host->policy, request, response, sizeof(response))) goto done;
    fields[0] = response;
    for (unsigned int i = 1; i < ARRAYSIZE(fields); ++i) {
        char *tab = strchr(fields[i-1], '\t');
        if (!tab) goto done;
        *tab = 0; fields[i] = tab + 1;
    }
    if (strchr(fields[4], '\t') || strcmp(fields[0], "WRITFS1") ||
        !decimal(fields[1], &sequence) || sequence != host->sequence + 1 ||
        !decimal(fields[3], &reply->value) || !*fields[4] || strlen(fields[4]) >= sizeof(reply->detail))
        goto done;
    for (const unsigned char *p = (const unsigned char *)fields[4]; *p; ++p)
        if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
            (*p >= '0' && *p <= '9') || *p == '-' || *p == '_')) goto done;
    if (strcmp(fields[2], "OK") && strcmp(fields[2], "DENY")) goto done;
    host->sequence = sequence;
    reply->allowed = !strcmp(fields[2], "OK");
    strcpy_s(reply->detail, sizeof(reply->detail), fields[4]);
    ok = TRUE;
done:
    free(request);
    if (!ok) host->failed = TRUE;
    return ok;
}

static BOOL rpc(WRIT_HOST *host, const char *operation, DWORD actor,
    DWORD handle, DWORD offset, DWORD count, const char *argument, WRIT_REPLY *reply)
{
    EnterCriticalSection(&host->lock);
    BOOL ok = rpc_locked(host, operation, actor, handle, offset, count, argument, reply);
    LeaveCriticalSection(&host->lock);
    return ok;
}

static BOOL audit(WRIT_HOST *host, const char *event, DWORD pid, DWORD actor, const WRIT_REPLY *reply)
{
    /* Fixed fields only. Object paths, worker text and plaintext are not log fields.
       This bounded fixture log is not a durable or administrator-resistant journal. */
    if (host->audit_count >= 1024 ||
        printf("EVENT n=%lu policy=%lu kind=%s pid=%lu actor=%lu result=%s reason=%s\n",
            ++host->audit_count, host->sequence, event, pid, actor,
            reply->allowed ? "allow" : "deny", reply->detail) < 0 || fflush(stdout)) {
        host->failed = TRUE; return FALSE;
    }
    return TRUE;
}

static DWORD native_actor(WRIT_HOST *host, DWORD *pid)
{
    FSP_FILE_SYSTEM_OPERATION_CONTEXT *context = FspFileSystemGetOperationContext();
    *pid = 0;
    if (!context || !context->Request || context->Request->Kind != FspFsctlTransactCreateKind)
        return 0;
    UINT64 evidence = context->Request->Req.Create.AccessToken;
    *pid = FSP_FSCTL_TRANSACT_REQ_TOKEN_PID(evidence);
    return writ_worker_matches(&host->worker, *pid, FSP_FSCTL_TRANSACT_REQ_TOKEN_HANDLE(evidence)) ? 1 : 0;
}

static const char *node_name(const wchar_t *name)
{
    if (!wcscmp(name, L"\\")) return "root";
    if (!wcscmp(name, L"\\data")) return "data";
    return NULL;
}

static void file_info(WRIT_HOST *host, BOOL root, FSP_FSCTL_FILE_INFO *information)
{
    ZeroMemory(information, sizeof(*information));
    information->FileAttributes = FILE_ATTRIBUTE_READONLY | (root ? FILE_ATTRIBUTE_DIRECTORY : 0);
    information->CreationTime = information->LastAccessTime = information->LastWriteTime =
        information->ChangeTime = host->created;
    information->IndexNumber = root ? 1 : 2;
    information->FileSize = root ? 0 : host->byte_count;
    information->AllocationSize = root ? 0 : ((host->byte_count + 4095u) & ~4095u);
    information->HardLinks = 0;
}

static NTSTATUS copy_security(WRIT_HOST *host, PSECURITY_DESCRIPTOR destination, SIZE_T *size)
{
    if (size) {
        SIZE_T capacity = *size;
        *size = host->security_size;
        if (capacity < host->security_size) return STATUS_BUFFER_OVERFLOW;
        if (destination) memcpy(destination, host->security, host->security_size);
    }
    return STATUS_SUCCESS;
}

static NTSTATUS get_volume_info(FSP_FILE_SYSTEM *filesystem, FSP_FSCTL_VOLUME_INFO *information)
{
    (void)filesystem;
    ZeroMemory(information, sizeof(*information));
    /* Fixed public structure, independent of payload length and policy state. */
    information->TotalSize = 65536;
    information->FreeSize = 0;
    information->VolumeLabelLength = sizeof(L"WRITFS1") - sizeof(wchar_t);
    memcpy(information->VolumeLabel, L"WRITFS1", information->VolumeLabelLength);
    return STATUS_SUCCESS;
}

static NTSTATUS get_security_by_name(FSP_FILE_SYSTEM *filesystem, PWSTR name, PUINT32 attributes,
    PSECURITY_DESCRIPTOR descriptor, SIZE_T *size)
{
    WRIT_HOST *host = filesystem->UserContext;
    WRIT_REPLY reply;
    DWORD pid;
    const char *node = node_name(name);
    EnterCriticalSection(&host->lock);
    DWORD actor = native_actor(host, &pid);
    /* Ask the shared model before disclosing even whether a path exists. */
    BOOL exchanged = rpc_locked(host, "STAT", actor, 0, 0, 0, node ? node : "data", &reply);
    NTSTATUS status = STATUS_ACCESS_DENIED;
    if (!exchanged) status = STATUS_IO_DEVICE_ERROR;
    else if (!audit(host, "stat", pid, actor, &reply)) status = STATUS_IO_DEVICE_ERROR;
    else if (reply.allowed) {
        if (!node) status = STATUS_OBJECT_NAME_NOT_FOUND;
        else if (reply.value != (!strcmp(node, "root") ? 0 : host->byte_count)) {
            host->failed = TRUE; status = STATUS_IO_DEVICE_ERROR;
        } else {
            if (attributes) *attributes = FILE_ATTRIBUTE_READONLY |
                (!strcmp(node, "root") ? FILE_ATTRIBUTE_DIRECTORY : 0);
            status = copy_security(host, descriptor, size);
        }
    }
    LeaveCriticalSection(&host->lock);
    return status;
}

static NTSTATUS open_file(FSP_FILE_SYSTEM *filesystem, PWSTR name, UINT32 options,
    UINT32 access, PVOID *context, FSP_FSCTL_FILE_INFO *information)
{
    WRIT_HOST *host = filesystem->UserContext;
    const char *node = node_name(name);
    DWORD denied_access = FILE_WRITE_DATA | FILE_APPEND_DATA | FILE_WRITE_EA | FILE_WRITE_ATTRIBUTES |
        DELETE | WRITE_DAC | WRITE_OWNER | FILE_DELETE_CHILD;
    if (!node) return STATUS_OBJECT_NAME_NOT_FOUND;
    if ((access & denied_access) || (options & FILE_DELETE_ON_CLOSE)) return STATUS_ACCESS_DENIED;
    BOOL root = !strcmp(node, "root");
    if ((root && (options & FILE_NON_DIRECTORY_FILE)) || (!root && (options & FILE_DIRECTORY_FILE)))
        return root ? STATUS_FILE_IS_A_DIRECTORY : STATUS_NOT_A_DIRECTORY;
    WRIT_OPEN *opened = calloc(1, sizeof(*opened));
    if (!opened) return STATUS_INSUFFICIENT_RESOURCES;
    WRIT_REPLY reply;
    DWORD pid;
    EnterCriticalSection(&host->lock);
    DWORD actor = native_actor(host, &pid);
    BOOL exchanged = rpc_locked(host, "OPEN", actor, 0, 0, 0, node, &reply);
    NTSTATUS status = STATUS_ACCESS_DENIED;
    if (!exchanged || !audit(host, "open", pid, actor, &reply)) status = STATUS_IO_DEVICE_ERROR;
    else if (reply.allowed && reply.value != 0) {
        opened->actor = actor; opened->handle = reply.value; opened->root = root;
        *context = opened; file_info(host, root, information); status = STATUS_SUCCESS;
    }
    LeaveCriticalSection(&host->lock);
    if (!NT_SUCCESS(status)) free(opened);
    return status;
}

static NTSTATUS read_file(FSP_FILE_SYSTEM *filesystem, PVOID context, PVOID buffer,
    UINT64 offset, ULONG length, PULONG transferred)
{
    WRIT_HOST *host = filesystem->UserContext;
    WRIT_OPEN *opened = context;
    *transferred = 0;
    if (!opened || offset > MAXDWORD) return STATUS_INVALID_PARAMETER;
    if (length > 65536) length = 65536;
    WRIT_REPLY reply;
    DWORD actor = writ_worker_alive(&host->worker) ? opened->actor : 0;
    EnterCriticalSection(&host->lock);
    BOOL exchanged = rpc_locked(host, "READ", actor, opened->handle, (DWORD)offset, length, "-", &reply);
    NTSTATUS status = STATUS_ACCESS_DENIED;
    if (!exchanged || !audit(host, "read-bound-open", host->worker.pid, actor, &reply)) status = STATUS_IO_DEVICE_ERROR;
    else if (reply.allowed) {
        if (reply.value > length || offset > host->byte_count || reply.value > host->byte_count - (DWORD)offset) {
            /* Beyond EOF may return a zero-byte success. Never narrow first. */
            if (reply.value == 0 && offset >= host->byte_count) status = STATUS_END_OF_FILE;
            else { host->failed = TRUE; status = STATUS_IO_DEVICE_ERROR; }
        } else if (!reply.value) status = STATUS_END_OF_FILE;
        else {
            memcpy(buffer, host->bytes + (DWORD)offset, reply.value);
            *transferred = reply.value; status = STATUS_SUCCESS;
        }
    }
    LeaveCriticalSection(&host->lock);
    return status;
}

static NTSTATUS get_file_info(FSP_FILE_SYSTEM *filesystem, PVOID context, FSP_FSCTL_FILE_INFO *information)
{
    WRIT_HOST *host = filesystem->UserContext;
    WRIT_OPEN *opened = context;
    if (!opened) return STATUS_INVALID_HANDLE;
    WRIT_REPLY reply;
    DWORD actor = writ_worker_alive(&host->worker) ? opened->actor : 0;
    if (!rpc(host, "STAT", actor, 0, 0, 0, opened->root ? "root" : "data", &reply)) return STATUS_IO_DEVICE_ERROR;
    if (!reply.allowed) return STATUS_ACCESS_DENIED;
    file_info(host, opened->root, information);
    return STATUS_SUCCESS;
}

static NTSTATUS get_security(FSP_FILE_SYSTEM *filesystem, PVOID context,
    PSECURITY_DESCRIPTOR descriptor, SIZE_T *size)
{
    FSP_FSCTL_FILE_INFO information;
    NTSTATUS status = get_file_info(filesystem, context, &information);
    return NT_SUCCESS(status) ? copy_security(filesystem->UserContext, descriptor, size) : status;
}

static NTSTATUS read_directory(FSP_FILE_SYSTEM *filesystem, PVOID context, PWSTR pattern,
    PWSTR marker, PVOID buffer, ULONG length, PULONG transferred)
{
    (void)pattern;
    WRIT_HOST *host = filesystem->UserContext;
    WRIT_OPEN *opened = context;
    *transferred = 0;
    if (!opened || !opened->root) return STATUS_NOT_A_DIRECTORY;
    WRIT_REPLY reply;
    DWORD actor = writ_worker_alive(&host->worker) ? opened->actor : 0;
    if (!rpc(host, "LIST", actor, 0, 0, 0, "root", &reply)) return STATUS_IO_DEVICE_ERROR;
    if (!reply.allowed || reply.value != 1) return STATUS_ACCESS_DENIED;
    if (!marker || wcscmp(marker, L"data") < 0) {
        union { UINT64 alignment; BYTE bytes[sizeof(FSP_FSCTL_DIR_INFO) + sizeof(L"data")]; } storage;
        FSP_FSCTL_DIR_INFO *entry = (FSP_FSCTL_DIR_INFO *)storage.bytes;
        ZeroMemory(&storage, sizeof(storage));
        entry->Size = (UINT16)(sizeof(FSP_FSCTL_DIR_INFO) + sizeof(L"data") - sizeof(wchar_t));
        file_info(host, FALSE, &entry->FileInfo);
        memcpy(entry->FileNameBuf, L"data", sizeof(L"data") - sizeof(wchar_t));
        if (!FspFileSystemAddDirInfo(entry, buffer, length, transferred)) return STATUS_SUCCESS;
    }
    FspFileSystemAddDirInfo(NULL, buffer, length, transferred);
    return STATUS_SUCCESS;
}

static void close_file(FSP_FILE_SYSTEM *filesystem, PVOID context)
{
    WRIT_HOST *host = filesystem->UserContext;
    WRIT_OPEN *opened = context;
    if (!opened) return;
    WRIT_REPLY reply;
    /* Cleanup uses the bound actor even after process exit or revocation. */
    if (!rpc(host, "CLOSE", opened->actor, opened->handle, 0, 0, "-", &reply) || !reply.allowed)
        host->failed = TRUE;
    free(opened);
}

static BOOL freeze_fixture(WRIT_HOST *host, const wchar_t *path)
{
    HANDLE file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
        FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_SEQUENTIAL_SCAN, NULL);
    BOOL ok = FALSE;
    if (file == INVALID_HANDLE_VALUE) return FALSE;
    BY_HANDLE_FILE_INFORMATION information;
    LARGE_INTEGER size;
    if (GetFileType(file) != FILE_TYPE_DISK || !GetFileInformationByHandle(file, &information) ||
        (information.dwFileAttributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY)) ||
        !GetFileSizeEx(file, &size) || size.QuadPart < 0 || size.QuadPart > 65536) goto done;
    host->byte_count = (DWORD)size.QuadPart;
    host->bytes = VirtualAlloc(NULL, 65536, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (!host->bytes) goto done;
    DWORD total = 0, got;
    while (total < host->byte_count) {
        if (!ReadFile(file, host->bytes + total, host->byte_count - total, &got, NULL) || !got) goto done;
        total += got;
    }
    DWORD previous;
    ok = VirtualProtect(host->bytes, 65536, PAGE_READONLY, &previous);
done:
    CloseHandle(file);
    return ok;
}

static BOOL initialize_policy(WRIT_HOST *host)
{
    static const char alphabet[] = "0123456789abcdef";
    char *hex = malloc(2 * (size_t)host->byte_count + 1);
    if (!hex) return FALSE;
    for (DWORD i = 0; i < host->byte_count; ++i) {
        hex[2*i] = alphabet[host->bytes[i] >> 4];
        hex[2*i+1] = alphabet[host->bytes[i] & 15];
    }
    hex[2*host->byte_count] = 0;
    WRIT_REPLY reply;
    BOOL ok = rpc(host, "INIT", 0, 0, 0, 0, hex, &reply) && reply.allowed && reply.value == host->byte_count &&
        strlen(reply.detail) == 64;
    if (ok) {
        for (unsigned int i = 0; i < 64; ++i)
            if (!((reply.detail[i] >= '0' && reply.detail[i] <= '9') ||
                (reply.detail[i] >= 'a' && reply.detail[i] <= 'f'))) ok = FALSE;
        strcpy_s(host->digest, sizeof(host->digest), reply.detail);
    }
    SecureZeroMemory(hex, 2 * (size_t)host->byte_count + 1);
    free(hex);
    return ok;
}

static BOOL mount_filesystem(WRIT_HOST *host, wchar_t *mount)
{
    FSP_FSCTL_VOLUME_PARAMS parameters;
    static FSP_FILE_SYSTEM_INTERFACE interface;
    wchar_t sddl[2048];
    LPWSTR user = NULL, package = NULL;
    ZeroMemory(&parameters, sizeof(parameters));
    ZeroMemory(&interface, sizeof(interface));
    if (!ConvertSidToStringSidW((PSID)host->worker.user_sid, &user)) return FALSE;
    if (host->worker.lpac && !ConvertSidToStringSidW(host->worker.app_sid, &package)) {
        LocalFree(user); return FALSE;
    }
    HRESULT formatted = host->worker.lpac ?
        StringCchPrintfW(sddl, ARRAYSIZE(sddl), L"O:BAG:BAD:P(A;;FRFX;;;%s)(A;;FRFX;;;%s)(A;;FA;;;SY)(A;;FA;;;BA)", user, package) :
        StringCchPrintfW(sddl, ARRAYSIZE(sddl), L"O:BAG:BAD:P(A;;FRFX;;;%s)(A;;FA;;;SY)(A;;FA;;;BA)", user);
    LocalFree(user); if (package) LocalFree(package);
    if (FAILED(formatted) || !ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, SDDL_REVISION_1,
        &host->security, &host->security_size)) return FALSE;
    FILETIME time;
    GetSystemTimeAsFileTime(&time);
    host->created = ((UINT64)time.dwHighDateTime << 32) | time.dwLowDateTime;
    parameters.Version = sizeof(parameters);
    parameters.SectorSize = 512; parameters.SectorsPerAllocationUnit = 8;
    parameters.MaxComponentLength = 255;
    parameters.VolumeCreationTime = host->created;
    parameters.VolumeSerialNumber = GetCurrentProcessId();
    parameters.FileInfoTimeout = 0;
    parameters.CaseSensitiveSearch = 1; parameters.CasePreservedNames = 1;
    parameters.UnicodeOnDisk = 1; parameters.PersistentAcls = 1;
    parameters.ReadOnlyVolume = 1;
    parameters.UmFileContextIsUserContext2 = 1;
    parameters.FlushAndPurgeOnCleanup = 1;
    parameters.AllowOpenInKernelMode = 0;
    wcscpy_s(parameters.FileSystemName, ARRAYSIZE(parameters.FileSystemName), L"WritFS1");
    interface.GetVolumeInfo = get_volume_info;
    interface.GetSecurityByName = get_security_by_name;
    interface.Open = open_file;
    interface.Close = close_file;
    interface.Read = read_file;
    interface.GetFileInfo = get_file_info;
    interface.GetSecurity = get_security;
    interface.ReadDirectory = read_directory;
    NTSTATUS status = FspFileSystemCreate(L"" FSP_FSCTL_DISK_DEVICE_NAME, &parameters, &interface, &host->filesystem);
    if (!NT_SUCCESS(status)) { fprintf(stderr, "FAIL winfsp-create status=%08lx\n", (DWORD)status); return FALSE; }
    host->filesystem->UserContext = host;
    FspFileSystemSetOperationGuardStrategy(host->filesystem, FSP_FILE_SYSTEM_OPERATION_GUARD_STRATEGY_COARSE);
    status = FspFileSystemSetMountPointEx(host->filesystem, mount, host->security);
    if (!NT_SUCCESS(status)) { fprintf(stderr, "FAIL winfsp-mount status=%08lx\n", (DWORD)status); return FALSE; }
    status = FspFileSystemStartDispatcher(host->filesystem, 1);
    if (!NT_SUCCESS(status)) { fprintf(stderr, "FAIL winfsp-dispatch status=%08lx\n", (DWORD)status); return FALSE; }
    return TRUE;
}

static SOCKET receiver(int family, int type, unsigned short *port)
{
    SOCKET value = socket(family, type, type == SOCK_STREAM ? IPPROTO_TCP : IPPROTO_UDP);
    if (value == INVALID_SOCKET) return value;
    SOCKADDR_STORAGE address;
    ZeroMemory(&address, sizeof(address));
    int size;
    if (family == AF_INET) {
        SOCKADDR_IN *v4 = (SOCKADDR_IN *)&address;
        v4->sin_family = AF_INET; v4->sin_addr.s_addr = htonl(INADDR_LOOPBACK); size = sizeof(*v4);
    } else {
        DWORD one = 1;
        if (setsockopt(value, IPPROTO_IPV6, IPV6_V6ONLY, (char *)&one, sizeof(one))) goto fail;
        SOCKADDR_IN6 *v6 = (SOCKADDR_IN6 *)&address;
        v6->sin6_family = AF_INET6; v6->sin6_addr = in6addr_loopback; size = sizeof(*v6);
    }
    if (bind(value, (SOCKADDR *)&address, size) ||
        (type == SOCK_STREAM && listen(value, 1)) || getsockname(value, (SOCKADDR *)&address, &size)) goto fail;
    *port = family == AF_INET ? ntohs(((SOCKADDR_IN *)&address)->sin_port) : ntohs(((SOCKADDR_IN6 *)&address)->sin6_port);
    u_long nonblocking = 1;
    if (ioctlsocket(value, FIONBIO, &nonblocking)) goto fail;
    return value;
fail:
    closesocket(value); return INVALID_SOCKET;
}

static BOOL receivers_empty(SOCKET *receivers)
{
    BOOL empty = TRUE;
    for (int i = 0; i < 4; ++i) {
        if (i < 2) {
            SOCKET accepted = accept(receivers[i], NULL, NULL);
            if (accepted != INVALID_SOCKET) { empty = FALSE; closesocket(accepted); }
            else if (WSAGetLastError() != WSAEWOULDBLOCK) empty = FALSE;
        } else {
            char bytes[128];
            if (recv(receivers[i], bytes, sizeof(bytes), 0) != SOCKET_ERROR || WSAGetLastError() != WSAEWOULDBLOCK)
                empty = FALSE;
        }
    }
    return empty;
}

static BOOL read_report(HANDLE input, HANDLE ready, HANDLE process, DWORD phase,
    unsigned int expected, WRIT_PROBE_REPORT *report)
{
    HANDLE waits[2] = { ready, process };
    if (WaitForMultipleObjects(2, waits, FALSE, 20000) != WAIT_OBJECT_0) return FALSE;
    DWORD available = 0, got = 0;
    if (!PeekNamedPipe(input, NULL, 0, NULL, &available, NULL) || available != sizeof(*report) ||
        !ReadFile(input, report, sizeof(*report), &got, NULL) || got != sizeof(*report) ||
        report->magic != WRIT_PROBE_MAGIC || report->phase != phase) return FALSE;
    printf("PROBE phase=%lu passed=%08x failed=%08x", phase, report->passed, report->failed);
    for (unsigned int i = 0; i < ARRAYSIZE(report->errors); ++i)
        printf(" e%u=%lu", i, (DWORD)report->errors[i]);
    printf("\n"); fflush(stdout);
    return report->passed == expected && report->failed == 0;
}

static BOOL choose_mount(wchar_t *mount)
{
    DWORD drives = GetLogicalDrives();
    if (!drives) return FALSE;
    for (int index = 25; index >= 17; --index) if (!(drives & (1u << index))) {
        wchar_t existing[512];
        mount[0] = (wchar_t)(L'A' + index); mount[1] = L':'; mount[2] = 0;
        if (!QueryDosDeviceW(mount, existing, ARRAYSIZE(existing)) && GetLastError() == ERROR_FILE_NOT_FOUND)
            return TRUE;
    }
    return FALSE;
}

static void print_identity(const WRIT_WORKER *worker)
{
    LPWSTR user = NULL, package = NULL;
    ConvertSidToStringSidW((PSID)worker->user_sid, &user);
    if (worker->app_sid) ConvertSidToStringSidW(worker->app_sid, &package);
    printf("IDENTITY pid=%lu created=%08lx%08lx user=%ls auth=%08lx%08lx package=%ls lpac=%u image_sha256=",
        worker->pid, worker->created.dwHighDateTime, worker->created.dwLowDateTime,
        user ? user : L"unknown", (DWORD)worker->token.AuthenticationId.HighPart,
        worker->token.AuthenticationId.LowPart, package ? package : L"none", worker->lpac);
    for (unsigned int i = 0; i < sizeof(worker->image_hash); ++i) printf("%02x", worker->image_hash[i]);
    printf("\n"); fflush(stdout);
    if (user) LocalFree(user); if (package) LocalFree(package);
}

int wmain(int argc, wchar_t **argv)
{
    /* Explicit public fixture, one fixed probe executable, no general client/control socket. */
    if (argc != 8 || wcscmp(argv[1], L"--public-fixture") ||
        (wcscmp(argv[7], L"mount") && wcscmp(argv[7], L"lpac"))) {
        fprintf(stderr, "usage: writfs-windows --public-fixture INPUT NODE BRIDGE MODULE PROBE mount|lpac\n");
        return 2;
    }
    BOOL lpac = !wcscmp(argv[7], L"lpac"), ok = FALSE, sockets_ready = FALSE;
    WRIT_HOST host;
    ZeroMemory(&host, sizeof(host));
    InitializeCriticalSection(&host.lock); host.lock_ready = TRUE;
    SECURITY_ATTRIBUTES inherited = { sizeof(inherited), NULL, TRUE };
    HANDLE report_read = NULL, report_write = NULL, ready = NULL, proceed = NULL;
    SOCKET listeners[4] = { INVALID_SOCKET, INVALID_SOCKET, INVALID_SOCKET, INVALID_SOCKET };
    unsigned short ports[4] = {0};
    wchar_t mount[3], command[32768], digest[65], path[32768], outside[MAX_PATH], temporary[MAX_PATH];
    WRIT_REPLY reply;
    WRIT_PROBE_REPORT report;
    if (!choose_mount(mount) || !freeze_fixture(&host, argv[2]) ||
        !writ_policy_start(&host.policy, argv[3], argv[4], argv[5]) || !initialize_policy(&host)) {
        fprintf(stderr, "FAIL initialize error=%lu\n", GetLastError()); goto done;
    }
    for (unsigned int i = 0; i < 65; ++i) digest[i] = host.digest[i];
    if (!GetTempPathW(ARRAYSIZE(temporary), temporary) ||
        FAILED(StringCchPrintfW(outside, ARRAYSIZE(outside), L"%swrit-egress-%lu-%llu.tmp", temporary,
            GetCurrentProcessId(), GetTickCount64()))) goto done;
    /* Verify the ordinary broker can write the exact destination before testing denial. */
    HANDLE positive = CreateFileW(outside, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (positive == INVALID_HANDLE_VALUE) goto done;
    CloseHandle(positive);
    if (!DeleteFileW(outside)) goto done;
    if (lpac) {
        WSADATA data;
        if (WSAStartup(MAKEWORD(2,2), &data)) goto done;
        sockets_ready = TRUE;
        for (int i = 0; i < 4; ++i) {
            listeners[i] = receiver(i % 2 ? AF_INET6 : AF_INET, i < 2 ? SOCK_STREAM : SOCK_DGRAM, &ports[i]);
            if (listeners[i] == INVALID_SOCKET) { fprintf(stderr, "FAIL listener error=%d\n", WSAGetLastError()); goto done; }
        }
    }
    if (!CreatePipe(&report_read, &report_write, &inherited, 0) ||
        !SetHandleInformation(report_read, HANDLE_FLAG_INHERIT, 0)) goto done;
    ready = CreateEventW(&inherited, FALSE, FALSE, NULL);
    proceed = CreateEventW(&inherited, FALSE, FALSE, NULL);
    if (!ready || !proceed || wcschr(argv[6], L'"') ||
        FAILED(StringCchPrintfW(command, ARRAYSIZE(command),
            L"\"%s\" %s %s %lu %llu %llu %llu %s %lu \"%s\" %u %u %u %u", argv[6], mount,
            digest, host.byte_count, (unsigned long long)(uintptr_t)report_write,
            (unsigned long long)(uintptr_t)ready, (unsigned long long)(uintptr_t)proceed,
            lpac ? L"lpac" : L"mount", GetCurrentProcessId(), outside, ports[0], ports[1], ports[2], ports[3]))) goto done;
    HANDLE handles[3] = { report_write, ready, proceed };
    if (!writ_worker_create(&host.worker, argv[6], command, handles, ARRAYSIZE(handles), lpac)) {
        fprintf(stderr, "FAIL worker-create error=%lu\n", GetLastError()); goto done;
    }
    CloseHandle(report_write); report_write = NULL;
    print_identity(&host.worker);
    if (!mount_filesystem(&host, mount)) goto done;
    printf("NATIVE_PASS native WinFsp filesystem mounted at %ls\n", mount);
    if (FAILED(StringCchPrintfW(path, ARRAYSIZE(path), L"%s\\data", mount))) goto done;
    HANDLE denied = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    DWORD denied_error = denied == INVALID_HANDLE_VALUE ? GetLastError() : 0;
    if (denied != INVALID_HANDLE_VALUE) CloseHandle(denied);
    if (denied != INVALID_HANDLE_VALUE || denied_error != ERROR_ACCESS_DENIED) {
        fprintf(stderr, "FAIL ordinary-reader error=%lu\n", denied_error); goto done;
    }
    printf("NATIVE_PASS ordinary reader receives access denied before admission\n");
    if (!rpc(&host, "ADMIT", 1, 0, 0, 0, "public-canary", &reply) || !reply.allowed || reply.value != 1)
        goto done;
    if (!writ_worker_resume(&host.worker)) goto done;
    if (!read_report(report_read, ready, host.worker.process, 1,
        WRIT_PROBE_MOUNT_MASK | (lpac ? WRIT_PROBE_CONFINEMENT_MASK : 0), &report)) {
        fprintf(stderr, "FAIL first mounted worker phase\n"); goto done;
    }
    printf("NATIVE_PASS admitted worker read, digest, range, EOF and directory match\n");
    printf("NATIVE_PASS write, alternate stream and new-file attempts fail\n");
    denied = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    denied_error = denied == INVALID_HANDLE_VALUE ? GetLastError() : 0;
    if (denied != INVALID_HANDLE_VALUE) CloseHandle(denied);
    if (denied != INVALID_HANDLE_VALUE || denied_error != ERROR_ACCESS_DENIED) goto done;
    printf("NATIVE_PASS ordinary reader remains denied after worker admission\n");
    if (lpac) {
        if (!receivers_empty(listeners) || GetFileAttributesW(outside) != INVALID_FILE_ATTRIBUTES ||
            GetLastError() != ERROR_FILE_NOT_FOUND) goto done;
        printf("NATIVE_PASS LPAC has no capabilities, job and WFP setup verified before observation\n");
        printf("NATIVE_PASS TCP and UDP IPv4/IPv6 blocked; live receivers got no connection or datagram\n");
        printf("NATIVE_PASS public file, child, console, broker access, clipboard and COM probes blocked\n");
        if (!writ_worker_remove_network_filters(&host.worker)) goto done;
    }
    if (!SetEvent(proceed) || !read_report(report_read, ready, host.worker.process, 2,
        lpac ? WRIT_PROBE_NETWORK_MASK : 0, &report)) goto done;
    if (lpac) {
        if (!receivers_empty(listeners)) goto done;
        printf("NATIVE_PASS LPAC network denial survives removal of the broker's dynamic WFP filters\n");
    }
    if (!rpc(&host, "REVOKE", 0, 0, 0, 0, "-", &reply) || !reply.allowed || !SetEvent(proceed) ||
        !read_report(report_read, ready, host.worker.process, 3, WRIT_PROBE_REVOKE_MASK, &report)) goto done;
    if (WaitForSingleObject(host.worker.process, 10000) != WAIT_OBJECT_0) goto done;
    DWORD exit_code;
    if (!GetExitCodeProcess(host.worker.process, &exit_code) || exit_code) goto done;
    printf("NATIVE_PASS revocation denies new opens and a subsequent uncached read\n");
    ok = !host.failed;
done:
    if (!ok) fprintf(stderr, "FAIL native Windows profile=%s win32=%lu\n", lpac ? "lpac-canary" : "mount-canary", GetLastError());
    if (!writ_worker_stop(&host.worker)) { fprintf(stderr, "FAIL worker cleanup\n"); ok = FALSE; }
    if (host.filesystem) {
        FspFileSystemStopDispatcher(host.filesystem);
        FspFileSystemRemoveMountPoint(host.filesystem);
        FspFileSystemDelete(host.filesystem);
    }
    if (host.policy.process && !host.failed) {
        if (!rpc(&host, "STOP", 0, 0, 0, 0, "-", &reply) || !reply.allowed) ok = FALSE;
    }
    writ_policy_stop(&host.policy);
    if (report_read) CloseHandle(report_read); if (report_write) CloseHandle(report_write);
    if (ready) CloseHandle(ready); if (proceed) CloseHandle(proceed);
    for (int i = 0; i < 4; ++i) if (listeners[i] != INVALID_SOCKET) closesocket(listeners[i]);
    if (sockets_ready) WSACleanup();
    if (host.security) LocalFree(host.security);
    if (host.bytes) VirtualFree(host.bytes, 0, MEM_RELEASE);
    if (host.lock_ready) DeleteCriticalSection(&host.lock);
    if (ok) printf("ALL WINDOWS NATIVE CHECKS PASSED profile=%s\n", lpac ? "lpac-canary" : "mount-canary");
    return ok ? 0 : 1;
}
