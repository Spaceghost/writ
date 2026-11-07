/* Windows no-data anonymous-pipe controls, not confinement evidence. */
#include "pss_init_pipe.h"
#include <stdio.h>

static int run_case(DWORD bytes, BOOL extra, BOOL close_writer, BOOL corrupt, BOOL expected)
{
    HANDLE input = NULL, output = NULL;
    WRIT_INIT_REPORT sent = {0}, received = {0};
    DWORD written = 0, error = 0;
    BOOL ok = FALSE, result = FALSE;
    sent.magic = corrupt ? 0 : WRIT_INIT_MAGIC; sent.version = WRIT_INIT_VERSION; sent.size = sizeof(sent);
    if (!CreatePipe(&input, &output, NULL, 0)) {
        input = NULL; output = NULL; /* Failed CreatePipe outputs are indeterminate. */
        goto done;
    }
    if (!WriteFile(output, &sent, bytes, &written, NULL) || written != bytes) goto done;
    if (extra && (!WriteFile(output, "x", 1, &written, NULL) || written != 1)) goto done;
    if (close_writer) { if (!CloseHandle(output)) goto done; output = NULL; }
    result = writ_pss_init_read_report(input, &received, &error);
    ok = result == expected;
done:
    if (output && !CloseHandle(output)) ok = FALSE;
    if (input && !CloseHandle(input)) ok = FALSE;
    return ok;
}
int main(void)
{
    if (!run_case(sizeof(WRIT_INIT_REPORT), FALSE, TRUE, FALSE, TRUE)) return 1;
    if (!run_case(sizeof(WRIT_INIT_REPORT), TRUE, TRUE, FALSE, FALSE)) return 2;
    if (!run_case(sizeof(WRIT_INIT_REPORT), FALSE, FALSE, FALSE, FALSE)) return 3;
    if (!run_case(sizeof(WRIT_INIT_REPORT)-1, FALSE, TRUE, FALSE, FALSE)) return 4;
    if (!run_case(sizeof(WRIT_INIT_REPORT), FALSE, TRUE, TRUE, FALSE)) return 5;
    puts("PASS Windows synthetic one-report, trailing, open-writer, truncated and malformed pipe cases");
    return 0;
}
