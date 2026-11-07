/* Synthetic no-data classification, not an OS or confinement test. */
#include "registry_ab_checks.h"
#include <stdio.h>
int main(void)
{
    if (!writ_ab_capabilities(WRIT_AB_ZERO, 0, 0, 0) ||
        !writ_ab_capabilities(WRIT_AB_REGISTRY, 1, 1, 1)) return 1;
    if (writ_ab_capabilities(WRIT_AB_ZERO, 1, 1, 1) ||
        writ_ab_capabilities(WRIT_AB_REGISTRY, 0, 0, 0) ||
        writ_ab_capabilities(WRIT_AB_REGISTRY, 2, 1, 1) ||
        writ_ab_capabilities(WRIT_AB_REGISTRY, 1, 0, 1) ||
        writ_ab_capabilities(WRIT_AB_REGISTRY, 1, 1, 0) ||
        writ_ab_capabilities((WRIT_AB_ARM)2, 0, 0, 0)) return 2;
    for (size_t i = 0; i < WRIT_AB_CASES; ++i) {
        unsigned int done = (1u << i) - 1u;
        if (!writ_ab_may_start(i, done, 0) || writ_ab_may_start(i, done, 1)) return 3;
        if (i && writ_ab_may_start(i, done ^ 1u, 0)) return 4;
    }
    if (writ_ab_may_start(WRIT_AB_CASES, 15, 0) ||
        writ_ab_arm(0) != WRIT_AB_ZERO || writ_ab_arm(1) != WRIT_AB_REGISTRY ||
        writ_ab_arm(2) != WRIT_AB_REGISTRY || writ_ab_arm(3) != WRIT_AB_ZERO ||
        writ_ab_arm(4) == WRIT_AB_ZERO || writ_ab_arm(4) == WRIT_AB_REGISTRY) return 5;
    if (!writ_ab_can_init(0, 0) || writ_ab_can_init(1, 0) || writ_ab_can_init(0, 1)) return 16;
    if (!writ_ab_can_launch(0, 0, 0) || writ_ab_can_launch(1, 0, 0) ||
        writ_ab_can_launch(0, 1, 0) || writ_ab_can_launch(0, 0, 1)) return 12;
    if (writ_ab_capabilities(WRIT_AB_REGISTRY, 1, 1, 2)) return 13;
    WRIT_AB_SID sids[2] = {{0}};
    sids[0].length = sids[1].length = 8;
    sids[0].bytes[0] = sids[1].bytes[0] = 1;
    sids[1].attributes = 4;
    if (writ_ab_sid_identities_unique(sids, 2)) return 6;
    sids[1].bytes[0] = 2;
    if (!writ_ab_sid_identities_unique(sids, 2)) return 7;
    sids[1].length = 0;
    if (writ_ab_sid_identities_unique(sids, 2)) return 8;
    WRIT_AB_PRIVILEGE privileges[2] = {{0}};
    privileges[0].low = privileges[1].low = 3;
    privileges[1].attributes = 4;
    if (writ_ab_privilege_identities_unique(privileges, 2)) return 9;
    privileges[1].high = 1;
    if (!writ_ab_privilege_identities_unique(privileges, 2)) return 10;
    if (writ_ab_sid_identities_unique(sids, WRIT_AB_MAX_TOKEN_ENTRIES + 1) ||
        writ_ab_privilege_identities_unique(NULL, 1)) return 11;
    if (!writ_ab_case_complete(WRIT_AB_CASE_ALL, 0, 0) || writ_ab_case_complete(WRIT_AB_CASE_ALL, 0, 1)) return 14;
    for (uint32_t bit = 1; bit <= WRIT_AB_TOKEN_OK; bit <<= 1) if (WRIT_AB_CASE_ALL & bit) {
        if (writ_ab_case_complete(WRIT_AB_CASE_ALL & ~bit, 0, 0) ||
            writ_ab_case_complete(WRIT_AB_CASE_ALL, bit, 0)) return 15;
    }
    puts("PASS synthetic registryRead capability, identity uniqueness, case failures and ABBA stop conditions");
    return 0;
}
