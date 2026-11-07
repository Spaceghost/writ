/* Reuse the unchanged launcher while marking all of its stdout as diagnostic. */
#include <stdio.h>
#include <stdarg.h>
static int writ_init_printf(const char *format, ...)
{
    va_list args;
    int result;
    fputs("NO_DATA_LAUNCH ", stdout);
    va_start(args, format);
    result = vfprintf(stdout, format, args);
    va_end(args);
    return result;
}
#define printf writ_init_printf
#include "worker.c"
