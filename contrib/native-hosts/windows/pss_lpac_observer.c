/* Fixed no-data LPAC canary launch and PSS observation; no Writ session. */
#define _WIN32_WINNT 0x0A00
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <processsnapshot.h>
#include <fwpmu.h>
#include <winerror.h>
#include <rpc.h>
#include <userenv.h>
#include <stdint.h>
#include <stdio.h>
#include <wchar.h>
#include <strsafe.h>
#include "pss_table.h"
#include "pss_progress.h"
#include "pss_lpac_progress.h"
#include "worker.h"

static BOOL close_checked(HANDLE *handle, const char *name)
{
    if (!*handle || *handle == INVALID_HANDLE_VALUE) return TRUE;
    BOOL ok = CloseHandle(*handle);
    if (!ok) {
        DWORD error = GetLastError();
        fprintf(stderr, "PSS_CLEANUP_FAILED %s error=%lu\n", name, error);
        SetLastError(error);
    }
    *handle = NULL;
    return ok;
}

static BOOL lifetime(HANDLE process, DWORD pid, FILETIME expected)
{
    FILETIME created, exited, kernel, user;
    DWORD waited = WaitForSingleObject(process, 0);
    if (waited == WAIT_FAILED) return FALSE;
    if (waited != WAIT_TIMEOUT) { SetLastError(ERROR_PROCESS_ABORTED); return FALSE; }
    DWORD actual_pid = GetProcessId(process);
    if (!actual_pid) return FALSE;
    if (actual_pid != pid) { SetLastError(ERROR_INVALID_DATA); return FALSE; }
    if (!GetProcessTimes(process, &created, &exited, &kernel, &user)) return FALSE;
    if (CompareFileTime(&created, &expected) != 0) { SetLastError(ERROR_INVALID_DATA); return FALSE; }
    return TRUE;
}

typedef BOOL (WINAPI *WRIT_COMPARE_HANDLES)(HANDLE, HANDLE);

/* Only the two supervisor-created fixture values may be duplicated. */
static BOOL same_fixture(WRIT_COMPARE_HANDLES compare, HANDLE process, HANDLE value, HANDLE original, DWORD *error)
{
    HANDLE copy = NULL;
    BOOL ok = DuplicateHandle(process, value, GetCurrentProcess(), &copy, 0, FALSE, DUPLICATE_SAME_ACCESS);
    if (!ok) *error = GetLastError();
    if (ok) {
        SetLastError(ERROR_SUCCESS);
        if (!compare(copy, original)) {
            *error = GetLastError();
            fprintf(stderr, "PSS_FIXTURE_COMPARE_FALSE last_error=%lu\n", *error);
            ok = FALSE;
        }
    }
    if (!close_checked(&copy, "fixture-duplicate")) {
        *error = GetLastError();
        ok = FALSE;
    }
    return ok;
}

