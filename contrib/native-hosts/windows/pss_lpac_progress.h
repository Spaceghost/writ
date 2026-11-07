#ifndef WRIT_WINDOWS_PSS_LPAC_PROGRESS_H
#define WRIT_WINDOWS_PSS_LPAC_PROGRESS_H
#include <stdint.h>
#include "pss_progress.h"
#define WRIT_LPAC_LAUNCH_OK UINT32_C(8192)
#define WRIT_LPAC_WFP_CLOSED UINT32_C(16384)
#define WRIT_LPAC_WFP_ABSENT UINT32_C(32768)
#define WRIT_LPAC_IMAGE_REMOVED UINT32_C(65536)
#define WRIT_LPAC_PROFILE_REMOVED UINT32_C(131072)
#define WRIT_LPAC_SID_FREED UINT32_C(262144)
#define WRIT_LPAC_ALL (WRIT_PSS_ALL | WRIT_LPAC_LAUNCH_OK | WRIT_LPAC_WFP_CLOSED | \
    WRIT_LPAC_WFP_ABSENT | WRIT_LPAC_IMAGE_REMOVED | WRIT_LPAC_PROFILE_REMOVED | WRIT_LPAC_SID_FREED)

/* Missing, failed or timed-out phases always leave the observation incomplete. */
int writ_lpac_complete(uint32_t passed, uint32_t failed, int timed_out);
int writ_lpac_may_release_owned_controls(int child_exit_observed);
#endif
