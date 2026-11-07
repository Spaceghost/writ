#define _WIN32_WINNT 0x0A00
#include "combined_ad_token.h"
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
_Static_assert(WRIT_AD_MAX_SID_BYTES >= SECURITY_MAX_SID_SIZE, "SID buffer must cover Windows maximum");

/* GetTokenInformation results are trusted OS output, never caller pointers.
   Bound each SID inside the returned buffer before using SID APIs. */
static BOOL copy_sid(const BYTE *base, DWORD length, PSID source, DWORD attributes, WRIT_AD_SID *out)
{
    uintptr_t start = (uintptr_t)base, ptr = (uintptr_t)source;
    size_t offset, size;
    if (!source || ptr < start) return FALSE;
    offset = (size_t)(ptr - start);
    if (offset > length || length - offset < offsetof(SID, SubAuthority)) return FALSE;
    SID *sid = (SID *)source;
    if (sid->SubAuthorityCount > SID_MAX_SUB_AUTHORITIES) return FALSE;
    size = offsetof(SID, SubAuthority) + (size_t)sid->SubAuthorityCount * sizeof(DWORD);
    if (size > SECURITY_MAX_SID_SIZE || size > length - offset || !IsValidSid(source) || GetLengthSid(source) != size) return FALSE;
    ZeroMemory(out, sizeof(*out));
    out->length = (DWORD)size; out->attributes = attributes;
    memcpy(out->bytes, source, size);
    return TRUE;
}

static int sid_compare(const void *left, const void *right)
{
    const WRIT_AD_SID *a = (const WRIT_AD_SID *)left, *b = (const WRIT_AD_SID *)right;
    if (a->length != b->length) return a->length < b->length ? -1 : 1;
    int cmp = memcmp(a->bytes, b->bytes, a->length);
    if (cmp) return cmp;
    return a->attributes == b->attributes ? 0 : (a->attributes < b->attributes ? -1 : 1);
}
static int privilege_compare(const void *left, const void *right)
{
    const WRIT_AD_PRIVILEGE *a = (const WRIT_AD_PRIVILEGE *)left, *b = (const WRIT_AD_PRIVILEGE *)right;
    if (a->high != b->high) return a->high < b->high ? -1 : 1;
    if (a->low != b->low) return a->low < b->low ? -1 : 1;
    return a->attributes == b->attributes ? 0 : (a->attributes < b->attributes ? -1 : 1);
}

