/* Standalone no-data initialization supervisor; no Writ session or fixture. */
#define _WIN32_WINNT 0x0A00
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <fwpmu.h>
#include <winerror.h>
#include <rpc.h>
#include <userenv.h>
#include <stdint.h>
#include <stdio.h>
#include <wchar.h>
#include <strsafe.h>
#include "init_report.h"
#include "worker.h"

static BOOL close_checked(HANDLE *handle)
{
    if (!*handle || *handle == INVALID_HANDLE_VALUE) return TRUE;
    BOOL ok = CloseHandle(*handle);
    *handle = NULL;
    return ok;
}

/* Retire only resources from this successful standalone launch. Verify every
   owned WFP filter disappeared through a separate engine after session close. */
static BOOL cleanup(WRIT_WORKER *worker)
{
    BOOL ok = TRUE;
    HANDLE observer = NULL;
    if (worker->network && FwpmEngineOpen0(NULL, RPC_C_AUTHN_WINNT, NULL, NULL, &observer) != ERROR_SUCCESS)
        ok = FALSE;
    if (worker->job && !TerminateJobObject(worker->job, ERROR_OPERATION_ABORTED)) ok = FALSE;
    if (worker->process && WaitForSingleObject(worker->process, 5000) != WAIT_OBJECT_0) ok = FALSE;
    if (!close_checked(&worker->thread)) ok = FALSE;
    if (!close_checked(&worker->process)) ok = FALSE;
    if (!close_checked(&worker->job)) ok = FALSE;
    if (!close_checked(&worker->image)) ok = FALSE;
    if (worker->network) {
        if (FwpmEngineClose0(worker->network) != ERROR_SUCCESS) ok = FALSE;
        worker->network = NULL;
        if (observer) for (unsigned int i = 0; i < 4; ++i) {
            FWPM_FILTER0 *filter = NULL;
            DWORD status = worker->filters[i] ? FwpmFilterGetById0(observer, worker->filters[i], &filter) : ERROR_INVALID_DATA;
            if (filter) FwpmFreeMemory0((void **)&filter);
            if (status != (DWORD)FWP_E_FILTER_NOT_FOUND) ok = FALSE;
        }
    }
    if (observer && FwpmEngineClose0(observer) != ERROR_SUCCESS) ok = FALSE;
    if (worker->image_created && !DeleteFileW(worker->private_image)) ok = FALSE;
    if (worker->directory_created && !RemoveDirectoryW(worker->private_directory)) ok = FALSE;
    if (worker->profile_created && FAILED(DeleteAppContainerProfile(worker->profile))) ok = FALSE;
    if (worker->app_sid && FreeSid(worker->app_sid) != NULL) ok = FALSE;
    return ok;
}

static BOOL run_case(const wchar_t *image, BOOL lpac, const char *label)
{
    SECURITY_ATTRIBUTES security = { sizeof(security), NULL, TRUE };
    HANDLE input = NULL, output = NULL;
    WRIT_WORKER worker = {0};
    WRIT_INIT_REPORT report = {0};
    wchar_t command[128];
    DWORD available = 0, got = 0, code = 1;
    BOOL started = FALSE, ok = FALSE;
    if (!CreatePipe(&input, &output, &security, 0) ||
        !SetHandleInformation(input, HANDLE_FLAG_INHERIT, 0) ||
        FAILED(StringCchPrintfW(command, ARRAYSIZE(command), L"writ-init-child %llu",
            (unsigned long long)(ULONG_PTR)output))) goto done;
    printf("BEGIN_NO_DATA_LAUNCH %s; launcher output below is diagnostic only\n", label);
    if (!writ_worker_create(&worker, image, command, &output, 1, lpac)) {
        /* The shared launcher's internal failure cleanup cannot be independently
           verified here. This case is always incomplete. */
        fprintf(stderr, "INCOMPLETE no-data launcher failed; cleanup not independently verified\n");
        goto done;
    }
    started = TRUE;
    printf("END_NO_DATA_LAUNCH %s\n", label);
    if (!close_checked(&output)) goto done;
    printf("INIT_PROFILE %s no_data=1 pid=%lu created=%08lx%08lx image_sha256=", label,
        worker.pid, worker.created.dwHighDateTime, worker.created.dwLowDateTime);
    for (unsigned int i = 0; i < sizeof(worker.image_hash); ++i) printf("%02x", worker.image_hash[i]);
    printf(" report_handles=1 session=none data=none\n");
    if (!writ_worker_resume(&worker) || WaitForSingleObject(worker.process, 20000) != WAIT_OBJECT_0 ||
        !GetExitCodeProcess(worker.process, &code) || code != 0 ||
        !PeekNamedPipe(input, NULL, 0, NULL, &available, NULL) || available != sizeof(report) ||
        !ReadFile(input, &report, sizeof(report), &got, NULL) ||
        !writ_init_report_valid(&report, got)) goto done;
    printf("INIT_RESULT %s initial_modules=%lu after_winsock_modules=%lu pre_ole32_modules=%lu winsock=%lu load_failures=%lu cleanup_failures=%lu user32=%lu ole32=%lu confinement_credit=none\n",
        label, (unsigned long)report.initial_modules, (unsigned long)report.after_winsock_modules,
        (unsigned long)report.pre_ole32_modules, (unsigned long)report.winsock,
        (unsigned long)report.load_failures, (unsigned long)report.cleanup_failures, (unsigned long)report.user32, (unsigned long)report.ole32);
    /* A preloaded target invalidates a cold-load comparison, even in LPAC. */
    if (!writ_init_cold(&report, got) || report.cleanup_failures) goto done;
    ok = lpac || writ_init_positive(&report, got);
done:
    if (!ok) fprintf(stderr, "INCOMPLETE no-data initialization %s error=%lu exit=%lu\n", label, GetLastError(), code);
    if (!close_checked(&output)) ok = FALSE;
    if (!close_checked(&input)) ok = FALSE;
    if (started && !cleanup(&worker)) {
        fprintf(stderr, "INCOMPLETE no-data initialization %s cleanup or WFP readback failed\n", label);
        ok = FALSE;
    }
    if (started && ok) printf("INIT_CLEANUP %s owned_resources=retired wfp_readback=%s\n", label, lpac ? "absent" : "not-applicable");
    return ok;
}

int wmain(int argc, wchar_t **argv)
{
    (void)argv;
    if (argc != 1) return 2;
    wchar_t image[32768];
    DWORD length = GetModuleFileNameW(NULL, image, ARRAYSIZE(image));
    if (!length || length >= ARRAYSIZE(image)) return 1;
    wchar_t *name = wcsrchr(image, L'\\');
    if (!name || FAILED(StringCchCopyW(name + 1, ARRAYSIZE(image) - (size_t)(name + 1 - image), L"writfs-init-child.exe"))) return 1;
    /* Controlled launches supply only the fixed child image and report handle. */
    if (!run_case(image, FALSE, "ordinary-before")) return 1;
    if (!run_case(image, TRUE, "lpac")) return 1;
    if (!run_case(image, FALSE, "ordinary-after")) return 1;
    puts("INIT_OBSERVATION complete no_data=1 confinement_credit=none");
    return 0;
}