int wmain(int argc, wchar_t **argv)
{
    (void)argv;
    if (argc != 1) return 2;
    wchar_t image[32768], command[] = L"writfs-pss-child";
    DWORD length = GetModuleFileNameW(NULL, image, ARRAYSIZE(image));
    if (!length || length >= ARRAYSIZE(image)) {
        fprintf(stderr, "INCOMPLETE synthetic PSS observer-image error=%lu\n", GetLastError());
        return 1;
    }
    wchar_t *name = wcsrchr(image, L'\\');
    if (!name || FAILED(StringCchCopyW(name + 1, ARRAYSIZE(image) - (size_t)(name + 1 - image), L"writfs-pss-child.exe"))) {
        fprintf(stderr, "INCOMPLETE synthetic PSS fixed-child-path invalid\n");
        return 1;
    }

    HANDLE job = NULL, read_end = NULL, write_end = NULL, event = NULL, excluded = NULL;
    HMODULE compare_module = NULL;
    WRIT_COMPARE_HANDLES compare = NULL;
    SECURITY_ATTRIBUTES security = { sizeof(security), NULL, TRUE };
    WRIT_WORKER child = {0};
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limit = {0}, actual = {0};
    BOOL child_created = FALSE, assigned = FALSE, ok = FALSE;
    HPSS snapshot = NULL;
    HPSSWALK marker = NULL;
    PSS_HANDLE_INFORMATION info = {0};
    uint64_t handles[WRIT_PSS_MAX_HANDLES];
    size_t count = 0;
    DWORD status = ERROR_SUCCESS, before = 0, after = 0;
    uint32_t passed = 0, failed = 0;
    BOOL cleanup_ok = TRUE;
    FILETIME created;
    const char *stage = "image";

    stage = "resolve-compare-api";
    /* Acquire a reference only to the already-loaded OS module. Missing module
       or export is incomplete; no fallback to value-only identity is allowed. */
    if (!GetModuleHandleExW(0, L"KernelBase.dll", &compare_module)) goto failed;
    FARPROC address = GetProcAddress(compare_module, "CompareObjectHandles");
    if (!address) goto failed;
    compare = (WRIT_COMPARE_HANDLES)address;
    passed |= WRIT_PSS_COMPARE_RESOLVED;
    stage = "job-budget";
    job = CreateJobObjectW(NULL, NULL);
    /* This separate budget applies to the observer only. The fixed child gets
       the unchanged, UI-restricted LPAC job from the shared launcher. */
    limit.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_ACTIVE_PROCESS |
        JOB_OBJECT_LIMIT_PROCESS_MEMORY | JOB_OBJECT_LIMIT_PROCESS_TIME |
        JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK;
    limit.BasicLimitInformation.ActiveProcessLimit = 1;
    limit.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart = 15LL * 10000000LL;
    limit.ProcessMemoryLimit = 128 * 1024 * 1024;
    if (!job || !SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limit, sizeof(limit)) ||
        !AssignProcessToJobObject(job, GetCurrentProcess())) goto failed;
    assigned = TRUE;
    BOOL observer_in_job = FALSE;
    if (!IsProcessInJob(GetCurrentProcess(), job, &observer_in_job)) goto failed;
    if (!observer_in_job) { status = ERROR_INVALID_DATA; goto done; }
    if (!QueryInformationJobObject(job, JobObjectExtendedLimitInformation, &actual, sizeof(actual), NULL)) goto failed;
    if (actual.BasicLimitInformation.LimitFlags != limit.BasicLimitInformation.LimitFlags ||
        actual.BasicLimitInformation.ActiveProcessLimit != 1 ||
        actual.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart != limit.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart ||
        actual.ProcessMemoryLimit != limit.ProcessMemoryLimit) { status = ERROR_INVALID_DATA; goto done; }
    stage = "fixtures";
    if (!CreatePipe(&read_end, &write_end, &security, 0) ||
        !SetHandleInformation(read_end, HANDLE_FLAG_INHERIT, 0) ||
        !(event = CreateEventW(&security, FALSE, FALSE, NULL)) ||
        !(excluded = CreateEventW(&security, FALSE, FALSE, NULL))) goto failed;
    HANDLE inherited[2] = { write_end, event };
    stage = "create-lpac-suspended";
    printf("BEGIN_NO_DATA_PSS_LPAC_LAUNCH launcher_output_is_diagnostic_only=1\n");
    if (!writ_worker_create(&child, image, command, inherited, 2, TRUE)) {
        status = GetLastError();
        fprintf(stderr, "INCOMPLETE LPAC launcher failed; internal cleanup unverified\n");
        goto done;
    }
    child_created = TRUE;
    passed |= WRIT_LPAC_LAUNCH_OK;
    printf("END_NO_DATA_PSS_LPAC_LAUNCH no_data=1 process_handle_rights=creation_returned_unqueried\n");
    BOOL in_job = TRUE;
    if (!IsProcessInJob(child.process, job, &in_job)) goto failed;
    if (in_job) { status = ERROR_INVALID_DATA; goto done; }
    if (!IsProcessInJob(child.process, child.job, &in_job)) goto failed;
    if (!in_job) { status = ERROR_INVALID_DATA; goto done; }
    printf("PSS_LPAC_JOBS observer_budget=separate child_in_observer_job=0 child_in_lpac_job=1 outer_jobs=unverified\n");
    if (!lifetime(child.process, child.pid, child.created)) goto failed;
    created = child.created;
    printf("PSS_LPAC_LIFETIME pid=%lu created=%08lx%08lx image_sha256=",
        child.pid, created.dwHighDateTime, created.dwLowDateTime);
    for (unsigned int i = 0; i < sizeof(child.image_hash); ++i) printf("%02x", child.image_hash[i]);
    puts(" no_data=1 confinement_credit=none");
    stage = "count-before";
    if (!GetProcessHandleCount(child.process, &before)) goto failed;
    stage = "capture";
    status = PssCaptureSnapshot(child.process, PSS_CAPTURE_HANDLES, 0, &snapshot);
    if (status != ERROR_SUCCESS) goto done;
    passed |= WRIT_PSS_CAPTURE_OK;
    stage = "snapshot-count";
    status = PssQuerySnapshot(snapshot, PSS_QUERY_HANDLE_INFORMATION, &info, sizeof(info));
    if (status != ERROR_SUCCESS) goto done;
    if (info.HandlesCaptured > WRIT_PSS_MAX_HANDLES) { status = ERROR_BUFFER_OVERFLOW; goto done; }
    passed |= WRIT_PSS_QUERY_OK;
    stage = "walk-marker";
    status = PssWalkMarkerCreate(NULL, &marker);
    if (status != ERROR_SUCCESS) goto done;
    passed |= WRIT_PSS_MARKER_OK;
    stage = "walk";
    for (;;) {
        PSS_HANDLE_ENTRY entry = {0};
        status = PssWalkSnapshot(snapshot, PSS_WALK_HANDLES, marker, &entry, sizeof(entry));
        if (status == ERROR_NO_MORE_ITEMS) break;
        if (status != ERROR_SUCCESS) goto done;
        if (count >= WRIT_PSS_MAX_HANDLES) { status = ERROR_BUFFER_OVERFLOW; goto done; }
        handles[count++] = (uint64_t)(uintptr_t)entry.Handle;
    }
    passed |= WRIT_PSS_WALK_OK;
    status = ERROR_SUCCESS;
    stage = "lifetime-and-count-after";
    if (!GetProcessHandleCount(child.process, &after) ||
        !lifetime(child.process, child.pid, created)) goto failed;
    passed |= WRIT_PSS_LIFETIME_OK;
    WRIT_PSS_RESULT result = writ_pss_check(handles, count, info.HandlesCaptured, before, after, 1,
        (uint64_t)(uintptr_t)write_end, (uint64_t)(uintptr_t)event, (uint64_t)(uintptr_t)excluded);
    printf("PSS_LPAC_OBSERVATION before=%lu captured=%lu walked=%llu after=%lu synthetic_result=%u no_data=1 confinement_credit=none\n",
        before, info.HandlesCaptured, (unsigned long long)count, after, (unsigned int)result);
    stage = "exact-table-and-positive-controls";
    if (result != WRIT_PSS_MATCH) { status = ERROR_INVALID_DATA; goto done; }
    passed |= WRIT_PSS_TABLE_OK;
    stage = "fixture-pipe-identity";
    if (!same_fixture(compare, child.process, write_end, write_end, &status)) goto done;
    stage = "fixture-event-identity";
    if (!same_fixture(compare, child.process, event, event, &status)) goto done;
    passed |= WRIT_PSS_OBJECTS_OK;
    ok = TRUE;
    goto done;
