#ifndef WRIT_WINDOWS_REGISTRY_AB_CHECKS_H
#define WRIT_WINDOWS_REGISTRY_AB_CHECKS_H
#include <stddef.h>
#include <stdint.h>
#include "pss_init_progress.h"
#define WRIT_AB_CASES 4u
#define WRIT_AB_MAX_TOKEN_ENTRIES 64u
#define WRIT_AB_MAX_SID_BYTES 68u
#define WRIT_AB_TOKEN_OK UINT32_C(8388608)
#define WRIT_AB_WFP_CHECK_FAILED UINT32_C(16777216)
#define WRIT_AB_CASE_ALL ((WRIT_INIT_ALL & ~(WRIT_LPAC_WFP_CLOSED | WRIT_LPAC_WFP_ABSENT | \
    WRIT_LPAC_IMAGE_REMOVED | WRIT_LPAC_PROFILE_REMOVED | WRIT_LPAC_SID_FREED | WRIT_PSS_COMPARE_RELEASED)) | WRIT_AB_TOKEN_OK)

typedef struct {
    uint32_t length, attributes;
    uint8_t bytes[WRIT_AB_MAX_SID_BYTES];
} WRIT_AB_SID;
typedef struct {
    int32_t high;
    uint32_t low, attributes;
} WRIT_AB_PRIVILEGE;

typedef enum { WRIT_AB_ZERO = 0, WRIT_AB_REGISTRY = 1 } WRIT_AB_ARM;
/* Diagnostic classification only: no Writ authority or data decision. */
int writ_ab_capabilities(WRIT_AB_ARM arm, uint32_t count, int sid_matches, int enabled);
int writ_ab_may_start(size_t index, unsigned int completed_mask, unsigned int failed_mask);
int writ_ab_case_complete(uint32_t passed, uint32_t failed, int timed_out);
int writ_ab_can_init(int initialized, int has_resources);
int writ_ab_can_launch(int cleanup_uncertain, int child_exit_unverified, int child_has_resources);
WRIT_AB_ARM writ_ab_arm(size_t index);
/* Identity uniqueness ignores attributes; differing attributes are ambiguous. */
int writ_ab_sid_identities_unique(const WRIT_AB_SID *entries, size_t count);
int writ_ab_privilege_identities_unique(const WRIT_AB_PRIVILEGE *entries, size_t count);
#endif
