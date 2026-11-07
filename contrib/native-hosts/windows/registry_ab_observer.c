/* Fixed no-data registryRead ABBA diagnostic. No Writ session or input data. */
#define _WIN32_WINNT 0x0A00
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <processsnapshot.h>
#include <stdint.h>
#include <stdio.h>
#include <wchar.h>
#include <strsafe.h>
#include "registry_ab_launch.h"
#include "registry_ab_checks.h"
#include "pss_table.h"
#include "pss_init_pipe.h"
#include "pss_init_progress.h"

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
    if (!ok) { *error = GetLastError(); copy = NULL; }
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

/* One case may never start a successor unless all of its owned state retired. */
static BOOL run_case(WRIT_AB_SHARED *shared, WRIT_COMPARE_HANDLES compare, HANDLE budget,
    size_t index, WRIT_AB_TOKEN *baseline, BOOL *baseline_set)
{
    SECURITY_ATTRIBUTES security = { sizeof(security), NULL, TRUE };
    HANDLE input = NULL, output = NULL, excluded = NULL;
    WRIT_AB_CHILD child = {0};
    WRIT_AB_TOKEN facts = {0};
    HPSS snapshot = NULL;
    HPSSWALK marker = NULL;
    PSS_HANDLE_INFORMATION info = {0};
    uint64_t handles[WRIT_PSS_MAX_HANDLES];
    size_t count = 0;
    uint32_t passed = WRIT_PSS_COMPARE_RESOLVED, failed = 0;
    DWORD status = ERROR_SUCCESS, before = 0, after = 0;
    BOOL ok = FALSE, cleanup_ok = TRUE, in_job = TRUE;
    const char *stage = "fixture";
    WRIT_AB_ARM arm = writ_ab_arm(index);
    if (!CreatePipe(&input, &output, &security, 0)) {
        DWORD error = GetLastError(); input = NULL; output = NULL;
        shared->cleanup_uncertain = TRUE; status = error;
        fprintf(stderr, "INCOMPLETE AB pipe-creation outputs unverified\n"); goto done;
    }
    if (!SetHandleInformation(input, HANDLE_FLAG_INHERIT, 0) ||
        !(excluded = CreateEventW(&security, FALSE, FALSE, NULL))) goto failed;
    stage = "launch";
    if (!writ_ab_child_create(shared, arm, output, &child, &facts)) goto failed;
    passed |= WRIT_LPAC_LAUNCH_OK;
    if (!IsProcessInJob(child.process, budget, &in_job)) goto failed;
    if (in_job) { status = ERROR_INVALID_DATA; goto done; }
    if (!lifetime(child.process, child.pid, child.created)) goto failed;
    stage = "canonical-token-comparison";
    const char *token_scope = "baseline";
    if (!*baseline_set) { *baseline = facts; *baseline_set = TRUE; }
    else {
        if (!writ_ab_token_equal_except_capabilities(baseline, &facts)) {
            fprintf(stderr, "AB_INCONCLUSIVE index=%llu reason=token-drift\n", (unsigned long long)index);
            status = ERROR_INVALID_DATA; goto done;
        }
        token_scope = "match";
    }
    passed |= WRIT_AB_TOKEN_OK;
    printf("AB_LIFETIME index=%llu arm=%c pid=%lu created=%08lx%08lx image_sha256=",
        (unsigned long long)index, arm == WRIT_AB_ZERO ? 'A' : 'B', child.pid,
        child.created.dwHighDateTime, child.created.dwLowDateTime);
    for (unsigned int i = 0; i < sizeof(shared->owner.image_hash); ++i) printf("%02x", shared->owner.image_hash[i]);
    printf(" selected_token_facts=%s environment_input_equal=1 child_environment=unverified no_data=1 confinement_credit=none\n", token_scope);
    printf("AB_TOKEN_COUNTS index=%llu groups=%lu restricted=%lu privileges=%lu capabilities=%lu capability_attributes=%08lx raw_token_fields=not_retained\n",
        (unsigned long long)index, facts.groups_count, facts.restricted_count, facts.privilege_count,
        facts.capability_count, facts.capability_count == 1 ? (unsigned long)facts.capabilities[0].attributes : 0ul);
    stage = "count-before";
    if (!GetProcessHandleCount(child.process, &before)) goto failed;
    stage = "capture";
    status = PssCaptureSnapshot(child.process, PSS_CAPTURE_HANDLES, 0, &snapshot);
    if (status != ERROR_SUCCESS) { snapshot = NULL; shared->cleanup_uncertain = TRUE; goto done; }
    if (!snapshot) { status = ERROR_INVALID_DATA; shared->cleanup_uncertain = TRUE; goto done; }
    passed |= WRIT_PSS_CAPTURE_OK;
    stage = "snapshot-count";
    status = PssQuerySnapshot(snapshot, PSS_QUERY_HANDLE_INFORMATION, &info, sizeof(info));
    if (status != ERROR_SUCCESS) goto done;
    if (info.HandlesCaptured > WRIT_PSS_MAX_HANDLES) { status = ERROR_BUFFER_OVERFLOW; goto done; }
    passed |= WRIT_PSS_QUERY_OK;
    stage = "walk-marker";
    status = PssWalkMarkerCreate(NULL, &marker);
    if (status != ERROR_SUCCESS) { marker = NULL; shared->cleanup_uncertain = TRUE; goto done; }
    if (!marker) { status = ERROR_INVALID_DATA; shared->cleanup_uncertain = TRUE; goto done; }
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
    stage = "lifetime-and-count-after";
    if (!GetProcessHandleCount(child.process, &after) || !lifetime(child.process, child.pid, child.created)) goto failed;
    passed |= WRIT_PSS_LIFETIME_OK;
    WRIT_PSS_RESULT result = writ_pss_check_one(handles, count, info.HandlesCaptured, before, after, 1,
        (uint64_t)(uintptr_t)output, (uint64_t)(uintptr_t)excluded);
    printf("AB_PSS index=%llu before=%lu captured=%lu walked=%llu after=%lu result=%u no_data=1\n",
        (unsigned long long)index, before, info.HandlesCaptured, (unsigned long long)count, after, (unsigned int)result);
    stage = "expected-pipe";
    if (result != WRIT_PSS_MATCH) { status = ERROR_INVALID_DATA; goto done; }
    passed |= WRIT_PSS_TABLE_OK;
    if (!same_fixture(compare, child.process, output, output, &status)) {
        /* This also covers an unverified duplicate-handle close. */
        shared->cleanup_uncertain = TRUE; goto done;
    }
    passed |= WRIT_PSS_OBJECTS_OK;
    stage = "free-marker-before-resume";
    status = PssWalkMarkerFree(marker); marker = NULL;
    if (status != ERROR_SUCCESS) { failed |= WRIT_PSS_MARKER_FREED; shared->cleanup_uncertain = TRUE; goto done; }
    passed |= WRIT_PSS_MARKER_FREED;
    stage = "free-snapshot-before-resume";
    status = PssFreeSnapshot(GetCurrentProcess(), snapshot); snapshot = NULL;
    if (status != ERROR_SUCCESS) { failed |= WRIT_PSS_SNAPSHOT_FREED; shared->cleanup_uncertain = TRUE; goto done; }
    passed |= WRIT_PSS_SNAPSHOT_FREED;
    stage = "close-writer-before-resume";
    if (!close_checked(&output, "AB parent writer")) {
        status = GetLastError(); failed |= WRIT_INIT_WRITER_CLOSED; shared->cleanup_uncertain = TRUE; goto done;
    }
    passed |= WRIT_INIT_WRITER_CLOSED;
    /* The token-match bit is an extra diagnostic condition, not PSS authority. */
    if (!writ_pss_init_can_resume(passed & ~WRIT_AB_TOKEN_OK, failed) || !lifetime(child.process, child.pid, child.created)) {
        status = ERROR_INVALID_DATA; goto done;
    }
    stage = "resume-exactly-once";
    DWORD previous = ResumeThread(child.thread);
    if (previous == (DWORD)-1) goto failed;
    if (!writ_pss_init_suspend_ok(previous)) { status = ERROR_INVALID_DATA; goto done; }
    passed |= WRIT_INIT_RESUMED;
    stage = "wait-same-child";
    DWORD waited = WaitForSingleObject(child.process, 20000), exit_code = 1;
    if (waited != WAIT_OBJECT_0) { status = waited == WAIT_FAILED ? GetLastError() : ERROR_TIMEOUT; goto done; }
    FILETIME created, exited, kernel, user;
    if (!GetExitCodeProcess(child.process, &exit_code) || !GetProcessTimes(child.process, &created, &exited, &kernel, &user)) goto failed;
    DWORD actual_pid = GetProcessId(child.process);
    if (!actual_pid) goto failed;
    if (actual_pid != child.pid || exit_code != 0 || CompareFileTime(&created, &child.created) != 0) { status = ERROR_INVALID_DATA; goto done; }
    passed |= WRIT_INIT_EXITED;
    stage = "one-exact-report";
    WRIT_INIT_REPORT report = {0};
    if (!writ_pss_init_read_report(input, &report, &status)) goto done;
    printf("AB_RAW index=%llu arm=%c winsock=%lu load_failures=%lu user32=%lu ole32=%lu cleanup_failures=%lu initial_modules=%lu after_winsock_modules=%lu pre_ole32_modules=%lu interpretation=inconclusive no_data=1\n",
        (unsigned long long)index, arm == WRIT_AB_ZERO ? 'A' : 'B', (unsigned long)report.winsock,
        (unsigned long)report.load_failures, (unsigned long)report.user32, (unsigned long)report.ole32,
        (unsigned long)report.cleanup_failures, (unsigned long)report.initial_modules,
        (unsigned long)report.after_winsock_modules, (unsigned long)report.pre_ole32_modules);
    if (!writ_init_cold(&report, sizeof(report)) || report.cleanup_failures) { status = ERROR_INVALID_DATA; goto done; }
    passed |= WRIT_INIT_REPORT_OK;
    ok = TRUE;
    goto done;
failed:
    status = GetLastError();
done:
    if (!ok) fprintf(stderr, "INCOMPLETE AB index=%llu stage=%s status=%lu\n", (unsigned long long)index, stage, status);
    if (marker) {
        DWORD rc = PssWalkMarkerFree(marker);
        if (rc == ERROR_SUCCESS) passed |= WRIT_PSS_MARKER_FREED;
        else { fprintf(stderr, "AB_CLEANUP_FAILED marker status=%lu\n", rc); failed |= WRIT_PSS_MARKER_FREED; shared->cleanup_uncertain = TRUE; }
    }
    if (snapshot) {
        DWORD rc = PssFreeSnapshot(GetCurrentProcess(), snapshot);
        if (rc == ERROR_SUCCESS) passed |= WRIT_PSS_SNAPSHOT_FREED;
        else { fprintf(stderr, "AB_CLEANUP_FAILED snapshot status=%lu\n", rc); failed |= WRIT_PSS_SNAPSHOT_FREED; shared->cleanup_uncertain = TRUE; }
    }
    if (writ_ab_child_stop(shared, &child)) passed |= WRIT_PSS_CHILD_RETIRED;
    else failed |= WRIT_PSS_CHILD_RETIRED;
    if (!close_checked(&excluded, "AB excluded event")) cleanup_ok = FALSE;
    if (!close_checked(&output, "AB parent writer")) cleanup_ok = FALSE;
    if (!close_checked(&input, "AB parent reader")) cleanup_ok = FALSE;
    if (cleanup_ok) passed |= WRIT_PSS_HANDLES_CLOSED;
    else { failed |= WRIT_PSS_HANDLES_CLOSED; shared->cleanup_uncertain = TRUE; }
    if (!writ_ab_filters_checked(shared)) { fprintf(stderr, "AB_CLEANUP_FAILED wfp-readback error=%lu\n", GetLastError()); failed |= WRIT_AB_WFP_CHECK_FAILED; }
    ok = writ_ab_case_complete(passed, failed, 0);
    if (!ok) fprintf(stderr, "INCOMPLETE AB index=%llu passed=%08lx failed=%08lx\n", (unsigned long long)index, (unsigned long)passed, (unsigned long)failed);
    else printf("AB_CASE_COMPLETE index=%llu no_data=1 interpretation=inconclusive\n", (unsigned long long)index);
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
    HANDLE budget = NULL;
    HMODULE compare_module = NULL;
    WRIT_COMPARE_HANDLES compare = NULL;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limit = {0}, actual = {0};
    WRIT_AB_SHARED shared = {0};
    WRIT_AB_TOKEN baseline = {0};
    BOOL baseline_set = FALSE, shared_attempted = FALSE, ok = FALSE;
    unsigned int completed = 0, failed = 0;
    DWORD status = ERROR_SUCCESS;
    const char *stage = "resolve-compare-api";
    if (!GetModuleHandleExW(0, L"KernelBase.dll", &compare_module)) { compare_module = NULL; goto failed; }
    FARPROC address = GetProcAddress(compare_module, "CompareObjectHandles");
    if (!address) goto failed;
    compare = (WRIT_COMPARE_HANDLES)address;
    stage = "observer-budget";
    budget = CreateJobObjectW(NULL, NULL);
    limit.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_ACTIVE_PROCESS |
        JOB_OBJECT_LIMIT_PROCESS_MEMORY | JOB_OBJECT_LIMIT_PROCESS_TIME | JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK;
    limit.BasicLimitInformation.ActiveProcessLimit = 1;
    limit.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart = 15LL * 10000000LL;
    limit.ProcessMemoryLimit = 128 * 1024 * 1024;
    BOOL in_job = FALSE;
    if (!budget || !SetInformationJobObject(budget, JobObjectExtendedLimitInformation, &limit, sizeof(limit)) ||
        !AssignProcessToJobObject(budget, GetCurrentProcess()) || !IsProcessInJob(GetCurrentProcess(), budget, &in_job)) goto failed;
    if (!in_job) { status = ERROR_INVALID_DATA; goto done; }
    if (!QueryInformationJobObject(budget, JobObjectExtendedLimitInformation, &actual, sizeof(actual), NULL)) goto failed;
    if (actual.BasicLimitInformation.LimitFlags != limit.BasicLimitInformation.LimitFlags ||
        actual.BasicLimitInformation.ActiveProcessLimit != 1 ||
        actual.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart != limit.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart ||
        actual.ProcessMemoryLimit != limit.ProcessMemoryLimit) { status = ERROR_INVALID_DATA; goto done; }
    stage = "shared-no-data-package";
    shared_attempted = TRUE;
    if (!writ_ab_shared_create(&shared, image)) goto failed;
    for (size_t i = 0; i < WRIT_AB_CASES; ++i) {
        stage = "ABBA-case";
        if (!writ_ab_may_start(i, completed, failed) || shared.cleanup_uncertain || shared.child_exit_unverified ||
            !run_case(&shared, compare, budget, i, &baseline, &baseline_set)) {
            failed |= (1u << i);
            status = ERROR_INVALID_DATA;
            goto done;
        }
        completed |= (1u << i);
    }
    if (completed != ((1u << WRIT_AB_CASES) - 1u) || failed) { status = ERROR_INVALID_DATA; goto done; }
    ok = TRUE;
    goto done;
failed:
    status = GetLastError();
done:
    if (!ok) fprintf(stderr, "INCOMPLETE AB sequence stage=%s status=%lu completed=%08x failed=%08x\n", stage, status, completed, failed);
    if (shared_attempted && !writ_ab_shared_stop(&shared)) {
        fprintf(stderr, "AB_CLEANUP_UNVERIFIED shared resources; disposable VM fallback\n"); ok = FALSE;
    }
    if (!close_checked(&budget, "AB observer budget")) ok = FALSE;
    if (compare_module && !FreeLibrary(compare_module)) {
        fprintf(stderr, "AB_CLEANUP_FAILED compare-module error=%lu\n", GetLastError()); ok = FALSE;
    }
    if (!ok) {
        fprintf(stderr, "INCOMPLETE AB sequence or cleanup no_data=1 interpretation=inconclusive\n"); return 1;
    }
    puts("AB_SEQUENCE_COMPLETE cases=4 no_data=1 interpretation=inconclusive confinement_credit=none");
    return 0;
}
