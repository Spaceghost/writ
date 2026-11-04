#include "policy_pipe.h"
#include "isolation.h"
#include <strsafe.h>
#include <stdio.h>
#include <string.h>

static void close_handle(HANDLE *handle)
{
    if (*handle && *handle != INVALID_HANDLE_VALUE) CloseHandle(*handle);
    *handle = NULL;
}

static BOOL absolute_argument(const wchar_t *argument)
{
    /* Native path arguments are supplied by the trusted launcher, without a shell. */
    return argument && wcslen(argument) < 30000 && !wcschr(argument, L'"') &&
        ((argument[0] && argument[1] == L':' && argument[2] == L'\\') ||
         (argument[0] == L'\\' && argument[1] == L'\\'));
}

BOOL writ_policy_start(WRIT_POLICY_PIPE *pipe, const wchar_t *node,
    const wchar_t *bridge, const wchar_t *module)
{
    SECURITY_ATTRIBUTES sa = { sizeof(sa), NULL, TRUE };
    SECURITY_ATTRIBUTES process_sa = {0};
    STARTUPINFOEXW startup = {0};
    PROCESS_INFORMATION process = {0};
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    HANDLE child_input = NULL, child_output = NULL, child_error = NULL;
    HANDLE inherited[3];
    SIZE_T attribute_size = 0;
    wchar_t command[32768], system_root[MAX_PATH], environment[MAX_PATH + 32];
    DWORD error = ERROR_INVALID_PARAMETER;
    BOOL ok = FALSE, attributes_initialized = FALSE;

    ZeroMemory(pipe, sizeof(*pipe));
    InitializeCriticalSection(&pipe->lock);
    pipe->lock_ready = TRUE;
    if (!absolute_argument(node) || !absolute_argument(bridge) || !absolute_argument(module))
        goto done;
    if (FAILED(StringCchPrintfW(command, ARRAYSIZE(command),
        L"\"%s\" --no-addons --max-old-space-size=128 \"%s\" \"%s\"", node, bridge, module)))
        goto done;

    /* NODE_OPTIONS, preload hooks, PATH and a caller-selected working directory
       cannot alter the monitor process. All three executable/module paths are explicit. */
    DWORD root_length = GetWindowsDirectoryW(system_root, ARRAYSIZE(system_root));
    if (!root_length || root_length >= ARRAYSIZE(system_root)) goto failed;
    ZeroMemory(environment, sizeof(environment));
    if (FAILED(StringCchPrintfW(environment, ARRAYSIZE(environment) - 1,
        L"SystemRoot=%s", system_root))) goto done;

    if (!CreatePipe(&child_input, &pipe->input, &sa, 0) ||
        !SetHandleInformation(pipe->input, HANDLE_FLAG_INHERIT, 0) ||
        !CreatePipe(&pipe->output, &child_output, &sa, 0) ||
        !SetHandleInformation(pipe->output, HANDLE_FLAG_INHERIT, 0)) goto failed;
    child_error = CreateFileW(L"NUL", GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
        &sa, OPEN_EXISTING, 0, NULL);
    if (child_error == INVALID_HANDLE_VALUE) goto failed;

    pipe->job = CreateJobObjectW(NULL, NULL);
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE |
        JOB_OBJECT_LIMIT_DIE_ON_UNHANDLED_EXCEPTION | JOB_OBJECT_LIMIT_ACTIVE_PROCESS |
        JOB_OBJECT_LIMIT_PROCESS_MEMORY | JOB_OBJECT_LIMIT_JOB_MEMORY | JOB_OBJECT_LIMIT_PROCESS_TIME;
    limits.BasicLimitInformation.ActiveProcessLimit = 1;
    limits.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart = 30LL * 10000000LL;
    limits.ProcessMemoryLimit = limits.JobMemoryLimit = 256 * 1024 * 1024;
    if (!pipe->job || !SetInformationJobObject(pipe->job, JobObjectExtendedLimitInformation,
        &limits, sizeof(limits))) goto failed;

    InitializeProcThreadAttributeList(NULL, 1, 0, &attribute_size);
    startup.lpAttributeList = HeapAlloc(GetProcessHeap(), 0, attribute_size);
    if (!startup.lpAttributeList) { error = ERROR_NOT_ENOUGH_MEMORY; goto done; }
    if (!InitializeProcThreadAttributeList(startup.lpAttributeList, 1, 0, &attribute_size))
        goto failed;
    attributes_initialized = TRUE;
    inherited[0] = child_input; inherited[1] = child_output; inherited[2] = child_error;
    if (!UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
        inherited, sizeof(inherited), NULL, NULL)) goto failed;
    startup.StartupInfo.cb = sizeof(startup);
    startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    startup.StartupInfo.hStdInput = child_input;
    startup.StartupInfo.hStdOutput = child_output;
    startup.StartupInfo.hStdError = child_error;
    if (!writ_process_security(&process_sa)) goto failed;
    if (!CreateProcessW(node, command, &process_sa, &process_sa, TRUE,
        EXTENDED_STARTUPINFO_PRESENT | DETACHED_PROCESS | CREATE_SUSPENDED |
        CREATE_UNICODE_ENVIRONMENT, environment, system_root, &startup.StartupInfo, &process))
        goto failed;
    pipe->process = process.hProcess;
    if (!AssignProcessToJobObject(pipe->job, pipe->process) ||
        ResumeThread(process.hThread) == (DWORD)-1) goto failed;
    ok = TRUE;
    goto done;
