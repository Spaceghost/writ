#define _WIN32_WINNT 0x0A00
#include "win32k_ac_checked.h"
#include "win32k_ac_token.h"
#include <bcrypt.h>
#include <sddl.h>
#include <strsafe.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

/* Log the status at the failing call; cleanup can overwrite GetLastError. */
#define AC_WIN(call) do { if (!(call)) { DWORD e = GetLastError(); \
    fprintf(stderr, "AC_PREP_FAILED stage=%s domain=win32 status=%lu\n", #call, e); goto done; } } while (0)
#define AC_WIN_OUT(call, output) do { if (!(call)) { DWORD e = GetLastError(); (output) = NULL; \
    fprintf(stderr, "AC_PREP_FAILED stage=%s domain=win32 status=%lu output=unverified\n", #call, e); goto done; } } while (0)
#define AC_SEM(test, label) do { if (!(test)) { \
    fprintf(stderr, "AC_PREP_FAILED stage=%s domain=semantic status=invalid\n", label); goto done; } } while (0)
#define AC_NT(call) do { NTSTATUS s = (call); if (s < 0) { \
    fprintf(stderr, "AC_PREP_FAILED stage=%s domain=ntstatus status=0x%08lx\n", #call, (unsigned long)(ULONG)s); goto done; } } while (0)
#define AC_NT_OUT(call, output) do { NTSTATUS s = (call); if (s < 0) { (output) = NULL; \
    fprintf(stderr, "AC_PREP_FAILED stage=%s domain=ntstatus status=0x%08lx output=unverified\n", #call, (unsigned long)(ULONG)s); goto done; } } while (0)
#define AC_HR(call) do { HRESULT h = (call); if (FAILED(h)) { \
    fprintf(stderr, "AC_PREP_FAILED stage=%s domain=hresult status=0x%08lx\n", #call, (unsigned long)(ULONG)h); goto done; } } while (0)

static BOOL close_checked(HANDLE *handle, const char *label)
{
    if (!*handle || *handle == INVALID_HANDLE_VALUE) return TRUE;
    BOOL ok = CloseHandle(*handle);
    if (!ok) fprintf(stderr, "AC_PREP_CLEANUP_FAILED %s error=%lu\n", label, GetLastError());
    *handle = NULL;
    return ok;
}
static BOOL free_local(void *value, const char *label)
{
    if (!value) return TRUE;
    if (LocalFree(value) == NULL) return TRUE;
    fprintf(stderr, "AC_PREP_CLEANUP_FAILED %s error=%lu\n", label, GetLastError());
    return FALSE;
}
static BOOL capture_user_checked(HANDLE token, BYTE *sid)
{
    union { ULONGLONG alignment; BYTE bytes[sizeof(TOKEN_USER) + SECURITY_MAX_SID_SIZE]; } storage;
    DWORD needed = 0;
    TOKEN_USER *user = (TOKEN_USER *)storage.bytes;
    if (!GetTokenInformation(token, TokenUser, storage.bytes, sizeof(storage.bytes), &needed)) {
        DWORD e = GetLastError(); fprintf(stderr, "AC_PREP_FAILED stage=source-TokenUser domain=win32 status=%lu\n", e); return FALSE;
    }
    if (needed > sizeof(storage.bytes) || needed < sizeof(TOKEN_USER) || !user->User.Sid) return FALSE;
    uintptr_t base = (uintptr_t)storage.bytes, pointer = (uintptr_t)user->User.Sid;
    if (pointer < base) return FALSE;
    size_t offset = (size_t)(pointer - base);
    if (offset > needed || needed - offset < offsetof(SID, SubAuthority)) return FALSE;
    SID *actual = (SID *)user->User.Sid;
    if (actual->SubAuthorityCount > SID_MAX_SUB_AUTHORITIES) return FALSE;
    size_t size = offsetof(SID, SubAuthority) + (size_t)actual->SubAuthorityCount * sizeof(DWORD);
    if (size > SECURITY_MAX_SID_SIZE || size > needed - offset || !IsValidSid(actual) || GetLengthSid(actual) != size) return FALSE;
    return CopySid(SECURITY_MAX_SID_SIZE, sid, actual);
}

BOOL writ_ac_reduced_primary(HANDLE *result, BYTE *user)
{
    HANDLE source = NULL, reduced = NULL;
    union { ULONGLONG alignment; BYTE bytes[SECURITY_MAX_SID_SIZE]; } admin;
    DWORD size = sizeof(admin.bytes), needed = 0;
    TOKEN_ELEVATION elevation = {0};
    PSID medium = NULL;
    BOOL ok = FALSE;
    if (!result || !user) return FALSE;
    *result = NULL;
    AC_WIN(CreateWellKnownSid(WinBuiltinAdministratorsSid, NULL, admin.bytes, &size));
    AC_WIN_OUT(OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY | TOKEN_DUPLICATE | TOKEN_ASSIGN_PRIMARY | TOKEN_ADJUST_DEFAULT, &source), source);
    AC_SEM(capture_user_checked(source, user), "bounded-source-user");
    SID_AND_ATTRIBUTES disabled = { admin.bytes, 0 };
    AC_WIN_OUT(CreateRestrictedToken(source, DISABLE_MAX_PRIVILEGE | LUA_TOKEN, 1, &disabled, 0, NULL, 0, NULL, &reduced), reduced);
    AC_WIN_OUT(ConvertStringSidToSidW(L"S-1-16-8192", &medium), medium);
    TOKEN_MANDATORY_LABEL label = { { medium, SE_GROUP_INTEGRITY } };
    AC_WIN(SetTokenInformation(reduced, TokenIntegrityLevel, &label, sizeof(label) + GetLengthSid(medium)));
    AC_WIN(GetTokenInformation(reduced, TokenElevation, &elevation, sizeof(elevation), &needed));
    AC_SEM(needed == sizeof(elevation) && !elevation.TokenIsElevated, "reduced-elevation");
    if (!writ_ac_token_ordinary_primary(reduced, user)) {
        fprintf(stderr, "AC_PREP_FAILED stage=bounded-reduced-token-facts domain=unknown status=semantic-or-api\n"); goto done;
    }
    ok = TRUE;
done:
    if (!close_checked(&source, "source-token")) ok = FALSE;
    if (!free_local(medium, "medium-sid")) ok = FALSE;
    if (ok) { *result = reduced; reduced = NULL; }
    if (!close_checked(&reduced, "failed-reduced-token")) ok = FALSE;
    if (!ok) SetLastError(ERROR_INVALID_DATA);
    return ok;
}
BOOL writ_ac_image_identity(WRIT_WORKER *worker, const wchar_t *image)
{
    BCRYPT_ALG_HANDLE algorithm = NULL;
    BCRYPT_HASH_HANDLE hash = NULL;
    BYTE bytes[65536];
    LARGE_INTEGER remaining;
    DWORD got = 0;
    BOOL ok = FALSE;
    worker->image = CreateFileW(image, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
        FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_SEQUENTIAL_SCAN, NULL);
    if (worker->image == INVALID_HANDLE_VALUE) {
        DWORD e = GetLastError(); fprintf(stderr, "AC_PREP_FAILED stage=CreateFileW-image domain=win32 status=%lu\n", e); return FALSE;
    }
    BY_HANDLE_FILE_INFORMATION info;
    AC_WIN(GetFileInformationByHandle(worker->image, &info));
    AC_SEM(!(info.dwFileAttributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY)), "image-type");
    AC_WIN(GetFileSizeEx(worker->image, &remaining));
    AC_SEM(remaining.QuadPart > 0 && remaining.QuadPart <= 64 * 1024 * 1024, "image-size");
    DWORD chars = GetFinalPathNameByHandleW(worker->image, worker->image_path, ARRAYSIZE(worker->image_path), FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
    if (!chars) { DWORD e = GetLastError(); fprintf(stderr, "AC_PREP_FAILED stage=GetFinalPathNameByHandleW domain=win32 status=%lu\n", e); goto done; }
    AC_SEM(chars < ARRAYSIZE(worker->image_path), "image-path-length");
    AC_NT_OUT(BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, NULL, 0), algorithm);
    AC_NT_OUT(BCryptCreateHash(algorithm, &hash, NULL, 0, NULL, 0, 0), hash);
    while (remaining.QuadPart > 0) {
        DWORD requested = remaining.QuadPart > (LONGLONG)sizeof(bytes) ? (DWORD)sizeof(bytes) : (DWORD)remaining.QuadPart;
        AC_WIN(ReadFile(worker->image, bytes, requested, &got, NULL));
        AC_SEM(got && got <= requested, "image-read-length");
        AC_NT(BCryptHashData(hash, bytes, got, 0));
        remaining.QuadPart -= got;
    }
    AC_NT(BCryptFinishHash(hash, worker->image_hash, sizeof(worker->image_hash), 0));
    ok = TRUE;
done:
    if (hash) { NTSTATUS s = BCryptDestroyHash(hash); if (s < 0) { fprintf(stderr, "AC_PREP_CLEANUP_FAILED stage=hash domain=ntstatus status=0x%08lx\n", (unsigned long)(ULONG)s); ok = FALSE; } }
    if (algorithm) { NTSTATUS s = BCryptCloseAlgorithmProvider(algorithm, 0); if (s < 0) { fprintf(stderr, "AC_PREP_CLEANUP_FAILED stage=hash-provider domain=ntstatus status=0x%08lx\n", (unsigned long)(ULONG)s); ok = FALSE; } }
    SecureZeroMemory(bytes, sizeof(bytes));
    if (!ok) SetLastError(ERROR_INVALID_DATA);
    return ok;
}
BOOL writ_ac_private_image(WRIT_WORKER *worker)
{
    wchar_t temporary[MAX_PATH], sddl[1024];
    LPWSTR app_sid = NULL, user_sid = NULL;
    PSECURITY_DESCRIPTOR descriptor = NULL;
    SECURITY_ATTRIBUTES security = { sizeof(security), NULL, FALSE };
    HANDLE output = INVALID_HANDLE_VALUE;
    BYTE buffer[65536], digest[32];
    LARGE_INTEGER zero = {0};
    DWORD read = 0, written = 0;
    BOOL ok = FALSE;
    DWORD temp_length = GetTempPathW(ARRAYSIZE(temporary), temporary);
    if (!temp_length) { DWORD e = GetLastError(); fprintf(stderr, "AC_PREP_FAILED stage=GetTempPathW domain=win32 status=%lu\n", e); goto done; }
    AC_SEM(temp_length < ARRAYSIZE(temporary), "temporary-path-length");
    AC_WIN_OUT(ConvertSidToStringSidW(worker->app_sid, &app_sid), app_sid);
    AC_WIN_OUT(ConvertSidToStringSidW(worker->user_sid, &user_sid), user_sid);
    AC_HR(StringCchPrintfW(worker->private_directory, ARRAYSIZE(worker->private_directory), L"%s%s", temporary, worker->profile));
    AC_HR(StringCchPrintfW(worker->private_image, ARRAYSIZE(worker->private_image), L"%s\\reader.exe", worker->private_directory));
    AC_HR(StringCchPrintfW(sddl, ARRAYSIZE(sddl), L"O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;GRGX;;;%s)(A;OICI;GRGX;;;%s)", user_sid, app_sid));
    AC_WIN_OUT(ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, SDDL_REVISION_1, &descriptor, NULL), descriptor);
    security.lpSecurityDescriptor = descriptor;
    if (!CreateDirectoryW(worker->private_directory, &security)) {
        DWORD e = GetLastError(); fprintf(stderr, "AC_PREP_FAILED stage=CreateDirectoryW domain=win32 status=%lu\n", e);
        worker->private_directory[0] = 0; worker->private_image[0] = 0; goto done;
    }
    worker->directory_created = TRUE;
    output = CreateFileW(worker->private_image, GENERIC_WRITE, 0, &security, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (output == INVALID_HANDLE_VALUE) { DWORD e = GetLastError(); fprintf(stderr, "AC_PREP_FAILED stage=CreateFileW-private domain=win32 status=%lu\n", e); goto done; }
    worker->image_created = TRUE;
    AC_WIN(SetFilePointerEx(worker->image, zero, NULL, FILE_BEGIN));
    for (;;) {
        AC_WIN(ReadFile(worker->image, buffer, sizeof(buffer), &read, NULL));
        if (!read) break;
        AC_WIN(WriteFile(output, buffer, read, &written, NULL));
        AC_SEM(written == read, "private-image-write-length");
    }
    AC_WIN(FlushFileBuffers(output));
    if (!close_checked(&output, "private-image-output")) goto done;
    memcpy(digest, worker->image_hash, sizeof(digest));
    if (!close_checked(&worker->image, "source-image")) goto done;
    if (!writ_ac_image_identity(worker, worker->private_image)) goto done;
    AC_SEM(memcmp(digest, worker->image_hash, sizeof(digest)) == 0, "private-image-digest");
    ok = TRUE;
done:
    if (!close_checked(&output, "private-image-output")) ok = FALSE;
    if (!free_local(descriptor, "image-descriptor")) ok = FALSE;
    if (!free_local(app_sid, "image-package-string")) ok = FALSE;
    if (!free_local(user_sid, "image-user-string")) ok = FALSE;
    SecureZeroMemory(buffer, sizeof(buffer));
    if (!ok) SetLastError(ERROR_INVALID_DATA);
    return ok;
}
