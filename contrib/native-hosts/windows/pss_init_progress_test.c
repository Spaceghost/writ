/* Pure synthetic state and failure classifications; no native API execution. */
#include "pss_init_progress.h"
#include <stdio.h>
int main(void)
{
    if (!writ_pss_init_can_resume(WRIT_INIT_PRE_RESUME, 0)) return 1;
    for (uint32_t bit = 1; bit <= WRIT_INIT_REPORT_OK; bit <<= 1) {
        if ((WRIT_INIT_PRE_RESUME & bit) && writ_pss_init_can_resume(WRIT_INIT_PRE_RESUME & ~bit, 0)) return 2;
        if (writ_pss_init_complete(WRIT_INIT_ALL & ~bit, 0, 0)) return 3;
        if (writ_pss_init_complete(WRIT_INIT_ALL, bit, 0)) return 4;
    }
    if (writ_pss_init_can_resume(WRIT_INIT_PRE_RESUME, WRIT_PSS_SNAPSHOT_FREED)) return 5;
    if (writ_pss_init_can_resume(WRIT_INIT_PRE_RESUME | WRIT_INIT_RESUMED, 0)) return 6;
    if (!writ_pss_init_suspend_ok(1) || writ_pss_init_suspend_ok(0) ||
        writ_pss_init_suspend_ok(2) || writ_pss_init_suspend_ok(UINT32_MAX)) return 7;
    if (!writ_pss_init_complete(WRIT_INIT_ALL, 0, 0) || writ_pss_init_complete(WRIT_INIT_ALL, 0, 1)) return 8;
    if (writ_pss_init_complete(WRIT_INIT_ALL | UINT32_C(8388608), 0, 0)) return 9;
    puts("PASS synthetic same-lifetime PSS initialization progress and failures");
    return 0;
}
