#define _WIN32_WINNT 0x0A00
#include "isolation.h"
#include <aclapi.h>
#include <sddl.h>
#include <strsafe.h>
#include <stdio.h>
#include <stdlib.h>

BOOL writ_process_security(SECURITY_ATTRIBUTES *attributes)
{
    ZeroMemory(attributes, sizeof(*attributes));
    attributes->nLength = sizeof(*attributes);
    return ConvertStringSecurityDescriptorToSecurityDescriptorW(
        L"O:BAG:BAD:P(A;;GA;;;SY)(A;;GA;;;BA)", SDDL_REVISION_1,
        &attributes->lpSecurityDescriptor, NULL);
}

static BOOL protect_object(HANDLE object, PSECURITY_DESCRIPTOR descriptor)
{
    PSID owner = NULL, group = NULL;
    PACL dacl = NULL;
    BOOL defaulted = FALSE, present = FALSE;
    if (!GetSecurityDescriptorOwner(descriptor, &owner, &defaulted) ||
        !GetSecurityDescriptorGroup(descriptor, &group, &defaulted) ||
        !GetSecurityDescriptorDacl(descriptor, &present, &dacl, &defaulted) || !present || !dacl)
        return FALSE;
    DWORD error = SetSecurityInfo(object, SE_KERNEL_OBJECT,
        OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION |
        DACL_SECURITY_INFORMATION | PROTECTED_DACL_SECURITY_INFORMATION,
        owner, group, dacl, NULL);
    if (error) { SetLastError(error); return FALSE; }
    return TRUE;
}

