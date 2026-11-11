#include "../policy_pipe.h"

/* Link-time binding for this PUBLIC fixture executable only. Ordinary per-user
   process ownership is appropriate here. The protected WinFsp executable still
   links isolation.c and its original Administrators/SYSTEM process descriptor. */
BOOL writ_process_security(SECURITY_ATTRIBUTES *attributes)
{
    ZeroMemory(attributes, sizeof(*attributes));
    attributes->nLength = sizeof(*attributes);
    return TRUE;
}