static BOOL groups(HANDLE token, TOKEN_INFORMATION_CLASS kind, WRIT_AD_SID *out, DWORD *count)
{
    union { ULONGLONG alignment; BYTE bytes[32768]; } storage;
    DWORD needed = 0;
    if (!GetTokenInformation(token, kind, storage.bytes, sizeof(storage.bytes), &needed) ||
        needed > sizeof(storage.bytes) || needed < offsetof(TOKEN_GROUPS, Groups)) return FALSE;
    TOKEN_GROUPS *group = (TOKEN_GROUPS *)storage.bytes;
    if (group->GroupCount > WRIT_AD_MAX_TOKEN_ENTRIES ||
        group->GroupCount > (needed - offsetof(TOKEN_GROUPS, Groups)) / sizeof(SID_AND_ATTRIBUTES)) return FALSE;
    *count = group->GroupCount;
    for (DWORD i = 0; i < *count; ++i)
        if (!copy_sid(storage.bytes, needed, group->Groups[i].Sid, group->Groups[i].Attributes, &out[i])) return FALSE;
    qsort(out, *count, sizeof(*out), sid_compare);
    return writ_ad_sid_identities_unique(out, *count);
}
static BOOL privileges(HANDLE token, WRIT_AD_PRIVILEGE *out, DWORD *count)
{
    union { ULONGLONG alignment; BYTE bytes[4096]; } storage;
    DWORD needed = 0;
    if (!GetTokenInformation(token, TokenPrivileges, storage.bytes, sizeof(storage.bytes), &needed) ||
        needed > sizeof(storage.bytes) || needed < offsetof(TOKEN_PRIVILEGES, Privileges)) return FALSE;
    TOKEN_PRIVILEGES *priv = (TOKEN_PRIVILEGES *)storage.bytes;
    if (priv->PrivilegeCount > WRIT_AD_MAX_TOKEN_ENTRIES ||
        priv->PrivilegeCount > (needed - offsetof(TOKEN_PRIVILEGES, Privileges)) / sizeof(LUID_AND_ATTRIBUTES)) return FALSE;
    *count = priv->PrivilegeCount;
    for (DWORD i = 0; i < *count; ++i) { out[i].high = priv->Privileges[i].Luid.HighPart; out[i].low = priv->Privileges[i].Luid.LowPart; out[i].attributes = priv->Privileges[i].Attributes; }
    qsort(out, *count, sizeof(*out), privilege_compare);
    return writ_ad_privilege_identities_unique(out, *count);
}
BOOL writ_ad_token_ordinary_primary(HANDLE token, PSID expected_user)
{
    union { ULONGLONG alignment; BYTE bytes[1024]; } storage;
    union { ULONGLONG alignment; BYTE bytes[SECURITY_MAX_SID_SIZE]; } admin;
    WRIT_AD_SID user = {0}, integrity = {0};
    WRIT_AD_SID token_groups[WRIT_AD_MAX_TOKEN_ENTRIES] = {0};
    WRIT_AD_SID restricted[WRIT_AD_MAX_TOKEN_ENTRIES] = {0};
    WRIT_AD_PRIVILEGE token_privileges[WRIT_AD_MAX_TOKEN_ENTRIES] = {0};
    DWORD needed = 0, app = 1, admin_size = sizeof(admin.bytes);
    DWORD group_count = 0, restricted_count = 0, privilege_count = 0;
    TOKEN_ELEVATION elevation = {0};
    LUID traverse;
    if (!token || !expected_user || !IsValidSid(expected_user) ||
        !CreateWellKnownSid(WinBuiltinAdministratorsSid, NULL, admin.bytes, &admin_size) ||
        !GetTokenInformation(token, TokenUser, storage.bytes, sizeof(storage.bytes), &needed) ||
        needed > sizeof(storage.bytes) || needed < sizeof(TOKEN_USER) ||
        !copy_sid(storage.bytes, needed, ((TOKEN_USER *)storage.bytes)->User.Sid, 0, &user) ||
        !EqualSid((PSID)user.bytes, expected_user) ||
        !GetTokenInformation(token, TokenIntegrityLevel, storage.bytes, sizeof(storage.bytes), &needed) ||
        needed > sizeof(storage.bytes) || needed < sizeof(TOKEN_MANDATORY_LABEL) ||
        !copy_sid(storage.bytes, needed, ((TOKEN_MANDATORY_LABEL *)storage.bytes)->Label.Sid,
            ((TOKEN_MANDATORY_LABEL *)storage.bytes)->Label.Attributes, &integrity) ||
        !GetTokenInformation(token, TokenIsAppContainer, &app, sizeof(app), &needed) || needed != sizeof(app) || app ||
        !GetTokenInformation(token, TokenElevation, &elevation, sizeof(elevation), &needed) ||
        needed != sizeof(elevation) || elevation.TokenIsElevated ||
        !groups(token, TokenGroups, token_groups, &group_count) ||
        !groups(token, TokenRestrictedSids, restricted, &restricted_count) || restricted_count ||
        !privileges(token, token_privileges, &privilege_count) ||
        !LookupPrivilegeValueW(NULL, SE_CHANGE_NOTIFY_NAME, &traverse)) return FALSE;
    PSID label = (PSID)integrity.bytes;
    BYTE count = *GetSidSubAuthorityCount(label);
    if (!count || *GetSidSubAuthority(label, count - 1) != SECURITY_MANDATORY_MEDIUM_RID) return FALSE;
    BOOL admin_disabled = FALSE;
    for (DWORD i = 0; i < group_count; ++i) if (EqualSid((PSID)token_groups[i].bytes, admin.bytes)) {
        if ((token_groups[i].attributes & SE_GROUP_ENABLED) ||
            !(token_groups[i].attributes & SE_GROUP_USE_FOR_DENY_ONLY)) return FALSE;
        admin_disabled = TRUE;
    }
    for (DWORD i = 0; i < privilege_count; ++i)
        if (token_privileges[i].low != traverse.LowPart || token_privileges[i].high != traverse.HighPart) return FALSE;
    return admin_disabled;
}
BOOL writ_ad_token_snapshot(HANDLE token, WRIT_AD_TOKEN *out)
{
    union { ULONGLONG alignment; BYTE bytes[1024]; } storage;
    TOKEN_STATISTICS stats;
    TOKEN_ELEVATION elevation;
    DWORD appcontainer = 0, needed = 0;
    if (!out) return FALSE;
    ZeroMemory(out, sizeof(*out));
    if (!token) return FALSE;
    if (!GetTokenInformation(token, TokenUser, storage.bytes, sizeof(storage.bytes), &needed) ||
        needed > sizeof(storage.bytes) || needed < sizeof(TOKEN_USER) ||
        !copy_sid(storage.bytes, needed, ((TOKEN_USER *)storage.bytes)->User.Sid, 0, &out->user) ||
        !GetTokenInformation(token, TokenIntegrityLevel, storage.bytes, sizeof(storage.bytes), &needed) ||
        needed > sizeof(storage.bytes) || needed < sizeof(TOKEN_MANDATORY_LABEL) ||
        !copy_sid(storage.bytes, needed, ((TOKEN_MANDATORY_LABEL *)storage.bytes)->Label.Sid,
            ((TOKEN_MANDATORY_LABEL *)storage.bytes)->Label.Attributes, &out->integrity) ||
        !GetTokenInformation(token, TokenAppContainerSid, storage.bytes, sizeof(storage.bytes), &needed) ||
        needed > sizeof(storage.bytes) || needed < sizeof(TOKEN_APPCONTAINER_INFORMATION) ||
        !copy_sid(storage.bytes, needed, ((TOKEN_APPCONTAINER_INFORMATION *)storage.bytes)->TokenAppContainer, 0, &out->package) ||
        !GetTokenInformation(token, TokenIsAppContainer, &appcontainer, sizeof(appcontainer), &needed) || needed != sizeof(appcontainer) ||
        !GetTokenInformation(token, TokenElevation, &elevation, sizeof(elevation), &needed) || needed != sizeof(elevation) ||
        !GetTokenInformation(token, TokenStatistics, &stats, sizeof(stats), &needed) || needed != sizeof(stats) ||
        !groups(token, TokenGroups, out->groups, &out->groups_count) ||
        !groups(token, TokenCapabilities, out->capabilities, &out->capability_count) ||
        !groups(token, TokenRestrictedSids, out->restricted, &out->restricted_count) ||
        !privileges(token, out->privileges, &out->privilege_count)) return FALSE;
    out->elevated = elevation.TokenIsElevated;
    out->appcontainer = appcontainer;
    out->authentication = stats.AuthenticationId;
    out->magic = WRIT_AD_TOKEN_MAGIC;
    return TRUE;
}
BOOL writ_ad_token_equal_except_capabilities(const WRIT_AD_TOKEN *a, const WRIT_AD_TOKEN *b)
{
    if (!a || !b || a->magic != WRIT_AD_TOKEN_MAGIC || b->magic != WRIT_AD_TOKEN_MAGIC ||
        a->user.length < 8 || b->user.length < 8 || a->user.length > SECURITY_MAX_SID_SIZE || b->user.length > SECURITY_MAX_SID_SIZE ||
        a->integrity.length < 8 || b->integrity.length < 8 || a->integrity.length > SECURITY_MAX_SID_SIZE || b->integrity.length > SECURITY_MAX_SID_SIZE ||
        a->package.length < 8 || b->package.length < 8 || a->package.length > SECURITY_MAX_SID_SIZE || b->package.length > SECURITY_MAX_SID_SIZE ||
        a->appcontainer != b->appcontainer || a->elevated != b->elevated ||
        sid_compare(&a->package, &b->package) || sid_compare(&a->integrity, &b->integrity) ||
        a->groups_count > WRIT_AD_MAX_TOKEN_ENTRIES || b->groups_count > WRIT_AD_MAX_TOKEN_ENTRIES ||
        a->capability_count > WRIT_AD_MAX_TOKEN_ENTRIES || b->capability_count > WRIT_AD_MAX_TOKEN_ENTRIES ||
        a->restricted_count > WRIT_AD_MAX_TOKEN_ENTRIES || b->restricted_count > WRIT_AD_MAX_TOKEN_ENTRIES ||
        a->privilege_count > WRIT_AD_MAX_TOKEN_ENTRIES || b->privilege_count > WRIT_AD_MAX_TOKEN_ENTRIES ||
        sid_compare(&a->user, &b->user) ||
        a->authentication.HighPart != b->authentication.HighPart || a->authentication.LowPart != b->authentication.LowPart ||
        a->groups_count != b->groups_count || a->restricted_count != b->restricted_count ||
        a->privilege_count != b->privilege_count) return FALSE;
    for (DWORD i = 0; i < a->groups_count; ++i)
        if (a->groups[i].length > SECURITY_MAX_SID_SIZE || b->groups[i].length > SECURITY_MAX_SID_SIZE ||
            sid_compare(&a->groups[i], &b->groups[i])) return FALSE;
    for (DWORD i = 0; i < a->restricted_count; ++i)
        if (a->restricted[i].length > SECURITY_MAX_SID_SIZE || b->restricted[i].length > SECURITY_MAX_SID_SIZE ||
            sid_compare(&a->restricted[i], &b->restricted[i])) return FALSE;
    for (DWORD i = 0; i < a->privilege_count; ++i) if (privilege_compare(&a->privileges[i], &b->privileges[i])) return FALSE;
    return TRUE;
}
