#ifndef WRIT_WINDOWS_WIN32K_AC_CHECKS_H
#define WRIT_WINDOWS_WIN32K_AC_CHECKS_H
#include <stddef.h>
#include <stdint.h>
#include "pss_init_progress.h"
#define WRIT_AC_CASES 4u
#define WRIT_AC_MAX_TOKEN_ENTRIES 64u
#define WRIT_AC_MAX_SID_BYTES 68u
#define WRIT_AC_TOKEN_OK UINT32_C(8388608)
#define WRIT_AC_WFP_CHECK_FAILED UINT32_C(16777216)
#define WRIT_AC_CASE_ALL ((WRIT_INIT_ALL & ~(WRIT_LPAC_WFP_CLOSED | WRIT_LPAC_WFP_ABSENT | \
    WRIT_LPAC_IMAGE_REMOVED | WRIT_LPAC_PROFILE_REMOVED | WRIT_LPAC_SID_FREED | WRIT_PSS_COMPARE_RELEASED)) | WRIT_AC_TOKEN_OK)

typedef struct {
    uint32_t length, attributes;
    uint8_t bytes[WRIT_AC_MAX_SID_BYTES];
} WRIT_AC_SID;
typedef struct {
    int32_t high;
    uint32_t low, attributes;
} WRIT_AC_PRIVILEGE;

typedef enum { WRIT_AC_DISABLED = 0, WRIT_AC_ENABLED = 1 } WRIT_AC_ARM;
/* Diagnostic classification only: no Writ authority or data decision. */
int writ_ac_capabilities(uint32_t count);
int writ_ac_mitigation(WRIT_AC_ARM arm, uint64_t creation, uint32_t observed_flags, uint32_t baseline_other);
int writ_ac_may_start(size_t index, unsigned int completed_mask, unsigned int failed_mask);
int writ_ac_case_complete(uint32_t passed, uint32_t failed, int timed_out);
int writ_ac_can_init(int initialized, int has_resources);
int writ_ac_can_launch(int cleanup_uncertain, int child_exit_unverified, int child_has_resources);
WRIT_AC_ARM writ_ac_arm(size_t index);
/* Identity uniqueness ignores attributes; differing attributes are ambiguous. */
int writ_ac_sid_identities_unique(const WRIT_AC_SID *entries, size_t count);
int writ_ac_privilege_identities_unique(const WRIT_AC_PRIVILEGE *entries, size_t count);
#endif
