/* Portable synthetic framing/control tests, not native confinement evidence. */
#include "init_report.h"
#include <stdio.h>

int main(void)
{
    WRIT_INIT_REPORT r = {0};
    r.magic = WRIT_INIT_MAGIC; r.version = WRIT_INIT_VERSION; r.size = sizeof(r);
    if (!writ_init_positive(&r, sizeof(r)) || writ_init_report_valid(&r, sizeof(r)-1) ||
        writ_init_report_valid(&r, sizeof(r)+1) || writ_init_report_valid(NULL, sizeof(r))) return 1;
    r.magic = 0; if (writ_init_report_valid(&r, sizeof(r))) return 2;
    r.magic = WRIT_INIT_MAGIC; r.version++; if (writ_init_report_valid(&r, sizeof(r))) return 3;
    r.version = WRIT_INIT_VERSION; r.size--; if (writ_init_report_valid(&r, sizeof(r))) return 4;
    r.size = sizeof(r); r.winsock = 10107; if (writ_init_positive(&r, sizeof(r))) return 5;
    r.winsock = 0; r.load_failures = 1; r.user32 = 1114; if (writ_init_positive(&r, sizeof(r))) return 6;
    r.user32 = 0; r.load_failures = 2; r.ole32 = 1359; if (writ_init_positive(&r, sizeof(r))) return 7;
    if (!writ_init_report_valid(&r, sizeof(r))) return 8;
    r.load_failures = 4; if (writ_init_report_valid(&r, sizeof(r))) return 9;
    r.load_failures = 1; r.ole32 = 0; if (writ_init_positive(&r, sizeof(r))) return 10;
    r.load_failures = 0; r.user32 = 1114; if (writ_init_report_valid(&r, sizeof(r))) return 11;
    r.user32 = 0; r.initial_modules = 1; if (writ_init_positive(&r, sizeof(r))) return 12;
    r.initial_modules = 4; if (writ_init_report_valid(&r, sizeof(r))) return 13;
    r.initial_modules = 0; r.after_winsock_modules = 1; if (writ_init_cold(&r, sizeof(r))) return 14;
    r.after_winsock_modules = 2; if (writ_init_cold(&r, sizeof(r))) return 15;
    r.after_winsock_modules = 0; r.pre_ole32_modules = 2; if (writ_init_cold(&r, sizeof(r))) return 16;
    r.pre_ole32_modules = 1; if (!writ_init_cold(&r, sizeof(r))) return 17;
    r.cleanup_failures = 1; if (writ_init_positive(&r, sizeof(r))) return 18;
    r.cleanup_failures = 8; if (writ_init_report_valid(&r, sizeof(r))) return 19;
    puts("PASS no-data initialization report framing and positive-control errors");
    return 0;
}
