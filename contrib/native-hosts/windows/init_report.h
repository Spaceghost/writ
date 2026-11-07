#ifndef WRIT_WINDOWS_INIT_REPORT_H
#define WRIT_WINDOWS_INIT_REPORT_H

#include <stdint.h>
#include <stddef.h>

#define WRIT_INIT_MAGIC UINT32_C(0x57494e49)
#define WRIT_INIT_VERSION UINT32_C(1)

typedef struct {
    uint32_t magic, version, size;
    uint32_t initial_modules, after_winsock_modules, pre_ole32_modules;
    uint32_t winsock, load_failures, cleanup_failures, user32, ole32;
} WRIT_INIT_REPORT;

/* Transport validation only; this deliberately cannot grant restriction credit. */
static int writ_init_report_valid(const WRIT_INIT_REPORT *report, size_t received)
{
    return report && received == sizeof(*report) && report->magic == WRIT_INIT_MAGIC &&
        report->version == WRIT_INIT_VERSION && report->size == sizeof(*report) &&
        !(report->load_failures & ~UINT32_C(3)) &&
        !(report->cleanup_failures & ~UINT32_C(7)) &&
        !(report->initial_modules & ~UINT32_C(3)) &&
        !(report->after_winsock_modules & ~UINT32_C(3)) &&
        !(report->pre_ole32_modules & ~UINT32_C(3)) &&
        ((report->load_failures & UINT32_C(1)) || !report->user32) &&
        ((report->load_failures & UINT32_C(2)) || !report->ole32);
}

static int writ_init_cold(const WRIT_INIT_REPORT *report, size_t received)
{
    return writ_init_report_valid(report, received) && !report->initial_modules &&
        !report->after_winsock_modules && !(report->pre_ole32_modules & UINT32_C(2));
}

static int writ_init_positive(const WRIT_INIT_REPORT *report, size_t received)
{
    return writ_init_cold(report, received) && !report->cleanup_failures && !report->winsock &&
        !report->load_failures && !report->user32 && !report->ole32;
}
#endif
