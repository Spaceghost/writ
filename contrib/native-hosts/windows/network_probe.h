#ifndef WRIT_WINDOWS_NETWORK_PROBE_H
#define WRIT_WINDOWS_NETWORK_PROBE_H

#include <winsock2.h>
#include "probe.h"

/* Fixed public-canary loopback probes; the broker owns all four receiver ports.
 * Reports are diagnostic outputs, never authority or a complete host profile. */
void writ_network_checks(WRIT_PROBE_REPORT *report, const unsigned short ports[4]);

/* Validate the diagnostic claim at the receiving side as well. The fixed
 * private report still needs the caller's exact size, phase and mask checks. */
static inline int writ_network_report_valid(const WRIT_PROBE_REPORT *report, unsigned int expected)
{
    if (report->magic != WRIT_PROBE_MAGIC) return 0;
    if (!(expected & WRIT_PROBE_NETWORK_MASK) && report->network_startup_error) return 0;
    for (unsigned int i = 0; i < 4; ++i) {
        unsigned int bit = WRIT_PROBE_TCP4 << i;
        unsigned int stage = report->network_stage[i], error = report->errors[7 + i];
        if (!(expected & bit)) {
            if (stage != WRIT_NETWORK_NOT_RUN || error) return 0;
            continue;
        }
        int denied = 0;
        if (report->network_startup_error) {
            if (stage != WRIT_NETWORK_STARTUP || error) return 0;
        } else {
            if (stage < WRIT_NETWORK_SOCKET || stage > WRIT_NETWORK_CONNECT_RESULT) return 0;
            denied = error == WSAEACCES &&
                (stage == WRIT_NETWORK_SOCKET || stage == WRIT_NETWORK_SENDTO ||
                 stage == WRIT_NETWORK_CONNECT || stage == WRIT_NETWORK_CONNECT_RESULT);
            /* TCP cannot report a datagram send; UDP has no connection wait. */
            if ((i < 2 && stage == WRIT_NETWORK_SENDTO) ||
                (i >= 2 && stage >= WRIT_NETWORK_CONNECT)) return 0;
        }
        if (!!(report->passed & bit) != denied || !!(report->failed & bit) == denied) return 0;
    }
    return 1;
}

#endif
