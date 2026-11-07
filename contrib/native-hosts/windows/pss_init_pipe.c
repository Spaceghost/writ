#include "pss_init_pipe.h"

BOOL writ_pss_init_read_report(HANDLE input, WRIT_INIT_REPORT *report, DWORD *error)
{
    DWORD available = 0, got = 0;
    if (!report || !error) return FALSE;
    *error = ERROR_SUCCESS;
    if (!PeekNamedPipe(input, NULL, 0, NULL, &available, NULL)) { *error = GetLastError(); return FALSE; }
    if (available != sizeof(*report)) { *error = ERROR_INVALID_DATA; return FALSE; }
    if (!ReadFile(input, report, sizeof(*report), &got, NULL)) { *error = GetLastError(); return FALSE; }
    if (got != sizeof(*report) || !writ_init_report_valid(report, got)) {
        *error = ERROR_INVALID_DATA; return FALSE;
    }
    available = 0;
    if (PeekNamedPipe(input, NULL, 0, NULL, &available, NULL)) {
        *error = ERROR_INVALID_DATA; return FALSE;
    }
    DWORD pipe_error = GetLastError();
    if (pipe_error != ERROR_BROKEN_PIPE) { *error = pipe_error; return FALSE; }
    return TRUE;
}
