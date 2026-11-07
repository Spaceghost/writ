#ifndef WRIT_WINDOWS_PSS_INIT_PIPE_H
#define WRIT_WINDOWS_PSS_INIT_PIPE_H
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include "init_report.h"
/* After the retained child exits and the parent writer closes, require exactly
   one structurally valid initializer report followed by pipe EOF. No blocking EOF read. */
BOOL writ_pss_init_read_report(HANDLE input, WRIT_INIT_REPORT *report, DWORD *error);
#endif
