#ifndef WRIT_WINDOWS_COMBINED_AD_CHECKS_H
#define WRIT_WINDOWS_COMBINED_AD_CHECKS_H
#include <stddef.h>
#include <stdint.h>
#include "pss_init_progress.h"
#define WRIT_AD_CASES 4u
#define WRIT_AD_MAX_TOKEN_ENTRIES 64u
#define WRIT_AD_MAX_SID_BYTES 68u
#define WRIT_AD_TOKEN_OK UINT32_C(8388608)
#define WRIT_AD_WFP_CHECK_FAILED UINT32_C(16777216)
#define WRIT_AD_CASE_ALL ((WRIT_INIT_ALL & ~(WRIT_LPAC_WFP_CLOSED | WRIT_LPAC_WFP_ABSENT | \
    WRIT_LPAC_IMAGE_REMOVED | WRIT_LPAC_PROFILE_REMOVED | WRIT_LPAC_SID_FREED | WRIT_PSS_COMPARE_RELEASED)) | WRIT_AD_TOKEN_OK)

typedef struct {
    uint32_t length, attributes;
    uint8_t bytes[WRIT_AD_MAX_SID_BYTES];
} WRIT_AD_SID;
typedef struct {
    int32_t high;
    uint32_t low, attributes;
} WRIT_AD_PRIVILEGE;

typedef enum { WRIT_AD_ZERO = 0, WRIT_AD_COMBINED = 1 } WRIT_AD_ARM;
/* Diagnostic classification only: no Writ authority or data decision. */
int writ_ad_capabilities(WRIT_AD_ARM arm, uint32_t count, int sid_matches, int enabled);
int writ_ad_mitigation(WRIT_AD_ARM arm, uint64_t creation, uint32_t observed_flags, uint32_t baseline_other);
int writ_ad_may_start(size_t index, unsigned int completed_mask, unsigned int failed_mask);
int writ_ad_case_complete(uint32_t passed, uint32_t failed, int timed_out);
int writ_ad_can_init(int initialized, int has_resources);
int writ_ad_can_launch(int cleanup_uncertain, int child_exit_unverified, int child_has_resources);
WRIT_AD_ARM writ_ad_arm(size_t index);
/* Identity uniqueness ignores attributes; differing attributes are ambiguous. */
int writ_ad_sid_identities_unique(const WRIT_AD_SID *entries, size_t count);
int writ_ad_privilege_identities_unique(const WRIT_AD_PRIVILEGE *entries, size_t count);
#endif