failed:
    status = GetLastError();
done:
    if (!ok) fprintf(stderr, "INCOMPLETE no-data LPAC PSS stage=%s status=%lu no_data=1\n", stage, status);
    if (marker) {
        DWORD rc = PssWalkMarkerFree(marker);
        if (rc == ERROR_SUCCESS) passed |= WRIT_PSS_MARKER_FREED;
        else { fprintf(stderr, "PSS_CLEANUP_FAILED marker status=%lu\n", rc); failed |= WRIT_PSS_MARKER_FREED; }
    }
    if (snapshot) {
        DWORD rc = PssFreeSnapshot(GetCurrentProcess(), snapshot);
        if (rc == ERROR_SUCCESS) passed |= WRIT_PSS_SNAPSHOT_FREED;
        else { fprintf(stderr, "PSS_CLEANUP_FAILED snapshot status=%lu\n", rc); failed |= WRIT_PSS_SNAPSHOT_FREED; }
    }
    if (child_created) {
        BOOL retired = TRUE;
        if (!TerminateJobObject(child.job, ERROR_OPERATION_ABORTED)) {
            fprintf(stderr, "PSS_CLEANUP_FAILED terminate-lpac-job error=%lu\n", GetLastError());
            retired = FALSE;
            if (!TerminateProcess(child.process, ERROR_OPERATION_ABORTED))
                fprintf(stderr, "PSS_CLEANUP_FAILED terminate-lpac-process error=%lu\n", GetLastError());
        }
        DWORD waited = WaitForSingleObject(child.process, 5000);
        if (waited != WAIT_OBJECT_0) {
            DWORD error = waited == WAIT_FAILED ? GetLastError() : ERROR_TIMEOUT;
            fprintf(stderr, "PSS_CLEANUP_FAILED wait-lpac error=%lu\n", error); retired = FALSE;
        }
        if (retired) passed |= WRIT_PSS_CHILD_RETIRED;
        else failed |= WRIT_PSS_CHILD_RETIRED;

        if (writ_lpac_may_release_owned_controls(waited == WAIT_OBJECT_0)) {
            HANDLE wfp_observer = NULL;
            DWORD wfp_rc = FwpmEngineOpen0(NULL, RPC_C_AUTHN_WINNT, NULL, NULL, &wfp_observer);
            if (wfp_rc != ERROR_SUCCESS) {
                fprintf(stderr, "PSS_CLEANUP_FAILED wfp-observer status=%lu\n", wfp_rc);
                failed |= WRIT_LPAC_WFP_ABSENT;
            }
            if (child.network) {
                wfp_rc = FwpmEngineClose0(child.network);
                if (wfp_rc == ERROR_SUCCESS) passed |= WRIT_LPAC_WFP_CLOSED;
                else { fprintf(stderr, "PSS_CLEANUP_FAILED wfp-session status=%lu\n", wfp_rc); failed |= WRIT_LPAC_WFP_CLOSED; }
                child.network = NULL;
            } else failed |= WRIT_LPAC_WFP_CLOSED;
            if (wfp_observer) {
                BOOL absent = TRUE;
                for (unsigned int i = 0; i < 4; ++i) {
                    FWPM_FILTER0 *filter = NULL;
                    wfp_rc = child.filters[i] ? FwpmFilterGetById0(wfp_observer, child.filters[i], &filter) : ERROR_INVALID_DATA;
                    if (filter) FwpmFreeMemory0((void **)&filter);
                    if (wfp_rc != (DWORD)FWP_E_FILTER_NOT_FOUND) {
                        fprintf(stderr, "PSS_CLEANUP_FAILED wfp-filter index=%u status=%lu\n", i, wfp_rc);
                        absent = FALSE;
                    }
                }
                wfp_rc = FwpmEngineClose0(wfp_observer);
                if (wfp_rc != ERROR_SUCCESS) {
                    fprintf(stderr, "PSS_CLEANUP_FAILED wfp-observer-close status=%lu\n", wfp_rc); absent = FALSE;
                }
                if (absent) passed |= WRIT_LPAC_WFP_ABSENT;
                else failed |= WRIT_LPAC_WFP_ABSENT;
            }
        } else {
            /* Do not remove WFP or profile/image resources while the child
               might still be alive. Process teardown/VM destruction is fallback. */
            fprintf(stderr, "PSS_CLEANUP_UNVERIFIED child-exit-not-observed; wfp/profile retained\n");
            failed |= WRIT_LPAC_WFP_CLOSED | WRIT_LPAC_WFP_ABSENT | WRIT_LPAC_IMAGE_REMOVED | WRIT_LPAC_PROFILE_REMOVED;
        }
        if (!close_checked(&child.thread, "lpac-thread")) cleanup_ok = FALSE;
        if (!close_checked(&child.process, "lpac-process")) cleanup_ok = FALSE;
        if (!close_checked(&child.job, "lpac-job")) cleanup_ok = FALSE;
        if (!close_checked(&child.image, "lpac-image")) cleanup_ok = FALSE;
        if (writ_lpac_may_release_owned_controls(waited == WAIT_OBJECT_0)) {
            BOOL image_removed = TRUE;
            if (!child.image_created) {
                fprintf(stderr, "PSS_CLEANUP_FAILED private-image ownership-missing\n"); image_removed = FALSE;
            } else if (!DeleteFileW(child.private_image)) {
                fprintf(stderr, "PSS_CLEANUP_FAILED private-image error=%lu\n", GetLastError()); image_removed = FALSE;
            }
            if (!child.directory_created) {
                fprintf(stderr, "PSS_CLEANUP_FAILED private-directory ownership-missing\n"); image_removed = FALSE;
            } else if (!RemoveDirectoryW(child.private_directory)) {
                fprintf(stderr, "PSS_CLEANUP_FAILED private-directory error=%lu\n", GetLastError()); image_removed = FALSE;
            }
            if (image_removed) passed |= WRIT_LPAC_IMAGE_REMOVED;
            else failed |= WRIT_LPAC_IMAGE_REMOVED;
            HRESULT hr = child.profile_created ? DeleteAppContainerProfile(child.profile) : E_UNEXPECTED;
            if (SUCCEEDED(hr)) passed |= WRIT_LPAC_PROFILE_REMOVED;
            else { fprintf(stderr, "PSS_CLEANUP_FAILED profile hresult=%08lx\n", (unsigned long)hr); failed |= WRIT_LPAC_PROFILE_REMOVED; }
        }
        if (child.app_sid && FreeSid(child.app_sid) == NULL) passed |= WRIT_LPAC_SID_FREED;
        else { fprintf(stderr, "PSS_CLEANUP_FAILED package-sid\n"); failed |= WRIT_LPAC_SID_FREED; }
    }
    if (!close_checked(&excluded, "excluded-event")) cleanup_ok = FALSE;
    if (!close_checked(&event, "event")) cleanup_ok = FALSE;
    if (!close_checked(&write_end, "pipe-write")) cleanup_ok = FALSE;
    if (!close_checked(&read_end, "pipe-read")) cleanup_ok = FALSE;
    if (!close_checked(&job, "observer-job")) cleanup_ok = FALSE;
    if (compare_module) {
        if (FreeLibrary(compare_module)) passed |= WRIT_PSS_COMPARE_RELEASED;
        else { fprintf(stderr, "PSS_CLEANUP_FAILED compare-module error=%lu\n", GetLastError()); failed |= WRIT_PSS_COMPARE_RELEASED; }
    }
    if (cleanup_ok) passed |= WRIT_PSS_HANDLES_CLOSED;
    else failed |= WRIT_PSS_HANDLES_CLOSED;
    ok = writ_lpac_complete(passed, failed, 0);
    if (!ok) fprintf(stderr, "INCOMPLETE no-data LPAC PSS result or cleanup (job_assigned=%u passed=%08lx failed=%08lx)\n",
        assigned, (unsigned long)passed, (unsigned long)failed);
    else puts("PSS_LPAC_OBSERVATION complete no_data=1 confinement_credit=none");
    return ok ? 0 : 1;
}