failed:
    error = GetLastError();
done:
    if (process_sa.lpSecurityDescriptor) LocalFree(process_sa.lpSecurityDescriptor);
    close_handle(&process.hThread);
    close_handle(&child_input); close_handle(&child_output); close_handle(&child_error);
    if (startup.lpAttributeList) {
        if (attributes_initialized) DeleteProcThreadAttributeList(startup.lpAttributeList);
        HeapFree(GetProcessHeap(), 0, startup.lpAttributeList);
    }
    if (!ok) {
        if (!writ_policy_stop(pipe)) fputs("Writ policy child cleanup did not complete.\n", stderr);
        SetLastError(error);
    }
    return ok;
}

/* Writes use a watchdog because anonymous pipes do not support overlapped I/O.
   A timed-out or malformed exchange poisons the whole monitor instance: it is
   never resynchronized or retried after an uncertain state transition. */
typedef struct { HANDLE pipe; const char *bytes; DWORD length; BOOL ok; } WRITE_TASK;
static DWORD WINAPI write_request(void *parameter)
{
    WRITE_TASK *task = parameter;
    DWORD wrote = 0, total = 0;
    while (total < task->length) {
        if (!WriteFile(task->pipe, task->bytes + total, task->length - total, &wrote, NULL) || !wrote)
            return 0;
        total += wrote;
    }
    task->ok = TRUE;
    return 0;
}

static BOOL decimal(const char *text, DWORD *value)
{
    DWORD number = 0;
    if (!*text || (*text == '0' && text[1])) return FALSE;
    for (; *text; ++text) {
        if (*text < '0' || *text > '9') return FALSE;
        DWORD digit = (DWORD)(*text - '0');
        if (number > (MAXDWORD - digit) / 10) return FALSE;
        number = number * 10 + digit;
    }
    *value = number;
    return TRUE;
}

/* This is wire validation only. The host applies the generated Bend result;
   neither status nor a reason code is reconstructed by the binding. */
static BOOL canonical_reply(const char *response, size_t length, DWORD prior, DWORD *next)
{
    char copy[WRIT_POLICY_REPLY_MAX], *fields[5];
    DWORD ignored_value = 0;
    if (!length || length >= sizeof(copy) || prior == MAXDWORD) return FALSE;
    memcpy(copy, response, length + 1);
    fields[0] = copy;
    for (unsigned int i = 1; i < ARRAYSIZE(fields); ++i) {
        char *tab = strchr(fields[i - 1], '\t');
        if (!tab) return FALSE;
        *tab = 0;
        fields[i] = tab + 1;
    }
    if (strchr(fields[4], '\t') || strcmp(fields[0], "WRITFS1") ||
        !decimal(fields[1], next) || *next != prior + 1 ||
        (strcmp(fields[2], "OK") && strcmp(fields[2], "DENY") && strcmp(fields[2], "ERROR")) ||
        !decimal(fields[3], &ignored_value) || !*fields[4]) return FALSE;
    BOOL reason = TRUE, digest = strlen(fields[4]) == 64;
    for (const unsigned char *p = (const unsigned char *)fields[4]; *p; ++p) {
        if (!((*p >= 'A' && *p <= 'Z') || *p == '_')) reason = FALSE;
        if (!((*p >= '0' && *p <= '9') || (*p >= 'a' && *p <= 'f'))) digest = FALSE;
    }
    return reason || digest;
}

