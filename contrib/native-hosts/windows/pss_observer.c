/* Fixed, self-created synthetic child only. No Writ session or fixture data. */
#define _WIN32_WINNT 0x0A00
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <processsnapshot.h>
#include <stdint.h>
#include <stdio.h>
#include <wchar.h>
#include <strsafe.h>
#include "pss_table.h"
#include "pss_progress.h"

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
    wchar_t environment[2] = {0, 0};
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

    HANDLE job = NULL, child_job = NULL, read_end = NULL, write_end = NULL, event = NULL, excluded = NULL;
    HANDLE image_file = INVALID_HANDLE_VALUE;
    HMODULE compare_module = NULL;
    WRIT_COMPARE_HANDLES compare = NULL;
    SECURITY_ATTRIBUTES security = { sizeof(security), NULL, TRUE };
    STARTUPINFOEXW startup = {0};
    PROCESS_INFORMATION child = {0};
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limit = {0}, actual = {0};
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION child_limit = {0}, child_actual = {0};
    SIZE_T attribute_size = 0;
    BOOL attributes_ready = FALSE, child_created = FALSE, assigned = FALSE, ok = FALSE;
    HPSS snapshot = NULL;
    HPSSWALK marker = NULL;
    PSS_HANDLE_INFORMATION info = {0};
    uint64_t handles[WRIT_PSS_MAX_HANDLES];
    size_t count = 0;
    DWORD status = ERROR_SUCCESS, before = 0, after = 0;
    uint32_t passed = 0, failed = 0;
    BOOL cleanup_ok = TRUE;
    FILETIME created, exited, kernel, user;
    const char *stage = "image";

    image_file = CreateFileW(image, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
        FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    BY_HANDLE_FILE_INFORMATION image_info;
    if (image_file == INVALID_HANDLE_VALUE || !GetFileInformationByHandle(image_file, &image_info)) goto failed;
    if (image_info.dwFileAttributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY)) {
        status = ERROR_INVALID_DATA; goto done;
    }
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
    limit.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_ACTIVE_PROCESS |
        JOB_OBJECT_LIMIT_PROCESS_MEMORY | JOB_OBJECT_LIMIT_PROCESS_TIME;
    limit.BasicLimitInformation.ActiveProcessLimit = 2;
    limit.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart = 15LL * 10000000LL;
    limit.ProcessMemoryLimit = 128 * 1024 * 1024;
    if (!job || !SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limit, sizeof(limit)) ||
        !AssignProcessToJobObject(job, GetCurrentProcess())) goto failed;
    assigned = TRUE;
    if (!QueryInformationJobObject(job, JobObjectExtendedLimitInformation, &actual, sizeof(actual), NULL)) goto failed;
    if (actual.BasicLimitInformation.LimitFlags != limit.BasicLimitInformation.LimitFlags ||
        actual.BasicLimitInformation.ActiveProcessLimit != 2 ||
        actual.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart != limit.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart ||
        actual.ProcessMemoryLimit != limit.ProcessMemoryLimit) { status = ERROR_INVALID_DATA; goto done; }
    stage = "child-job";
    child_job = CreateJobObjectW(NULL, NULL);
    child_limit.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE |
        JOB_OBJECT_LIMIT_ACTIVE_PROCESS | JOB_OBJECT_LIMIT_PROCESS_MEMORY;
    child_limit.BasicLimitInformation.ActiveProcessLimit = 1;
    child_limit.ProcessMemoryLimit = 64 * 1024 * 1024;
    if (!child_job || !SetInformationJobObject(child_job, JobObjectExtendedLimitInformation,
        &child_limit, sizeof(child_limit)) || !QueryInformationJobObject(child_job,
        JobObjectExtendedLimitInformation, &child_actual, sizeof(child_actual), NULL)) goto failed;
    if (child_actual.BasicLimitInformation.LimitFlags != child_limit.BasicLimitInformation.LimitFlags ||
        child_actual.BasicLimitInformation.ActiveProcessLimit != 1 ||
        child_actual.ProcessMemoryLimit != child_limit.ProcessMemoryLimit) {
        status = ERROR_INVALID_DATA; goto done;
    }
    stage = "fixtures";
    if (!CreatePipe(&read_end, &write_end, &security, 0) ||
        !SetHandleInformation(read_end, HANDLE_FLAG_INHERIT, 0) ||
        !(event = CreateEventW(&security, FALSE, FALSE, NULL)) ||
        !(excluded = CreateEventW(&security, FALSE, FALSE, NULL))) goto failed;
    HANDLE inherited[2] = { write_end, event };
    stage = "attributes";
    SetLastError(ERROR_SUCCESS);
    BOOL measured = InitializeProcThreadAttributeList(NULL, 2, 0, &attribute_size);
    DWORD measure_error = GetLastError();
    if (measured || measure_error != ERROR_INSUFFICIENT_BUFFER || !attribute_size) {
        status = measured ? ERROR_INVALID_DATA : measure_error; goto done;
    }
    startup.lpAttributeList = HeapAlloc(GetProcessHeap(), 0, attribute_size);
    if (!startup.lpAttributeList) { status = ERROR_NOT_ENOUGH_MEMORY; goto done; }
    if (!InitializeProcThreadAttributeList(startup.lpAttributeList, 2, 0, &attribute_size)) goto failed;
    attributes_ready = TRUE;
    if (!UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
        inherited, sizeof(inherited), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_JOB_LIST,
        &child_job, sizeof(child_job), NULL, NULL)) goto failed;
    startup.StartupInfo.cb = sizeof(startup);
    startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    stage = "create-child-suspended";
    if (!CreateProcessW(image, command, NULL, NULL, TRUE,
        EXTENDED_STARTUPINFO_PRESENT | CREATE_SUSPENDED | DETACHED_PROCESS | CREATE_UNICODE_ENVIRONMENT,
        environment, NULL, &startup.StartupInfo, &child)) goto failed;
    child_created = TRUE;
    printf("PSS_TARGET self_created=1 suspended=1 process_handle_rights=creation_returned_unqueried no_data=1\n");
    BOOL in_job = FALSE;
    if (!IsProcessInJob(child.hProcess, job, &in_job)) goto failed;
    if (!in_job) { status = ERROR_INVALID_DATA; goto done; }
    in_job = FALSE;
    if (!IsProcessInJob(child.hProcess, child_job, &in_job)) goto failed;
    if (!in_job) { status = ERROR_INVALID_DATA; goto done; }
    if (!GetProcessTimes(child.hProcess, &created, &exited, &kernel, &user) ||
        !lifetime(child.hProcess, child.dwProcessId, created)) goto failed;
    printf("PSS_LIFETIME pid=%lu created=%08lx%08lx no_data=1\n",
        child.dwProcessId, created.dwHighDateTime, created.dwLowDateTime);
    stage = "count-before";
    if (!GetProcessHandleCount(child.hProcess, &before)) goto failed;
    stage = "capture";
    status = PssCaptureSnapshot(child.hProcess, PSS_CAPTURE_HANDLES, 0, &snapshot);
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
    if (!GetProcessHandleCount(child.hProcess, &after) ||
        !lifetime(child.hProcess, child.dwProcessId, created)) goto failed;
    passed |= WRIT_PSS_LIFETIME_OK;
    WRIT_PSS_RESULT result = writ_pss_check(handles, count, info.HandlesCaptured, before, after, 1,
        (uint64_t)(uintptr_t)write_end, (uint64_t)(uintptr_t)event, (uint64_t)(uintptr_t)excluded);
    printf("PSS_OBSERVATION before=%lu captured=%lu walked=%llu after=%lu synthetic_result=%u no_data=1 confinement_credit=none\n",
        before, info.HandlesCaptured, (unsigned long long)count, after, (unsigned int)result);
    stage = "exact-table-and-positive-controls";
    if (result != WRIT_PSS_MATCH) { status = ERROR_INVALID_DATA; goto done; }
    passed |= WRIT_PSS_TABLE_OK;
    stage = "fixture-pipe-identity";
    if (!same_fixture(compare, child.hProcess, write_end, write_end, &status)) goto done;
    stage = "fixture-event-identity";
    if (!same_fixture(compare, child.hProcess, event, event, &status)) goto done;
    passed |= WRIT_PSS_OBJECTS_OK;
    ok = TRUE;
    goto done;
