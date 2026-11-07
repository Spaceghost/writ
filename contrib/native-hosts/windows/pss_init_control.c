/* Fixed ordinary no-data initializer positive control; no Writ actor or input. */
#define _WIN32_WINNT 0x0A00
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <wchar.h>
#include <strsafe.h>
#include "worker.h"
#include "init_report.h"
#include "pss_init_progress.h"
#include "pss_init_pipe.h"

static BOOL close_checked(HANDLE *handle, const char *name)
{
    if (!*handle || *handle == INVALID_HANDLE_VALUE) return TRUE;
    BOOL ok = CloseHandle(*handle);
    if (!ok) {
        DWORD error = GetLastError();
        fprintf(stderr, "CONTROL_CLEANUP_FAILED %s error=%lu\n", name, error);
        SetLastError(error);
    }
    *handle = NULL;
    return ok;
}

int wmain(int argc, wchar_t **argv)
{
    (void)argv;
    if (argc != 1) return 2;
    wchar_t image[32768], command[128];
    DWORD length = GetModuleFileNameW(NULL, image, ARRAYSIZE(image));
    if (!length || length >= ARRAYSIZE(image)) return 1;
    wchar_t *name = wcsrchr(image, L'\\');
    if (!name || FAILED(StringCchCopyW(name + 1, ARRAYSIZE(image) - (size_t)(name + 1 - image), L"writfs-init-child.exe"))) return 1;
    HANDLE budget = NULL, input = NULL, output = NULL;
    SECURITY_ATTRIBUTES security = { sizeof(security), NULL, TRUE };
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limit = {0}, actual = {0};
    WRIT_WORKER child = {0};
    WRIT_INIT_REPORT report = {0};
    BOOL child_created = FALSE, ok = FALSE, cleanup_ok = TRUE;
    DWORD status = ERROR_SUCCESS, exit_code = 1;
    const char *stage = "observer-budget";
    budget = CreateJobObjectW(NULL, NULL);
    limit.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_ACTIVE_PROCESS |
        JOB_OBJECT_LIMIT_PROCESS_MEMORY | JOB_OBJECT_LIMIT_PROCESS_TIME | JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK;
    limit.BasicLimitInformation.ActiveProcessLimit = 1;
    limit.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart = 15LL * 10000000LL;
    limit.ProcessMemoryLimit = 128 * 1024 * 1024;
    BOOL in_job = FALSE;
    if (!budget || !SetInformationJobObject(budget, JobObjectExtendedLimitInformation, &limit, sizeof(limit)) ||
        !AssignProcessToJobObject(budget, GetCurrentProcess()) ||
        !IsProcessInJob(GetCurrentProcess(), budget, &in_job)) goto failed;
    if (!in_job) { status = ERROR_INVALID_DATA; goto done; }
    if (!QueryInformationJobObject(budget, JobObjectExtendedLimitInformation, &actual, sizeof(actual), NULL)) goto failed;
    if (actual.BasicLimitInformation.LimitFlags != limit.BasicLimitInformation.LimitFlags ||
        actual.BasicLimitInformation.ActiveProcessLimit != 1 ||
        actual.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart != limit.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart ||
        actual.ProcessMemoryLimit != limit.ProcessMemoryLimit) { status = ERROR_INVALID_DATA; goto done; }
    stage = "fixture";
    if (!CreatePipe(&input, &output, &security, 0)) {
        DWORD error = GetLastError();
        input = NULL; output = NULL; /* Failed CreatePipe outputs are indeterminate. */
        fprintf(stderr, "INCOMPLETE pipe-creation outputs unverified\n");
        status = error; goto done;
    }
    if (!SetHandleInformation(input, HANDLE_FLAG_INHERIT, 0)) goto failed;
    if (FAILED(StringCchPrintfW(command, ARRAYSIZE(command), L"writ-init-child %llu",
        (unsigned long long)(ULONG_PTR)output))) { status = ERROR_INVALID_DATA; goto done; }
    stage = "ordinary-launch";
    printf("BEGIN_NO_DATA_ORDINARY_CONTROL launcher_output_is_diagnostic_only=1\n");
    if (!writ_worker_create(&child, image, command, &output, 1, FALSE)) {
        status = GetLastError();
        fprintf(stderr, "INCOMPLETE ordinary launcher failed; internal cleanup unverified\n");
        goto done;
    }
    child_created = TRUE;
    in_job = TRUE;
    if (!IsProcessInJob(child.process, budget, &in_job)) goto failed;
    if (in_job) { status = ERROR_INVALID_DATA; goto done; }
    if (!IsProcessInJob(child.process, child.job, &in_job)) goto failed;
    if (!in_job) { status = ERROR_INVALID_DATA; goto done; }
    printf("PSS_INIT_ORDINARY_LIFETIME pid=%lu created=%08lx%08lx image_sha256=",
        child.pid, child.created.dwHighDateTime, child.created.dwLowDateTime);
    for (unsigned int i = 0; i < sizeof(child.image_hash); ++i) printf("%02x", child.image_hash[i]);
    puts(" no_data=1 confinement_credit=none");
    if (!close_checked(&output, "ordinary-parent-writer")) goto failed;
    stage = "resume-exactly-once";
    DWORD previous = ResumeThread(child.thread);
    if (previous == (DWORD)-1) goto failed;
    if (!writ_pss_init_suspend_ok(previous)) { status = ERROR_INVALID_DATA; goto done; }
    stage = "wait-same-child";
    DWORD waited = WaitForSingleObject(child.process, 20000);
    if (waited != WAIT_OBJECT_0) { status = waited == WAIT_FAILED ? GetLastError() : ERROR_TIMEOUT; goto done; }
    FILETIME created, exited, kernel, user;
    if (!GetExitCodeProcess(child.process, &exit_code) ||
        !GetProcessTimes(child.process, &created, &exited, &kernel, &user)) goto failed;
    DWORD actual_pid = GetProcessId(child.process);
    if (!actual_pid) goto failed;
    if (actual_pid != child.pid || exit_code != 0 || CompareFileTime(&created, &child.created) != 0) { status = ERROR_INVALID_DATA; goto done; }
    stage = "one-positive-report";
    if (!writ_pss_init_read_report(input, &report, &status)) goto done;
    if (!writ_init_positive(&report, sizeof(report))) { status = ERROR_INVALID_DATA; goto done; }
    puts("PSS_INIT_ORDINARY_RESULT winsock=0 user32=0 ole32=0 no_data=1 confinement_credit=none");
    ok = TRUE;
    goto done;
failed:
    status = GetLastError();
done:
    if (!ok) fprintf(stderr, "INCOMPLETE ordinary initialization stage=%s status=%lu\n", stage, status);
    if (child_created) {
        if (!TerminateJobObject(child.job, ERROR_OPERATION_ABORTED)) {
            fprintf(stderr, "CONTROL_CLEANUP_FAILED terminate-job error=%lu\n", GetLastError()); cleanup_ok = FALSE;
        }
        DWORD retired = WaitForSingleObject(child.process, 5000);
        if (retired != WAIT_OBJECT_0) {
            DWORD error = retired == WAIT_FAILED ? GetLastError() : ERROR_TIMEOUT;
            fprintf(stderr, "CONTROL_CLEANUP_FAILED wait-child error=%lu\n", error); cleanup_ok = FALSE;
        }
        if (!close_checked(&child.thread, "child-thread")) cleanup_ok = FALSE;
        if (!close_checked(&child.process, "child-process")) cleanup_ok = FALSE;
        if (!close_checked(&child.job, "child-job")) cleanup_ok = FALSE;
        if (!close_checked(&child.image, "child-image")) cleanup_ok = FALSE;
    }
    if (!close_checked(&output, "parent-writer")) cleanup_ok = FALSE;
    if (!close_checked(&input, "parent-reader")) cleanup_ok = FALSE;
    if (!close_checked(&budget, "observer-budget")) cleanup_ok = FALSE;
    if (!ok || !cleanup_ok) {
        fprintf(stderr, "INCOMPLETE ordinary initialization or cleanup\n"); return 1;
    }
    puts("PSS_INIT_ORDINARY complete no_data=1 confinement_credit=none");
    return 0;
}
