#include "pss_lpac_progress.h"
int writ_lpac_complete(uint32_t passed, uint32_t failed, int timed_out)
{
    return passed == WRIT_LPAC_ALL && failed == 0 && timed_out == 0;
}

/* Do not explicitly release the child's WFP or profile resources while it may live. */
int writ_lpac_may_release_owned_controls(int child_exit_observed)
{
    return child_exit_observed == 1;
}
