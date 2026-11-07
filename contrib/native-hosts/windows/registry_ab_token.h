#ifndef WRIT_WINDOWS_REGISTRY_AB_TOKEN_H
#define WRIT_WINDOWS_REGISTRY_AB_TOKEN_H
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include "registry_ab_checks.h"

#define WRIT_AB_TOKEN_MAGIC UINT32_C(0x4142544b)
typedef struct {
    uint32_t magic;
    WRIT_AB_SID user, integrity, package;
    uint32_t elevated, appcontainer;
    LUID authentication;
    DWORD groups_count, restricted_count, privilege_count, capability_count;
    WRIT_AB_SID groups[WRIT_AB_MAX_TOKEN_ENTRIES];
    WRIT_AB_SID capabilities[WRIT_AB_MAX_TOKEN_ENTRIES];
    WRIT_AB_SID restricted[WRIT_AB_MAX_TOKEN_ENTRIES];
    WRIT_AB_PRIVILEGE privileges[WRIT_AB_MAX_TOKEN_ENTRIES];
} WRIT_AB_TOKEN;
/* Snapshot only OS-provided token facts. No Writ identity or authority decision. */
BOOL writ_ab_token_snapshot(HANDLE token, WRIT_AB_TOKEN *out);
/* Bounded checks for the reduced non-AppContainer primary used to launch. */
BOOL writ_ab_token_ordinary_primary(HANDLE token, PSID expected_user);
/* Excludes the deliberately varied capability list; validate it independently. */
BOOL writ_ab_token_equal_except_capabilities(const WRIT_AB_TOKEN *a, const WRIT_AB_TOKEN *b);
#endif
