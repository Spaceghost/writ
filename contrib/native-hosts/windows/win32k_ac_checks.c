#include "win32k_ac_checks.h"
#include <string.h>
int writ_ac_capabilities(uint32_t count) { return count == 0; }
int writ_ac_mitigation(WRIT_AC_ARM arm, uint64_t creation, uint32_t observed_flags, uint32_t baseline_other)
{
    if (arm != WRIT_AC_DISABLED && arm != WRIT_AC_ENABLED) return 0;
    uint64_t expected = arm == WRIT_AC_DISABLED ? (UINT64_C(1) << 28) : (UINT64_C(2) << 28);
    uint32_t expected_disabled = arm == WRIT_AC_DISABLED ? 1u : 0u;
    /* Bits 1-3 are documented audit/FSCTL settings; any reserved bit is unknown. */
    uint32_t other = observed_flags & ~UINT32_C(1);
    return creation == expected && (observed_flags & 1u) == expected_disabled &&
        !(other & ~UINT32_C(0x0e)) && !(baseline_other & ~UINT32_C(0x0e)) && other == baseline_other;
}
int writ_ac_may_start(size_t index, unsigned int completed_mask, unsigned int failed_mask)
{
    if (index >= WRIT_AC_CASES || failed_mask != 0) return 0;
    return completed_mask == ((1u << index) - 1u);
}
int writ_ac_case_complete(uint32_t passed, uint32_t failed, int timed_out)
{
    return passed == WRIT_AC_CASE_ALL && failed == 0 && timed_out == 0;
}
int writ_ac_can_init(int initialized, int has_resources)
{
    return initialized == 0 && has_resources == 0;
}
int writ_ac_can_launch(int cleanup_uncertain, int child_exit_unverified, int child_has_resources)
{
    return cleanup_uncertain == 0 && child_exit_unverified == 0 && child_has_resources == 0;
}
WRIT_AC_ARM writ_ac_arm(size_t index)
{
    static const WRIT_AC_ARM arms[WRIT_AC_CASES] = { WRIT_AC_DISABLED, WRIT_AC_ENABLED, WRIT_AC_ENABLED, WRIT_AC_DISABLED };
    return index < WRIT_AC_CASES ? arms[index] : (WRIT_AC_ARM)2;
}

int writ_ac_sid_identities_unique(const WRIT_AC_SID *entries, size_t count)
{
    if (!entries || count > WRIT_AC_MAX_TOKEN_ENTRIES) return 0;
    for (size_t i = 0; i < count; ++i) {
        if (entries[i].length < 8 || entries[i].length > WRIT_AC_MAX_SID_BYTES) return 0;
        for (size_t j = 0; j < i; ++j)
            if (entries[i].length == entries[j].length &&
                !memcmp(entries[i].bytes, entries[j].bytes, entries[i].length)) return 0;
    }
    return 1;
}
int writ_ac_privilege_identities_unique(const WRIT_AC_PRIVILEGE *entries, size_t count)
{
    if (!entries || count > WRIT_AC_MAX_TOKEN_ENTRIES) return 0;
    for (size_t i = 0; i < count; ++i)
        for (size_t j = 0; j < i; ++j)
            if (entries[i].high == entries[j].high && entries[i].low == entries[j].low) return 0;
    return 1;
}
