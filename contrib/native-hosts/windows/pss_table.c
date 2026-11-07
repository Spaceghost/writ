#include "pss_table.h"

WRIT_PSS_RESULT writ_pss_check(const uint64_t *values, size_t read,
    size_t reported, size_t before, size_t after, int walk_complete,
    uint64_t first, uint64_t second, uint64_t excluded)
{
    unsigned int found_first = 0, found_second = 0;
    if (!values || !walk_complete || read != reported || before != reported || after != reported ||
        read > WRIT_PSS_MAX_HANDLES ||
        !first || !second || !excluded || first == UINT64_MAX || second == UINT64_MAX ||
        excluded == UINT64_MAX || first == second || first == excluded || second == excluded)
        return WRIT_PSS_INVALID;
    for (size_t i = 0; i < read; ++i) {
        if (!values[i] || values[i] == UINT64_MAX) return WRIT_PSS_INVALID;
        for (size_t j = 0; j < i; ++j)
            if (values[j] == values[i]) return WRIT_PSS_INVALID;
        if (values[i] == first) found_first = 1;
        if (values[i] == second) found_second = 1;
        if (values[i] == excluded) return WRIT_PSS_UNEXPECTED;
    }
    if (!found_first || !found_second) return WRIT_PSS_MISSING;
    return read == 2 ? WRIT_PSS_MATCH : WRIT_PSS_EXTRA;
}
