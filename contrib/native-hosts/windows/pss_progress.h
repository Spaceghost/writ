#ifndef WRIT_WINDOWS_PSS_PROGRESS_H
#define WRIT_WINDOWS_PSS_PROGRESS_H
#include <stdint.h>
#define WRIT_PSS_CAPTURE_OK UINT32_C(1)
#define WRIT_PSS_QUERY_OK UINT32_C(2)
#define WRIT_PSS_MARKER_OK UINT32_C(4)
#define WRIT_PSS_WALK_OK UINT32_C(8)
#define WRIT_PSS_LIFETIME_OK UINT32_C(16)
#define WRIT_PSS_TABLE_OK UINT32_C(32)
#define WRIT_PSS_OBJECTS_OK UINT32_C(64)
#define WRIT_PSS_MARKER_FREED UINT32_C(128)
#define WRIT_PSS_SNAPSHOT_FREED UINT32_C(256)
#define WRIT_PSS_CHILD_RETIRED UINT32_C(512)
#define WRIT_PSS_HANDLES_CLOSED UINT32_C(1024)
#define WRIT_PSS_ALL UINT32_C(2047)

/* Missing, failed, or unknown facts always prevent a complete observation. */
int writ_pss_complete(uint32_t passed, uint32_t failed);
#endif
