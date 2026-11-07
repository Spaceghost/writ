#include "registry_ab_checks.h"
#include <string.h>
int writ_ab_capabilities(WRIT_AB_ARM arm, uint32_t count, int sid_matches, int enabled)
{
    if (arm == WRIT_AB_ZERO) return count == 0 && sid_matches == 0 && enabled == 0;
    if (arm == WRIT_AB_REGISTRY) return count == 1 && sid_matches == 1 && enabled == 1;
    return 0;
}
int writ_ab_may_start(size_t index, unsigned int completed_mask, unsigned int failed_mask)
{
    if (index >= WRIT_AB_CASES || failed_mask != 0) return 0;
    return completed_mask == ((1u << index) - 1u);
}
int writ_ab_case_complete(uint32_t passed, uint32_t failed, int timed_out)
{
    return passed == WRIT_AB_CASE_ALL && failed == 0 && timed_out == 0;
}
int writ_ab_can_init(int initialized, int has_resources)
{
    return initialized == 0 && has_resources == 0;
}
int writ_ab_can_launch(int cleanup_uncertain, int child_exit_unverified, int child_has_resources)
{
    return cleanup_uncertain == 0 && child_exit_unverified == 0 && child_has_resources == 0;
}
WRIT_AB_ARM writ_ab_arm(size_t index)
{
    static const WRIT_AB_ARM arms[WRIT_AB_CASES] = { WRIT_AB_ZERO, WRIT_AB_REGISTRY, WRIT_AB_REGISTRY, WRIT_AB_ZERO };
    return index < WRIT_AB_CASES ? arms[index] : (WRIT_AB_ARM)2;
}

int writ_ab_sid_identities_unique(const WRIT_AB_SID *entries, size_t count)
{
    if (!entries || count > WRIT_AB_MAX_TOKEN_ENTRIES) return 0;
    for (size_t i = 0; i < count; ++i) {
        if (entries[i].length < 8 || entries[i].length > WRIT_AB_MAX_SID_BYTES) return 0;
        for (size_t j = 0; j < i; ++j)
            if (entries[i].length == entries[j].length &&
                !memcmp(entries[i].bytes, entries[j].bytes, entries[i].length)) return 0;
    }
    return 1;
}
int writ_ab_privilege_identities_unique(const WRIT_AB_PRIVILEGE *entries, size_t count)
{
    if (!entries || count > WRIT_AB_MAX_TOKEN_ENTRIES) return 0;
    for (size_t i = 0; i < count; ++i)
        for (size_t j = 0; j < i; ++j)
            if (entries[i].high == entries[j].high && entries[i].low == entries[j].low) return 0;
    return 1;
}
