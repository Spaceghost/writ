#ifndef WRIT_WINDOWS_REGISTRY_AB_LAUNCH_H
#define WRIT_WINDOWS_REGISTRY_AB_LAUNCH_H
#include "worker.h"
#include "registry_ab_checks.h"
#include "registry_ab_token.h"

typedef struct {
    WRIT_WORKER owner;
    HANDLE launch_token;
    PSID *groups, *capabilities;
    DWORD group_count, capability_count;
    BOOL initialized, derived, cleanup_uncertain, child_exit_unverified, cleanup_attempted;
    wchar_t root[MAX_PATH], environment[32768];
    wchar_t expected_root[MAX_PATH], expected_environment[32768];
    BOOL environment_frozen;
} WRIT_AB_SHARED;
typedef struct {
    HANDLE process, thread, job;
    DWORD pid;
    FILETIME created;
    BOOL cleanup_attempted;
} WRIT_AB_CHILD;

/* Fixed no-data caller supplies a zero-initialized object exactly once. */
BOOL writ_ab_shared_create(WRIT_AB_SHARED *shared, const wchar_t *fixed_image);
BOOL writ_ab_filters_checked(WRIT_AB_SHARED *shared);
BOOL writ_ab_environment_checked(const WRIT_AB_SHARED *shared);
BOOL writ_ab_child_create(WRIT_AB_SHARED *shared, WRIT_AB_ARM arm,
    HANDLE report_writer, WRIT_AB_CHILD *child, WRIT_AB_TOKEN *facts);
/* A failed create may still return a live child or owned job: the caller must
   always stop it and must not start another case on any failure. */
BOOL writ_ab_child_stop(WRIT_AB_SHARED *shared, WRIT_AB_CHILD *child);
BOOL writ_ab_shared_stop(WRIT_AB_SHARED *shared);
#endif
