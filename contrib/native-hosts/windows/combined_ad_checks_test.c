/* Synthetic no-data classification, not an OS or confinement test. */
#include "combined_ad_checks.h"
#include <stdio.h>
int main(void)
{
    if (!writ_ad_capabilities(WRIT_AD_ZERO, 0, 0, 0) ||
        !writ_ad_capabilities(WRIT_AD_COMBINED, 1, 1, 1)) return 1;
    if (writ_ad_capabilities(WRIT_AD_ZERO, 1, 1, 1) ||
        writ_ad_capabilities(WRIT_AD_COMBINED, 0, 0, 0) ||
        writ_ad_capabilities(WRIT_AD_COMBINED, 2, 1, 1) ||
        writ_ad_capabilities(WRIT_AD_COMBINED, 1, 0, 1) ||
        writ_ad_capabilities(WRIT_AD_COMBINED, 1, 1, 0) ||
        writ_ad_capabilities((WRIT_AD_ARM)2, 0, 0, 0)) return 2;
    uint64_t on = UINT64_C(1) << 28, off = UINT64_C(2) << 28;
    if (!writ_ad_mitigation(WRIT_AD_ZERO, on, 1, 0) ||
        !writ_ad_mitigation(WRIT_AD_COMBINED, off, 2, 2)) return 2;
    if (writ_ad_mitigation(WRIT_AD_ZERO, off, 1, 0) ||
        writ_ad_mitigation(WRIT_AD_ZERO, on, 0, 0) ||
        writ_ad_mitigation(WRIT_AD_COMBINED, on, 0, 0) ||
        writ_ad_mitigation(WRIT_AD_COMBINED, off, 1, 0) ||
        writ_ad_mitigation(WRIT_AD_COMBINED, off, 2, 0) ||
        writ_ad_mitigation(WRIT_AD_ZERO, on | 1, 1, 0) ||
        writ_ad_mitigation(WRIT_AD_COMBINED, off, UINT32_C(0x80000000), UINT32_C(0x80000000)) ||
        writ_ad_mitigation((WRIT_AD_ARM)2, off, 0, 0)) return 13;
    for (size_t i = 0; i < WRIT_AD_CASES; ++i) {
        unsigned int done = (1u << i) - 1u;
        if (!writ_ad_may_start(i, done, 0) || writ_ad_may_start(i, done, 1)) return 3;
        if (i && writ_ad_may_start(i, done ^ 1u, 0)) return 4;
    }
    if (writ_ad_may_start(WRIT_AD_CASES, 15, 0) ||
        writ_ad_arm(0) != WRIT_AD_ZERO || writ_ad_arm(1) != WRIT_AD_COMBINED ||
        writ_ad_arm(2) != WRIT_AD_COMBINED || writ_ad_arm(3) != WRIT_AD_ZERO ||
        writ_ad_arm(4) == WRIT_AD_ZERO || writ_ad_arm(4) == WRIT_AD_COMBINED) return 5;
    if (!writ_ad_can_init(0, 0) || writ_ad_can_init(1, 0) || writ_ad_can_init(0, 1)) return 16;
    if (!writ_ad_can_launch(0, 0, 0) || writ_ad_can_launch(1, 0, 0) ||
        writ_ad_can_launch(0, 1, 0) || writ_ad_can_launch(0, 0, 1)) return 12;
    if (writ_ad_capabilities(WRIT_AD_COMBINED, 1, 1, 2)) return 13;
    WRIT_AD_SID sids[2] = {{0}};
    sids[0].length = sids[1].length = 8;
    sids[0].bytes[0] = sids[1].bytes[0] = 1;
    sids[1].attributes = 4;
    if (writ_ad_sid_identities_unique(sids, 2)) return 6;
    sids[1].bytes[0] = 2;
    if (!writ_ad_sid_identities_unique(sids, 2)) return 7;
    sids[1].length = 0;
    if (writ_ad_sid_identities_unique(sids, 2)) return 8;
    WRIT_AD_PRIVILEGE privileges[2] = {{0}};
    privileges[0].low = privileges[1].low = 3;
    privileges[1].attributes = 4;
    if (writ_ad_privilege_identities_unique(privileges, 2)) return 9;
    privileges[1].high = 1;
    if (!writ_ad_privilege_identities_unique(privileges, 2)) return 10;
    if (writ_ad_sid_identities_unique(sids, WRIT_AD_MAX_TOKEN_ENTRIES + 1) ||
        writ_ad_privilege_identities_unique(NULL, 1)) return 11;
    if (!writ_ad_case_complete(WRIT_AD_CASE_ALL, 0, 0) || writ_ad_case_complete(WRIT_AD_CASE_ALL, 0, 1)) return 14;
    for (uint32_t bit = 1; bit <= WRIT_AD_TOKEN_OK; bit <<= 1) if (WRIT_AD_CASE_ALL & bit) {
        if (writ_ad_case_complete(WRIT_AD_CASE_ALL & ~bit, 0, 0) ||
            writ_ad_case_complete(WRIT_AD_CASE_ALL, bit, 0)) return 15;
    }
    puts("PASS synthetic combined capability and mitigation, identity uniqueness, failures and ADDA stop conditions");
    return 0;
}
