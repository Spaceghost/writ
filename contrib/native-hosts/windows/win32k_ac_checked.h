#ifndef WRIT_WINDOWS_WIN32K_AC_CHECKED_H
#define WRIT_WINDOWS_WIN32K_AC_CHECKED_H
#include "worker.h"
/* Diagnostic-only native preparation with checked status-bearing cleanup. */
BOOL writ_ac_reduced_primary(HANDLE *result, BYTE *user);
BOOL writ_ac_image_identity(WRIT_WORKER *worker, const wchar_t *image);
BOOL writ_ac_private_image(WRIT_WORKER *worker);
#endif
