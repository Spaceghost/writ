/* Synthetic failure classifications; no Windows API invocation. */
#include "pss_lpac_progress.h"
#include <stdio.h>
int main(void)
{
    if (!writ_lpac_complete(WRIT_LPAC_ALL, 0, 0)) return 1;
    for (uint32_t bit = 1; bit <= WRIT_LPAC_SID_FREED; bit <<= 1) {
        if (writ_lpac_complete(WRIT_LPAC_ALL & ~bit, 0, 0)) return 2;
        if (writ_lpac_complete(WRIT_LPAC_ALL, bit, 0)) return 3;
    }
    if (writ_lpac_complete(WRIT_LPAC_ALL, 0, 1)) return 4;
    if (writ_lpac_complete(WRIT_LPAC_ALL | UINT32_C(524288), 0, 0)) return 5;
    if (writ_lpac_complete(WRIT_LPAC_LAUNCH_OK | WRIT_PSS_CAPTURE_OK, 0, 0)) return 6;
    if (!writ_lpac_may_release_owned_controls(1) || writ_lpac_may_release_owned_controls(0) ||
        writ_lpac_may_release_owned_controls(-1) || writ_lpac_may_release_owned_controls(2)) return 7;
    puts("PASS synthetic LPAC PSS missing-phase, failure, timeout and cleanup-order classification");
    return 0;
}
