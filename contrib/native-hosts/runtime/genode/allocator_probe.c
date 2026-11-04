#include "allocator_checks.h"
#include <stdio.h>

int main(void)
{
    int const count = writ_qjs_allocator_checks();
    if (count != WRIT_QJS_ALLOCATOR_CHECKS) {
        fprintf(stderr, "FAIL native allocator checks: %d\n", count);
        return 1;
    }
    printf("PASS allocator invariants: %d\n", count);
    return 0;
}
