/* Synthetic validation only; this does not inspect Windows. */
#include "pss_table.h"
#include <stdio.h>
int main(void)
{
    uint64_t values[WRIT_PSS_MAX_HANDLES + 1] = { 16, 24, 32 };
    if (writ_pss_check(values, 2, 2, 2, 2, 1, 16, 24, 40) != WRIT_PSS_MATCH) return 1;
    if (writ_pss_check(values, 1, 1, 1, 1, 1, 16, 24, 40) != WRIT_PSS_MISSING) return 2;
    if (writ_pss_check(values, 3, 3, 3, 3, 1, 16, 24, 40) != WRIT_PSS_EXTRA) return 3;
    if (writ_pss_check(values, 3, 3, 3, 3, 1, 16, 24, 32) != WRIT_PSS_UNEXPECTED) return 4;
    if (writ_pss_check(values, 2, 3, 3, 3, 1, 16, 24, 40) != WRIT_PSS_INVALID) return 5;
    if (writ_pss_check(values, WRIT_PSS_MAX_HANDLES + 1, WRIT_PSS_MAX_HANDLES + 1, WRIT_PSS_MAX_HANDLES + 1, WRIT_PSS_MAX_HANDLES + 1, 1, 16, 24, 40) != WRIT_PSS_INVALID) return 6;
    values[1] = 16; if (writ_pss_check(values, 2, 2, 2, 2, 1, 16, 24, 40) != WRIT_PSS_INVALID) return 7;
    values[1] = 0; if (writ_pss_check(values, 2, 2, 2, 2, 1, 16, 24, 40) != WRIT_PSS_INVALID) return 8;
    values[1] = UINT64_MAX; if (writ_pss_check(values, 2, 2, 2, 2, 1, 16, 24, 40) != WRIT_PSS_INVALID) return 9;
    values[1] = 24; if (writ_pss_check(NULL, 2, 2, 2, 2, 1, 16, 24, 40) != WRIT_PSS_INVALID) return 10;
    if (writ_pss_check(values, 2, 2, 2, 2, 1, 16, 16, 40) != WRIT_PSS_INVALID) return 11;
    if (writ_pss_check(values, 2, 2, 2, 2, 1, 16, 24, 16) != WRIT_PSS_INVALID) return 12;
    if (writ_pss_check(values, 2, 2, 2, 2, 1, UINT64_MAX, 24, 40) != WRIT_PSS_INVALID) return 13;
    if (writ_pss_check(values, 2, 2, 2, 2, 0, 16, 24, 40) != WRIT_PSS_INVALID) return 14;
    if (writ_pss_check(values, 2, 2, 1, 2, 1, 16, 24, 40) != WRIT_PSS_INVALID) return 15;
    if (writ_pss_check(values, 2, 2, 2, 3, 1, 16, 24, 40) != WRIT_PSS_INVALID) return 16;
    puts("PASS synthetic bounded handle-table checks");
    return 0;
}
