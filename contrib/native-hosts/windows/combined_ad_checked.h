#ifndef WRIT_WINDOWS_COMBINED_AD_CHECKED_H
#define WRIT_WINDOWS_COMBINED_AD_CHECKED_H
#include "worker.h"
/* Diagnostic-only native preparation with checked status-bearing cleanup. */
BOOL writ_ad_reduced_primary(HANDLE *result, BYTE *user);
BOOL writ_ad_image_identity(WRIT_WORKER *worker, const wchar_t *image);
BOOL writ_ad_private_image(WRIT_WORKER *worker);
#endif
