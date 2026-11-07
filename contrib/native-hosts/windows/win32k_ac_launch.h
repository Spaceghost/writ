#ifndef WRIT_WINDOWS_WIN32K_AC_LAUNCH_H
#define WRIT_WINDOWS_WIN32K_AC_LAUNCH_H
#include "worker.h"
#include "win32k_ac_checks.h"
#include "win32k_ac_token.h"

typedef struct {
    WRIT_WORKER owner;
    HANDLE launch_token;
    BOOL initialized, cleanup_uncertain, child_exit_unverified, cleanup_attempted;
    BOOL mitigation_baseline_set; DWORD mitigation_other;
    wchar_t root[MAX_PATH], environment[32768];
    wchar_t expected_root[MAX_PATH], expected_environment[32768];
    BOOL environment_frozen;
} WRIT_AC_SHARED;
typedef struct {
    HANDLE process, thread, job;
    DWORD pid;
    FILETIME created;
    BOOL cleanup_attempted;
} WRIT_AC_CHILD;

/* Fixed no-data caller supplies a zero-initialized object exactly once. */
BOOL writ_ac_shared_create(WRIT_AC_SHARED *shared, const wchar_t *fixed_image);
BOOL writ_ac_filters_checked(WRIT_AC_SHARED *shared);
BOOL writ_ac_environment_checked(const WRIT_AC_SHARED *shared);
BOOL writ_ac_child_create(WRIT_AC_SHARED *shared, WRIT_AC_ARM arm,
    HANDLE report_writer, WRIT_AC_CHILD *child, WRIT_AC_TOKEN *facts);
/* A failed create may still return a live child or owned job: the caller must
   always stop it and must not start another case on any failure. */
BOOL writ_ac_child_stop(WRIT_AC_SHARED *shared, WRIT_AC_CHILD *child);
BOOL writ_ac_shared_stop(WRIT_AC_SHARED *shared);
#endif