static BOOL output_quiet(const WRIT_POLICY_PIPE *pipe)
{
    DWORD available = 0;
    return WaitForSingleObject(pipe->process, 0) == WAIT_TIMEOUT &&
        PeekNamedPipe(pipe->output, NULL, 0, NULL, &available, NULL) && !available;
}

BOOL writ_policy_exchange(WRIT_POLICY_PIPE *pipe, const char *request,
    char *response, size_t capacity)
{
    size_t length = 0, used = 0;
    ULONGLONG deadline;
    HANDLE writer = NULL;
    WRITE_TASK task;
    BOOL ok = FALSE;
    if (!pipe || !pipe->lock_ready || !request || !response || capacity < 2) return FALSE;
    response[0] = '\0';
    EnterCriticalSection(&pipe->lock);
    if (pipe->failed || !pipe->process || !output_quiet(pipe)) goto done;
    length = strnlen(request, WRIT_POLICY_FRAME_MAX);
    if (!length || length >= WRIT_POLICY_FRAME_MAX || request[length - 1] != '\n') goto done;
    for (size_t i = 0; i + 1 < length; ++i)
        if ((request[i] != '\t' && (unsigned char)request[i] < 32) || (unsigned char)request[i] > 126) goto done;
    deadline = GetTickCount64() + 15000;
    task.pipe = pipe->input; task.bytes = request; task.length = (DWORD)length; task.ok = FALSE;
    writer = CreateThread(NULL, 0, write_request, &task, 0, NULL);
    if (!writer) goto done;
    if (WaitForSingleObject(writer, 15000) != WAIT_OBJECT_0) {
        CancelSynchronousIo(writer);
        /* Terminating the child closes its pipe endpoints and releases blocked writes. */
        TerminateJobObject(pipe->job, ERROR_TIMEOUT);
        if (WaitForSingleObject(writer, 5000) != WAIT_OBJECT_0) {
            TerminateProcess(GetCurrentProcess(), ERROR_TIMEOUT);
            ExitProcess(ERROR_TIMEOUT);
        }
        goto done;
    }
    if (!task.ok) goto done;
    while (GetTickCount64() < deadline) {
        DWORD available = 0, got = 0;
        char byte;
        if (!PeekNamedPipe(pipe->output, NULL, 0, NULL, &available, NULL)) goto done;
        if (!available) {
            if (WaitForSingleObject(pipe->process, 5) != WAIT_TIMEOUT) goto done;
            continue;
        }
        if (!ReadFile(pipe->output, &byte, 1, &got, NULL) || got != 1) goto done;
        if (byte == '\n') {
            DWORD sequence = 0;
            response[used] = '\0';
            /* One request has exactly one response. Never carry queued output
               into another exchange or acknowledge a reply followed by junk. */
            if (!canonical_reply(response, used, pipe->sequence, &sequence) || !output_quiet(pipe)) goto done;
            pipe->sequence = sequence;
            ok = TRUE;
            break;
        }
        if ((byte != '\t' && (unsigned char)byte < 32) || (unsigned char)byte > 126 ||
            used + 1 >= capacity || used + 1 >= WRIT_POLICY_REPLY_MAX)
            goto done;
        response[used++] = byte;
    }
done:
    close_handle(&writer);
    if (!ok) {
        pipe->failed = TRUE;
        if (pipe->job) TerminateJobObject(pipe->job, ERROR_INVALID_DATA);
        response[0] = '\0';
    }
    LeaveCriticalSection(&pipe->lock);
    return ok;
}

BOOL writ_policy_stop(WRIT_POLICY_PIPE *pipe)
{
    BOOL ok = TRUE;
    if (pipe->job) TerminateJobObject(pipe->job, ERROR_OPERATION_ABORTED);
    if (pipe->process) {
        /* Assignment can fail while the newly owned process is suspended and
           not yet in its job. Retire that child as well as assigned children. */
        TerminateProcess(pipe->process, ERROR_OPERATION_ABORTED);
        if (WaitForSingleObject(pipe->process, 5000) != WAIT_OBJECT_0) ok = FALSE;
    }
    close_handle(&pipe->input); close_handle(&pipe->output);
    close_handle(&pipe->process); close_handle(&pipe->job);
    if (pipe->lock_ready) DeleteCriticalSection(&pipe->lock);
    ZeroMemory(pipe, sizeof(*pipe));
    return ok;
}