BOOL writ_protect_broker(void)
{
    SECURITY_ATTRIBUTES attributes;
    BOOL ok = FALSE, admin = FALSE;
    BYTE admin_sid[SECURITY_MAX_SID_SIZE];
    DWORD size = sizeof(admin_sid);
    HANDLE token = NULL;
    TOKEN_ELEVATION elevation;
    if (!CreateWellKnownSid(WinBuiltinAdministratorsSid, NULL, admin_sid, &size) ||
        !CheckTokenMembership(NULL, admin_sid, &admin) || !admin ||
        !OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return FALSE;
    size = 0;
    ok = GetTokenInformation(token, TokenElevation, &elevation, sizeof(elevation), &size) &&
        elevation.TokenIsElevated != 0;
    CloseHandle(token);
    if (!ok || !writ_process_security(&attributes)) return FALSE;
    /* Install before importing any fixture bytes. Administrator/kernel access
       remains in the trusted boundary; ordinary account ownership is removed. */
    ok = protect_object(GetCurrentProcess(), attributes.lpSecurityDescriptor) &&
        protect_object(GetCurrentThread(), attributes.lpSecurityDescriptor);
    LocalFree(attributes.lpSecurityDescriptor);
    return ok;
}

BOOL writ_ordinary_token(HANDLE token, PSID expected_user)
{
    BYTE user_storage[sizeof(TOKEN_USER) + SECURITY_MAX_SID_SIZE];
    BYTE label_storage[sizeof(TOKEN_MANDATORY_LABEL) + SECURITY_MAX_SID_SIZE];
    BYTE groups_storage[16384], privileges_storage[4096], restricted_storage[4096];
    BYTE admin_sid[SECURITY_MAX_SID_SIZE];
    DWORD needed = 0, app = 1, sid_size = sizeof(admin_sid);
    TOKEN_USER *user = (TOKEN_USER *)user_storage;
    TOKEN_MANDATORY_LABEL *label = (TOKEN_MANDATORY_LABEL *)label_storage;
    TOKEN_GROUPS *groups = (TOKEN_GROUPS *)groups_storage;
    TOKEN_GROUPS *restricted = (TOKEN_GROUPS *)restricted_storage;
    TOKEN_PRIVILEGES *privileges = (TOKEN_PRIVILEGES *)privileges_storage;
    LUID traverse;
    if (!CreateWellKnownSid(WinBuiltinAdministratorsSid, NULL, admin_sid, &sid_size) ||
        !GetTokenInformation(token, TokenUser, user_storage, sizeof(user_storage), &needed) ||
        !IsValidSid(user->User.Sid) || (expected_user && !EqualSid(user->User.Sid, expected_user)) ||
        !GetTokenInformation(token, TokenIsAppContainer, &app, sizeof(app), &needed) || app ||
        !GetTokenInformation(token, TokenIntegrityLevel, label_storage, sizeof(label_storage), &needed) ||
        !IsValidSid(label->Label.Sid) || !*GetSidSubAuthorityCount(label->Label.Sid) ||
        *GetSidSubAuthority(label->Label.Sid, *GetSidSubAuthorityCount(label->Label.Sid) - 1) != SECURITY_MANDATORY_MEDIUM_RID ||
        !GetTokenInformation(token, TokenGroups, groups_storage, sizeof(groups_storage), &needed) ||
        groups->GroupCount > (sizeof(groups_storage) - FIELD_OFFSET(TOKEN_GROUPS, Groups)) / sizeof(SID_AND_ATTRIBUTES) ||
        !GetTokenInformation(token, TokenRestrictedSids, restricted_storage, sizeof(restricted_storage), &needed) ||
        restricted->GroupCount != 0 ||
        !GetTokenInformation(token, TokenPrivileges, privileges_storage, sizeof(privileges_storage), &needed) ||
        privileges->PrivilegeCount > (sizeof(privileges_storage) - FIELD_OFFSET(TOKEN_PRIVILEGES, Privileges)) / sizeof(LUID_AND_ATTRIBUTES) ||
        !LookupPrivilegeValueW(NULL, SE_CHANGE_NOTIFY_NAME, &traverse)) return FALSE;
    BOOL admin_disabled = FALSE;
    for (DWORD i = 0; i < groups->GroupCount; ++i) if (EqualSid(groups->Groups[i].Sid, admin_sid)) {
        if ((groups->Groups[i].Attributes & SE_GROUP_ENABLED) ||
            !(groups->Groups[i].Attributes & SE_GROUP_USE_FOR_DENY_ONLY)) return FALSE;
        admin_disabled = TRUE;
    }
    for (DWORD i = 0; i < privileges->PrivilegeCount; ++i)
        if (privileges->Privileges[i].Luid.LowPart != traverse.LowPart ||
            privileges->Privileges[i].Luid.HighPart != traverse.HighPart) return FALSE;
    return admin_disabled;
}

BOOL writ_same_user_probe(const wchar_t *image, HANDLE policy, HANDLE worker)
{
    HANDLE source = NULL, restricted = NULL, actual = NULL, job = NULL;
    PROCESS_INFORMATION process = {0};
    STARTUPINFOEXW startup = {0};
    SECURITY_ATTRIBUTES child_security = { sizeof(child_security), NULL, FALSE };
    BYTE admin_sid[SECURITY_MAX_SID_SIZE], user_storage[sizeof(TOKEN_USER) + SECURITY_MAX_SID_SIZE];
    TOKEN_USER *user = (TOKEN_USER *)user_storage;
    PSID medium = NULL;
    LPWSTR user_string = NULL;
    DWORD size = sizeof(admin_sid), needed = 0, exit_code = 1, error = ERROR_ACCESS_DENIED;
    SIZE_T attribute_size = 0;
    BOOL ok = FALSE, attributes_ready = FALSE;
    wchar_t command[32768], security[512], system_root[MAX_PATH], environment[MAX_PATH + 32];
    if (WaitForSingleObject(policy, 0) != WAIT_TIMEOUT || WaitForSingleObject(worker, 0) != WAIT_TIMEOUT ||
        !image || wcschr(image, L'"') ||
        !CreateWellKnownSid(WinBuiltinAdministratorsSid, NULL, admin_sid, &size) ||
        !OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY | TOKEN_DUPLICATE | TOKEN_ASSIGN_PRIMARY, &source) ||
        !GetTokenInformation(source, TokenUser, user_storage, sizeof(user_storage), &needed)) goto failed;
    SID_AND_ATTRIBUTES disabled = { admin_sid, 0 };
    /* No restricting SID list or AppContainer is added: the negative reader
       keeps the same user SID and ordinary user access, without admin privileges. */
    if (!CreateRestrictedToken(source, DISABLE_MAX_PRIVILEGE, 1, &disabled, 0, NULL, 0, NULL, &restricted) ||
        !ConvertStringSidToSidW(L"S-1-16-8192", &medium)) goto failed;
    TOKEN_MANDATORY_LABEL label = { { medium, SE_GROUP_INTEGRITY } };
    if (!SetTokenInformation(restricted, TokenIntegrityLevel, &label, sizeof(label) + GetLengthSid(medium)) ||
        !writ_ordinary_token(restricted, user->User.Sid) ||
        !ConvertSidToStringSidW(user->User.Sid, &user_string) ||
        FAILED(StringCchPrintfW(security, ARRAYSIZE(security),
            L"O:%sD:P(A;;GA;;;%s)(A;;GA;;;SY)(A;;GA;;;BA)", user_string, user_string)) ||
        !ConvertStringSecurityDescriptorToSecurityDescriptorW(security, SDDL_REVISION_1,
            &child_security.lpSecurityDescriptor, NULL)) goto failed;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE |
        JOB_OBJECT_LIMIT_ACTIVE_PROCESS | JOB_OBJECT_LIMIT_PROCESS_MEMORY | JOB_OBJECT_LIMIT_PROCESS_TIME;
    limits.BasicLimitInformation.ActiveProcessLimit = 1;
    limits.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart = 10LL * 10000000LL;
    limits.ProcessMemoryLimit = 64 * 1024 * 1024;
    job = CreateJobObjectW(NULL, NULL);
    if (!job || !SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) goto failed;
    InitializeProcThreadAttributeList(NULL, 1, 0, &attribute_size);
    startup.lpAttributeList = HeapAlloc(GetProcessHeap(), 0, attribute_size);
    if (!startup.lpAttributeList ||
        !InitializeProcThreadAttributeList(startup.lpAttributeList, 1, 0, &attribute_size)) goto failed;
    attributes_ready = TRUE;
    if (!UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_JOB_LIST,
        &job, sizeof(job), NULL, NULL)) goto failed;
    startup.StartupInfo.cb = sizeof(startup);
    startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    ZeroMemory(environment, sizeof(environment));
    DWORD root_length = GetWindowsDirectoryW(system_root, ARRAYSIZE(system_root));
    if (!root_length || root_length >= ARRAYSIZE(system_root) ||
        FAILED(StringCchPrintfW(environment, ARRAYSIZE(environment) - 1, L"SystemRoot=%s", system_root)) ||
        FAILED(StringCchPrintfW(command, ARRAYSIZE(command), L"\"%s\" --outsider %lu %lu %lu", image,
            GetCurrentProcessId(), GetProcessId(policy), GetProcessId(worker))) ||
        !CreateProcessAsUserW(restricted, image, command, &child_security, &child_security, FALSE,
            EXTENDED_STARTUPINFO_PRESENT | CREATE_SUSPENDED | CREATE_NO_WINDOW | CREATE_UNICODE_ENVIRONMENT,
            environment, system_root, &startup.StartupInfo, &process)) goto failed;
    if (!OpenProcessToken(process.hProcess, TOKEN_QUERY, &actual) ||
        !writ_ordinary_token(actual, user->User.Sid) || ResumeThread(process.hThread) == (DWORD)-1 ||
        WaitForSingleObject(process.hProcess, 10000) != WAIT_OBJECT_0 ||
        !GetExitCodeProcess(process.hProcess, &exit_code) || exit_code ||
        WaitForSingleObject(policy, 0) != WAIT_TIMEOUT || WaitForSingleObject(worker, 0) != WAIT_TIMEOUT) goto failed;
    ok = TRUE;
    goto done;
