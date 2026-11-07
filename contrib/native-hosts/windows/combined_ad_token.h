#ifndef WRIT_WINDOWS_COMBINED_AD_TOKEN_H
#define WRIT_WINDOWS_COMBINED_AD_TOKEN_H
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include "combined_ad_checks.h"

#define WRIT_AD_TOKEN_MAGIC UINT32_C(0x4142544b)
typedef struct {
    uint32_t magic;
    WRIT_AD_SID user, integrity, package;
    uint32_t elevated, appcontainer;
    LUID authentication;
    DWORD groups_count, restricted_count, privilege_count, capability_count;
    WRIT_AD_SID groups[WRIT_AD_MAX_TOKEN_ENTRIES];
    WRIT_AD_SID capabilities[WRIT_AD_MAX_TOKEN_ENTRIES];
    WRIT_AD_SID restricted[WRIT_AD_MAX_TOKEN_ENTRIES];
    WRIT_AD_PRIVILEGE privileges[WRIT_AD_MAX_TOKEN_ENTRIES];
} WRIT_AD_TOKEN;
/* Snapshot only OS-provided token facts. No Writ identity or authority decision. */
BOOL writ_ad_token_snapshot(HANDLE token, WRIT_AD_TOKEN *out);
/* Bounded checks for the reduced non-AppContainer primary used to launch. */
BOOL writ_ad_token_ordinary_primary(HANDLE token, PSID expected_user);
/* Excludes the deliberately varied capability list; validate it independently. */
BOOL writ_ad_token_equal_except_capabilities(const WRIT_AD_TOKEN *a, const WRIT_AD_TOKEN *b);
#endif
