#include "pss_progress.h"
#include <stdio.h>
int main(void)
{
    if (!writ_pss_complete(WRIT_PSS_ALL, 0)) return 1;
    for (uint32_t bit = 1; bit <= WRIT_PSS_HANDLES_CLOSED; bit <<= 1) {
        if (writ_pss_complete(WRIT_PSS_ALL & ~bit, 0)) return 2;
        if (writ_pss_complete(WRIT_PSS_ALL, bit)) return 3;
    }
    if (writ_pss_complete(WRIT_PSS_ALL | UINT32_C(4096), 0)) return 4;
    if (writ_pss_complete(WRIT_PSS_CAPTURE_OK | WRIT_PSS_QUERY_OK, 0)) return 5;
    puts("PASS synthetic incomplete capture, walk, identity and cleanup outcomes");
    return 0;
}