failed:
    status = GetLastError();
done:
    if (!ok) fprintf(stderr, "INCOMPLETE synthetic PSS stage=%s status=%lu no_data=1\n", stage, status);
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
        if (!TerminateProcess(child.hProcess, ERROR_OPERATION_ABORTED)) {
            fprintf(stderr, "PSS_CLEANUP_FAILED terminate-child error=%lu\n", GetLastError()); retired = FALSE;
        }
        DWORD waited = WaitForSingleObject(child.hProcess, 5000);
        if (waited != WAIT_OBJECT_0) {
            DWORD error = waited == WAIT_FAILED ? GetLastError() : ERROR_TIMEOUT;
            fprintf(stderr, "PSS_CLEANUP_FAILED wait-child error=%lu\n", error); retired = FALSE;
        }
        if (retired) passed |= WRIT_PSS_CHILD_RETIRED;
        else failed |= WRIT_PSS_CHILD_RETIRED;
    }
    if (!close_checked(&child.hThread, "child-thread")) cleanup_ok = FALSE;
    if (!close_checked(&child.hProcess, "child-process")) cleanup_ok = FALSE;
    if (attributes_ready) DeleteProcThreadAttributeList(startup.lpAttributeList);
    if (startup.lpAttributeList && !HeapFree(GetProcessHeap(), 0, startup.lpAttributeList)) {
        fprintf(stderr, "PSS_CLEANUP_FAILED attributes error=%lu\n", GetLastError()); cleanup_ok = FALSE;
    }
    if (!close_checked(&excluded, "excluded-event")) cleanup_ok = FALSE;
    if (!close_checked(&event, "event")) cleanup_ok = FALSE;
    if (!close_checked(&write_end, "pipe-write")) cleanup_ok = FALSE;
    if (!close_checked(&read_end, "pipe-read")) cleanup_ok = FALSE;
    if (!close_checked(&image_file, "child-image")) cleanup_ok = FALSE;
    if (!close_checked(&child_job, "kill-on-close-child-job")) cleanup_ok = FALSE;
    if (!close_checked(&job, "observer-job")) cleanup_ok = FALSE;
    if (compare_module) {
        if (FreeLibrary(compare_module)) passed |= WRIT_PSS_COMPARE_RELEASED;
        else { fprintf(stderr, "PSS_CLEANUP_FAILED compare-module error=%lu\n", GetLastError()); failed |= WRIT_PSS_COMPARE_RELEASED; }
    }
    if (cleanup_ok) passed |= WRIT_PSS_HANDLES_CLOSED;
    else failed |= WRIT_PSS_HANDLES_CLOSED;
    ok = writ_pss_complete(passed, failed);
    if (!ok) fprintf(stderr, "INCOMPLETE synthetic PSS result or cleanup (job_assigned=%u passed=%08lx failed=%08lx)\n",
        assigned, (unsigned long)passed, (unsigned long)failed);
    else puts("PSS_OBSERVATION complete no_data=1 confinement_credit=none");
    return ok ? 0 : 1;
}
