#ifndef WRIT_WINDOWS_COMBINED_AD_LAUNCH_H
#define WRIT_WINDOWS_COMBINED_AD_LAUNCH_H
#include "worker.h"
#include "combined_ad_checks.h"
#include "combined_ad_token.h"

typedef struct {
    WRIT_WORKER owner;
    HANDLE launch_token;
    PSID *groups, *capabilities;
    DWORD group_count, capability_count;
    BOOL initialized, derived, cleanup_uncertain, child_exit_unverified, cleanup_attempted;
    BOOL mitigation_baseline_set; DWORD mitigation_other;
    wchar_t root[MAX_PATH], environment[32768];
    wchar_t expected_root[MAX_PATH], expected_environment[32768];
    BOOL environment_frozen;
} WRIT_AD_SHARED;
typedef struct {
    HANDLE process, thread, job;
    DWORD pid;
    FILETIME created;
    BOOL cleanup_attempted;
} WRIT_AD_CHILD;

/* Fixed no-data caller supplies a zero-initialized object exactly once. */
BOOL writ_ad_shared_create(WRIT_AD_SHARED *shared, const wchar_t *fixed_image);
BOOL writ_ad_filters_checked(WRIT_AD_SHARED *shared);
BOOL writ_ad_environment_checked(const WRIT_AD_SHARED *shared);
BOOL writ_ad_child_create(WRIT_AD_SHARED *shared, WRIT_AD_ARM arm,
    HANDLE report_writer, WRIT_AD_CHILD *child, WRIT_AD_TOKEN *facts);
/* A failed create may still return a live child or owned job: the caller must
   always stop it and must not start another case on any failure. */
BOOL writ_ad_child_stop(WRIT_AD_SHARED *shared, WRIT_AD_CHILD *child);
BOOL writ_ad_shared_stop(WRIT_AD_SHARED *shared);
#endif
