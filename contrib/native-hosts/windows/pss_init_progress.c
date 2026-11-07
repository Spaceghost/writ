#include "pss_init_progress.h"
int writ_pss_init_can_resume(uint32_t passed, uint32_t failed)
{
    return (passed & WRIT_INIT_PRE_RESUME) == WRIT_INIT_PRE_RESUME && failed == 0 &&
        (passed & ~WRIT_INIT_PRE_RESUME) == 0;
}
int writ_pss_init_suspend_ok(uint32_t previous_count)
{
    return previous_count == 1;
}
int writ_pss_init_complete(uint32_t passed, uint32_t failed, int timed_out)
{
    return passed == WRIT_INIT_ALL && failed == 0 && timed_out == 0;
}
