#ifndef WRIT_WINDOWS_WIN32K_AC_TOKEN_H
#define WRIT_WINDOWS_WIN32K_AC_TOKEN_H
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include "win32k_ac_checks.h"

#define WRIT_AC_TOKEN_MAGIC UINT32_C(0x4142544b)
typedef struct {
    uint32_t magic;
    WRIT_AC_SID user, integrity, package;
    uint32_t elevated, appcontainer;
    LUID authentication;
    DWORD groups_count, restricted_count, privilege_count, capability_count;
    WRIT_AC_SID groups[WRIT_AC_MAX_TOKEN_ENTRIES];
    WRIT_AC_SID capabilities[WRIT_AC_MAX_TOKEN_ENTRIES];
    WRIT_AC_SID restricted[WRIT_AC_MAX_TOKEN_ENTRIES];
    WRIT_AC_PRIVILEGE privileges[WRIT_AC_MAX_TOKEN_ENTRIES];
} WRIT_AC_TOKEN;
/* Snapshot only OS-provided token facts. No Writ identity or authority decision. */
BOOL writ_ac_token_snapshot(HANDLE token, WRIT_AC_TOKEN *out);
/* Bounded checks for the reduced non-AppContainer primary used to launch. */
BOOL writ_ac_token_ordinary_primary(HANDLE token, PSID expected_user);
/* Both snapshots must have zero capabilities; compare the selected remaining fields. */
BOOL writ_ac_token_equal_zero_capabilities(const WRIT_AC_TOKEN *a, const WRIT_AC_TOKEN *b);
#endif