failed:
    error = GetLastError();
    fprintf(stderr, "FAIL ordinary same-user process probe error=%lu exit=%lu\n", error, exit_code);
done:
    if (job) TerminateJobObject(job, ERROR_OPERATION_ABORTED);
    if (process.hProcess) { WaitForSingleObject(process.hProcess, 5000); CloseHandle(process.hProcess); }
    if (process.hThread) CloseHandle(process.hThread);
    if (job) CloseHandle(job);
    if (actual) CloseHandle(actual);
    if (restricted) CloseHandle(restricted);
    if (source) CloseHandle(source);
    if (attributes_ready) DeleteProcThreadAttributeList(startup.lpAttributeList);
    if (startup.lpAttributeList) HeapFree(GetProcessHeap(), 0, startup.lpAttributeList);
    if (child_security.lpSecurityDescriptor) LocalFree(child_security.lpSecurityDescriptor);
    if (medium) LocalFree(medium);
    if (user_string) LocalFree(user_string);
    if (!ok) SetLastError(error);
    return ok;
}

int writ_outsider_probe(int argc, wchar_t **argv)
{
    HANDLE token = NULL;
    if (argc != 5 || !OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return 91;
    BOOL ordinary = writ_ordinary_token(token, NULL);
    CloseHandle(token);
    if (!ordinary) return 92;
    const DWORD rights[] = { PROCESS_VM_READ, PROCESS_DUP_HANDLE, WRITE_DAC, WRITE_OWNER };
    /* Positive control: these exact API rights work against this unprotected
       process. An access-denied result is then required for each protected target. */
    for (unsigned int i = 0; i < ARRAYSIZE(rights); ++i) {
        HANDLE self = OpenProcess(rights[i], FALSE, GetCurrentProcessId());
        if (!self) return 93;
        CloseHandle(self);
    }
    for (int target = 2; target < 5; ++target) {
        wchar_t *end = NULL;
        unsigned long pid = wcstoul(argv[target], &end, 10);
        if (!pid || !end || *end) return 94;
        for (unsigned int i = 0; i < ARRAYSIZE(rights); ++i) {
            HANDLE access = OpenProcess(rights[i], FALSE, (DWORD)pid);
            DWORD error = access ? ERROR_SUCCESS : GetLastError();
            if (access) CloseHandle(access);
            if (access || error != ERROR_ACCESS_DENIED) return 100 + (target - 2) * 4 + (int)i;
        }
    }
    return 0;
}
