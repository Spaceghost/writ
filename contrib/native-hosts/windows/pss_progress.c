#include "pss_progress.h"
int writ_pss_complete(uint32_t passed, uint32_t failed)
{
    return passed == WRIT_PSS_ALL && failed == 0;
}
