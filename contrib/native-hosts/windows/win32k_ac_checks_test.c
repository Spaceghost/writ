/* Synthetic no-data classification, not an OS or confinement test. */
#include "win32k_ac_checks.h"
#include <stdio.h>
int main(void)
{
    if (!writ_ac_capabilities(0) || writ_ac_capabilities(1) || writ_ac_capabilities(2)) return 1;
    uint64_t on = UINT64_C(1) << 28, off = UINT64_C(2) << 28;
    if (!writ_ac_mitigation(WRIT_AC_DISABLED, on, 1, 0) ||
        !writ_ac_mitigation(WRIT_AC_ENABLED, off, 2, 2)) return 2;
    if (writ_ac_mitigation(WRIT_AC_DISABLED, off, 1, 0) ||
        writ_ac_mitigation(WRIT_AC_DISABLED, on, 0, 0) ||
        writ_ac_mitigation(WRIT_AC_ENABLED, on, 0, 0) ||
        writ_ac_mitigation(WRIT_AC_ENABLED, off, 1, 0) ||
        writ_ac_mitigation(WRIT_AC_ENABLED, off, 2, 0) ||
        writ_ac_mitigation(WRIT_AC_DISABLED, on | 1, 1, 0) ||
        writ_ac_mitigation(WRIT_AC_ENABLED, off, UINT32_C(0x80000000), UINT32_C(0x80000000)) ||
        writ_ac_mitigation((WRIT_AC_ARM)2, off, 0, 0)) return 13;
    for (size_t i = 0; i < WRIT_AC_CASES; ++i) {
        unsigned int done = (1u << i) - 1u;
        if (!writ_ac_may_start(i, done, 0) || writ_ac_may_start(i, done, 1)) return 3;
        if (i && writ_ac_may_start(i, done ^ 1u, 0)) return 4;
    }
    if (writ_ac_may_start(WRIT_AC_CASES, 15, 0) ||
        writ_ac_arm(0) != WRIT_AC_DISABLED || writ_ac_arm(1) != WRIT_AC_ENABLED ||
        writ_ac_arm(2) != WRIT_AC_ENABLED || writ_ac_arm(3) != WRIT_AC_DISABLED ||
        writ_ac_arm(4) == WRIT_AC_DISABLED || writ_ac_arm(4) == WRIT_AC_ENABLED) return 5;
    if (!writ_ac_can_init(0, 0) || writ_ac_can_init(1, 0) || writ_ac_can_init(0, 1)) return 16;
    if (!writ_ac_can_launch(0, 0, 0) || writ_ac_can_launch(1, 0, 0) ||
        writ_ac_can_launch(0, 1, 0) || writ_ac_can_launch(0, 0, 1)) return 12;
    WRIT_AC_SID sids[2] = {{0}};
    sids[0].length = sids[1].length = 8;
    sids[0].bytes[0] = sids[1].bytes[0] = 1;
    sids[1].attributes = 4;
    if (writ_ac_sid_identities_unique(sids, 2)) return 6;
    sids[1].bytes[0] = 2;
    if (!writ_ac_sid_identities_unique(sids, 2)) return 7;
    sids[1].length = 0;
    if (writ_ac_sid_identities_unique(sids, 2)) return 8;
    WRIT_AC_PRIVILEGE privileges[2] = {{0}};
    privileges[0].low = privileges[1].low = 3;
    privileges[1].attributes = 4;
    if (writ_ac_privilege_identities_unique(privileges, 2)) return 9;
    privileges[1].high = 1;
    if (!writ_ac_privilege_identities_unique(privileges, 2)) return 10;
    if (writ_ac_sid_identities_unique(sids, WRIT_AC_MAX_TOKEN_ENTRIES + 1) ||
        writ_ac_privilege_identities_unique(NULL, 1)) return 11;
    if (!writ_ac_case_complete(WRIT_AC_CASE_ALL, 0, 0) || writ_ac_case_complete(WRIT_AC_CASE_ALL, 0, 1)) return 14;
    for (uint32_t bit = 1; bit <= WRIT_AC_TOKEN_OK; bit <<= 1) if (WRIT_AC_CASE_ALL & bit) {
        if (writ_ac_case_complete(WRIT_AC_CASE_ALL & ~bit, 0, 0) ||
            writ_ac_case_complete(WRIT_AC_CASE_ALL, bit, 0)) return 15;
    }
    puts("PASS synthetic zero capabilities, mitigation readbacks, identity uniqueness, case failures and ACCA stop conditions");
    return 0;
}
