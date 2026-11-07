/* Synthetic comparison of snapshot validation; no live Windows token. */
#include "registry_ab_token.h"
#include <stdio.h>
int main(void)
{
    WRIT_AB_TOKEN a = {0}, b = {0};
    if (writ_ab_token_ordinary_primary(NULL, NULL)) return 11;
    if (writ_ab_token_equal_except_capabilities(&a, &b)) return 1;
    a.magic = b.magic = WRIT_AB_TOKEN_MAGIC;
    if (writ_ab_token_equal_except_capabilities(&a, &b)) return 2;
    a.user.length = b.user.length = 8;
    a.integrity.length = b.integrity.length = 8;
    a.package.length = b.package.length = 8;
    a.user.bytes[0] = b.user.bytes[0] = 1;
    a.integrity.bytes[0] = b.integrity.bytes[0] = 2;
    a.package.bytes[0] = b.package.bytes[0] = 4;
    if (!writ_ab_token_equal_except_capabilities(&a, &b)) return 3;
    b.capability_count = 1; b.capabilities[0].length = 8; b.capabilities[0].attributes = 4;
    if (!writ_ab_token_equal_except_capabilities(&a, &b)) return 8;
    WRIT_AB_TOKEN previous = a;
    if (writ_ab_token_snapshot(NULL, &a) || writ_ab_token_equal_except_capabilities(&a, &previous) || a.magic != 0) return 7;
    a = previous;
    b.elevated = 1;
    if (writ_ab_token_equal_except_capabilities(&a, &b)) return 4;
    b.elevated = 0;
    a.groups_count = b.groups_count = 1;
    a.groups[0].length = b.groups[0].length = 8;
    a.groups[0].bytes[0] = b.groups[0].bytes[0] = 3;
    if (!writ_ab_token_equal_except_capabilities(&a, &b)) return 9;
    b.groups[0].attributes = 4;
    if (writ_ab_token_equal_except_capabilities(&a, &b)) return 10;
    b.groups[0].attributes = 0; b.magic = 0;
    if (writ_ab_token_equal_except_capabilities(&a, &b)) return 5;
    b.magic = WRIT_AB_TOKEN_MAGIC; b.groups_count = WRIT_AB_MAX_TOKEN_ENTRIES + 1;
    if (writ_ab_token_equal_except_capabilities(&a, &b)) return 6;
    puts("PASS synthetic token snapshot validity and equality");
    return 0;
}
