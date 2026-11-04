#ifndef WRIT_WINDOWS_POLICY_PIPE_H
#define WRIT_WINDOWS_POLICY_PIPE_H

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stddef.h>

/* Private broker-to-generated-Bend transport, never a worker endpoint. */
#define WRIT_POLICY_FRAME_MAX (2 * 65536 + 1024)
typedef struct {
    HANDLE process, job, input, output;
    CRITICAL_SECTION lock;
    BOOL lock_ready, failed;
} WRIT_POLICY_PIPE;

BOOL writ_policy_start(WRIT_POLICY_PIPE *pipe, const wchar_t *node,
    const wchar_t *bridge, const wchar_t *module);
BOOL writ_policy_exchange(WRIT_POLICY_PIPE *pipe, const char *request,
    char *response, size_t capacity);
void writ_policy_stop(WRIT_POLICY_PIPE *pipe);

#endif
