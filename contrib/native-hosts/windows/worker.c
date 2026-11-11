#define _WIN32_WINNT 0x0A00
#include "worker.h"
#include "isolation.h"
#include "probe.h"
#include "network_probe.h"
#include <bcrypt.h>
#include <fwpmu.h>
#include <rpc.h>
#include <sddl.h>
#include <strsafe.h>
#include <userenv.h>
#include <objbase.h>
#include <stdio.h>
#include <string.h>

static void close_handle(HANDLE *handle)
{
    if (*handle && *handle != INVALID_HANDLE_VALUE) CloseHandle(*handle);
    *handle = NULL;
}

static BOOL token_blob(HANDLE token, TOKEN_INFORMATION_CLASS information,
    void *buffer, DWORD capacity)
{
    DWORD needed = 0;
    return GetTokenInformation(token, information, buffer, capacity, &needed) && needed <= capacity;
}

static BOOL capture_user(HANDLE token, BYTE *sid)
{
    BYTE storage[sizeof(TOKEN_USER) + SECURITY_MAX_SID_SIZE];
    TOKEN_USER *user = (TOKEN_USER *)storage;
    if (!token_blob(token, TokenUser, storage, sizeof(storage)) || !IsValidSid(user->User.Sid))
        return FALSE;
    return CopySid(SECURITY_MAX_SID_SIZE, sid, user->User.Sid);
}

static BOOL reduced_primary(HANDLE *result, BYTE *user)
{
    HANDLE source = NULL, reduced = NULL;
    BYTE admin[SECURITY_MAX_SID_SIZE];
    DWORD size = sizeof(admin), elevation = 1, error = ERROR_ACCESS_DENIED;
    PSID medium = NULL;
    BOOL ok = FALSE;
    *result = NULL;
    if (!CreateWellKnownSid(WinBuiltinAdministratorsSid, NULL, admin, &size) ||
        !OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY | TOKEN_DUPLICATE |
            TOKEN_ASSIGN_PRIMARY | TOKEN_ADJUST_DEFAULT, &source) || !capture_user(source, user)) goto failed;
    SID_AND_ATTRIBUTES disabled = { admin, 0 };
    /* Reduce the primary token before asking Windows to construct its LPAC.
       AppContainer membership alone does not remove an elevated broker's rights. */
    if (!CreateRestrictedToken(source, DISABLE_MAX_PRIVILEGE | LUA_TOKEN, 1, &disabled,
        0, NULL, 0, NULL, &reduced) || !ConvertStringSidToSidW(L"S-1-16-8192", &medium)) goto failed;
    TOKEN_MANDATORY_LABEL label = { { medium, SE_GROUP_INTEGRITY } };
    if (!SetTokenInformation(reduced, TokenIntegrityLevel, &label, sizeof(label) + GetLengthSid(medium)) ||
        !token_blob(reduced, TokenElevation, &elevation, sizeof(elevation))) goto failed;
    SetLastError(ERROR_ACCESS_DENIED);
    if (elevation || !writ_ordinary_token(reduced, user)) {
        fprintf(stderr, "FAIL reduced LPAC primary token elevated=%lu error=%lu\n", elevation, GetLastError());
        goto failed;
    }
    *result = reduced; reduced = NULL; ok = TRUE;
    goto done;
failed:
    error = GetLastError();
done:
    close_handle(&source); close_handle(&reduced);
    if (medium) LocalFree(medium);
    if (!ok) SetLastError(error ? error : ERROR_ACCESS_DENIED);
    return ok;
}

static BOOL lpac_access_check(HANDLE token, PSID expected, PSID user, BOOL diagnostic)
{
    HANDLE duplicate = NULL, checked = token;
    TOKEN_TYPE type;
    LPWSTR package_string = NULL, user_string = NULL;
    const wchar_t *package_classes[4];
    const BOOL expected_access[4] = { TRUE, TRUE, FALSE, FALSE };
    const char *names[4] = { "exact-package", "restricted-packages", "all-packages", "user-only" };
    BOOL ok = FALSE;
    DWORD error = ERROR_ACCESS_DENIED;
    if (!token_blob(token, TokenType, &type, sizeof(type))) goto failed;
    if (type == TokenPrimary) {
        if (!DuplicateTokenEx(token, TOKEN_QUERY, NULL, SecurityIdentification,
            TokenImpersonation, &duplicate)) goto failed;
        checked = duplicate;
    } else if (type != TokenImpersonation) goto done;
    if (!ConvertSidToStringSidW(expected, &package_string) ||
        !ConvertSidToStringSidW(user, &user_string)) goto failed;
    package_classes[0] = package_string;
    package_classes[1] = L"S-1-15-2-2"; /* ALL RESTRICTED APPLICATION PACKAGES */
    package_classes[2] = L"S-1-15-2-1"; /* ALL APPLICATION PACKAGES */
    package_classes[3] = NULL;
    for (unsigned int i = 0; i < ARRAYSIZE(package_classes); ++i) {
        wchar_t sddl[1024];
        PSECURITY_DESCRIPTOR descriptor = NULL;
        GENERIC_MAPPING mapping = { FILE_GENERIC_READ, FILE_GENERIC_WRITE, FILE_GENERIC_EXECUTE, FILE_ALL_ACCESS };
        PRIVILEGE_SET privileges = {0};
        DWORD privilege_size = sizeof(privileges), granted = 0;
        BOOL permitted = FALSE;
        HRESULT formatted = package_classes[i] ?
            StringCchPrintfW(sddl, ARRAYSIZE(sddl), L"O:SYG:SYD:P(A;;0x1;;;%s)(A;;0x1;;;%s)",
                user_string, package_classes[i]) :
            StringCchPrintfW(sddl, ARRAYSIZE(sddl), L"O:SYG:SYD:P(A;;0x1;;;%s)", user_string);
        if (FAILED(formatted)) { error = ERROR_INSUFFICIENT_BUFFER; goto done; }
        if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, SDDL_REVISION_1,
            &descriptor, NULL)) goto failed;
        /* Check the actual launched/request token against unchanged descriptors.
           Never remove an ACE or simulate the LPAC opt-out on an ordinary token. */
        BOOL completed = AccessCheck(descriptor, checked, FILE_READ_DATA, &mapping,
            &privileges, &privilege_size, &granted, &permitted);
        DWORD access_error = GetLastError();
        LocalFree(descriptor);
        if (!completed || permitted != expected_access[i] ||
            granted != (expected_access[i] ? FILE_READ_DATA : 0) || privileges.PrivilegeCount) {
            error = completed ? ERROR_ACCESS_DENIED : access_error;
            if (diagnostic) fprintf(stderr,
                "FAIL LPAC AccessCheck test=%s completed=%u permitted=%u granted=%08lx privileges=%lu error=%lu\n",
                names[i], completed, permitted, granted, privileges.PrivilegeCount, error);
            goto done;
        }
    }
    ok = TRUE;
    goto done;
failed:
    error = GetLastError();
done:
    if (package_string) LocalFree(package_string);
    if (user_string) LocalFree(user_string);
    close_handle(&duplicate);
    if (!ok) SetLastError(error ? error : ERROR_ACCESS_DENIED);
    return ok;
}

static BOOL lpac_token(HANDLE token, PSID expected, PSID diagnostic_capability, BOOL diagnostic)
{
    DWORD app = 0, elevated = 1;
    BYTE user[SECURITY_MAX_SID_SIZE];
    BYTE package_storage[sizeof(TOKEN_APPCONTAINER_INFORMATION) + SECURITY_MAX_SID_SIZE];
    BYTE capability_storage[sizeof(TOKEN_GROUPS) + 16 * sizeof(SID_AND_ATTRIBUTES) + 16 * SECURITY_MAX_SID_SIZE];
    BYTE label_storage[sizeof(TOKEN_MANDATORY_LABEL) + SECURITY_MAX_SID_SIZE];
    TOKEN_APPCONTAINER_INFORMATION *package = (TOKEN_APPCONTAINER_INFORMATION *)package_storage;
    TOKEN_GROUPS *capabilities = (TOKEN_GROUPS *)capability_storage;
    TOKEN_MANDATORY_LABEL *label = (TOKEN_MANDATORY_LABEL *)label_storage;
    if (!token_blob(token, TokenIsAppContainer, &app, sizeof(app)) ||
        !token_blob(token, TokenElevation, &elevated, sizeof(elevated)) ||
        !token_blob(token, TokenAppContainerSid, package_storage, sizeof(package_storage)) ||
        !token_blob(token, TokenCapabilities, capability_storage, sizeof(capability_storage)) ||
        !token_blob(token, TokenIntegrityLevel, label_storage, sizeof(label_storage)) ||
        !capture_user(token, user)) return FALSE;
    if (!package->TokenAppContainer || !IsValidSid(package->TokenAppContainer) ||
        !EqualSid(package->TokenAppContainer, expected) || !IsValidSid(label->Label.Sid)) {
        SetLastError(ERROR_ACCESS_DENIED);
        return FALSE;
    }
    BYTE subauthorities = *GetSidSubAuthorityCount(label->Label.Sid);
    DWORD integrity = subauthorities ? *GetSidSubAuthority(label->Label.Sid, subauthorities - 1) : MAXDWORD;
    BOOL capability_ok = diagnostic_capability ? capabilities->GroupCount == 1 &&
        IsValidSid(capabilities->Groups[0].Sid) && EqualSid(capabilities->Groups[0].Sid, diagnostic_capability) &&
        (capabilities->Groups[0].Attributes & SE_GROUP_ENABLED) != 0 : capabilities->GroupCount == 0;
    BOOL ok = app == 1 && elevated == 0 && capability_ok &&
        integrity <= SECURITY_MANDATORY_LOW_RID;
    if (!ok) {
        if (diagnostic) fprintf(stderr, "FAIL LPAC token facts app=%lu elevated=%lu capabilities=%lu integrity=%lu\n",
            app, elevated, capabilities->GroupCount, integrity);
        SetLastError(ERROR_ACCESS_DENIED);
    }
    /* Require observable native access semantics, without relying on the
       availability of the class-46 token-information query. */
    return ok && lpac_access_check(token, expected, user, diagnostic);
}

static BOOL image_identity(WRIT_WORKER *worker, const wchar_t *image)
{
    BCRYPT_ALG_HANDLE algorithm = NULL;
    BCRYPT_HASH_HANDLE hash = NULL;
    DWORD got = 0;
    BYTE bytes[65536];
    LARGE_INTEGER size;
    BOOL ok = FALSE;
    worker->image = CreateFileW(image, GENERIC_READ, FILE_SHARE_READ, NULL,
        OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_SEQUENTIAL_SCAN, NULL);
    if (worker->image == INVALID_HANDLE_VALUE) return FALSE;
    BY_HANDLE_FILE_INFORMATION info;
    if (!GetFileInformationByHandle(worker->image, &info) ||
        (info.dwFileAttributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY)) ||
        !GetFileSizeEx(worker->image, &size) || size.QuadPart <= 0 || size.QuadPart > 64 * 1024 * 1024)
        return FALSE;
    DWORD chars = GetFinalPathNameByHandleW(worker->image, worker->image_path,
        ARRAYSIZE(worker->image_path), FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
    if (!chars || chars >= ARRAYSIZE(worker->image_path)) return FALSE;
    if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, NULL, 0) < 0 ||
        BCryptCreateHash(algorithm, &hash, NULL, 0, NULL, 0, 0) < 0) goto done;
    while (ReadFile(worker->image, bytes, sizeof(bytes), &got, NULL) && got) {
        if (BCryptHashData(hash, bytes, got, 0) < 0) goto done;
        size.QuadPart -= got;
        if (size.QuadPart < 0) goto done;
    }
    if (size.QuadPart || BCryptFinishHash(hash, worker->image_hash, sizeof(worker->image_hash), 0) < 0)
        goto done;
    ok = TRUE;
done:
    if (hash) BCryptDestroyHash(hash);
    if (algorithm) BCryptCloseAlgorithmProvider(algorithm, 0);
    SecureZeroMemory(bytes, sizeof(bytes));
    return ok;
}

static BOOL install_network_filters(WRIT_WORKER *worker)
{
    FWPM_SESSION0 session = {0};
    FWPM_SUBLAYER0 sublayer = {0};
    FWPM_FILTER_CONDITION0 condition = {0};
    const GUID *layers[4] = { &FWPM_LAYER_ALE_AUTH_CONNECT_V4, &FWPM_LAYER_ALE_AUTH_CONNECT_V6,
        &FWPM_LAYER_ALE_AUTH_RECV_ACCEPT_V4, &FWPM_LAYER_ALE_AUTH_RECV_ACCEPT_V6 };
    DWORD error;
    BOOL transaction = FALSE, ok = FALSE;
    session.displayData.name = L"Writ public-canary worker";
    session.flags = FWPM_SESSION_FLAG_DYNAMIC;
    if ((error = FwpmEngineOpen0(NULL, RPC_C_AUTHN_WINNT, NULL, &session, &worker->network)) != ERROR_SUCCESS)
        goto done;
    if ((error = FwpmTransactionBegin0(worker->network, 0)) != ERROR_SUCCESS) goto done;
    transaction = TRUE;
    if (UuidCreate(&sublayer.subLayerKey) != RPC_S_OK) { error = ERROR_GEN_FAILURE; goto done; }
    sublayer.displayData.name = L"Writ invocation egress blocks";
    sublayer.weight = 0xffff;
    if ((error = FwpmSubLayerAdd0(worker->network, &sublayer, NULL)) != ERROR_SUCCESS) goto done;
    condition.fieldKey = FWPM_CONDITION_ALE_PACKAGE_ID;
    condition.matchType = FWP_MATCH_EQUAL;
    condition.conditionValue.type = FWP_SID;
    condition.conditionValue.sid = worker->app_sid;
    for (DWORD i = 0; i < 4; ++i) {
        FWPM_FILTER0 filter = {0};
        filter.displayData.name = L"Writ no network";
        filter.layerKey = *layers[i];
        filter.subLayerKey = sublayer.subLayerKey;
        filter.action.type = FWP_ACTION_BLOCK;
        filter.weight.type = FWP_UINT8;
        filter.weight.uint8 = 15;
        filter.numFilterConditions = 1;
        filter.filterCondition = &condition;
        if ((error = FwpmFilterAdd0(worker->network, &filter, NULL, &worker->filters[i])) != ERROR_SUCCESS)
            goto done;
    }
    if ((error = FwpmTransactionCommit0(worker->network)) != ERROR_SUCCESS) goto done;
    transaction = FALSE;
    for (DWORD i = 0; i < 4; ++i) {
        FWPM_FILTER0 *readback = NULL;
        error = FwpmFilterGetById0(worker->network, worker->filters[i], &readback);
        if (error != ERROR_SUCCESS) goto done;
        BOOL matches = readback->action.type == FWP_ACTION_BLOCK &&
            IsEqualGUID(&readback->layerKey, layers[i]) && readback->numFilterConditions == 1 &&
            IsEqualGUID(&readback->filterCondition[0].fieldKey, &FWPM_CONDITION_ALE_PACKAGE_ID) &&
            readback->filterCondition[0].matchType == FWP_MATCH_EQUAL &&
            readback->filterCondition[0].conditionValue.type == FWP_SID &&
            EqualSid(readback->filterCondition[0].conditionValue.sid, worker->app_sid);
        FwpmFreeMemory0((void **)&readback);
        if (!matches) { error = ERROR_INVALID_DATA; goto done; }
    }
    ok = TRUE;
done:
    if (transaction) FwpmTransactionAbort0(worker->network);
    if (!ok) { writ_worker_remove_network_filters(worker); SetLastError(error); }
    return ok;
}

static BOOL private_image(WRIT_WORKER *worker)
{
    wchar_t temporary[MAX_PATH], sddl[1024];
    LPWSTR app_sid = NULL, user_sid = NULL;
    PSECURITY_DESCRIPTOR descriptor = NULL;
    SECURITY_ATTRIBUTES security = { sizeof(security), NULL, FALSE };
    HANDLE output = INVALID_HANDLE_VALUE;
    BYTE buffer[65536], digest[32];
    LARGE_INTEGER zero;
    DWORD read = 0, written = 0;
    BOOL ok = FALSE;
    zero.QuadPart = 0;
    DWORD temporary_length = GetTempPathW(ARRAYSIZE(temporary), temporary);
    if (!temporary_length || temporary_length >= ARRAYSIZE(temporary) ||
        !ConvertSidToStringSidW(worker->app_sid, &app_sid) ||
        !ConvertSidToStringSidW(worker->user_sid, &user_sid) ||
        FAILED(StringCchPrintfW(worker->private_directory, ARRAYSIZE(worker->private_directory),
            L"%s%s", temporary, worker->profile)) ||
        FAILED(StringCchPrintfW(worker->private_image, ARRAYSIZE(worker->private_image),
            L"%s\\reader.exe", worker->private_directory)) ||
        FAILED(StringCchPrintfW(sddl, ARRAYSIZE(sddl),
            L"O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;GRGX;;;%s)(A;OICI;GRGX;;;%s)",
            user_sid, app_sid)) ||
        !ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, SDDL_REVISION_1,
            &descriptor, NULL)) goto done;
    security.lpSecurityDescriptor = descriptor;
    if (!CreateDirectoryW(worker->private_directory, &security)) {
        /* No adoption or cleanup of an existing directory. */
        worker->private_directory[0] = 0; worker->private_image[0] = 0;
        goto done;
    }
    worker->directory_created = TRUE;
    output = CreateFileW(worker->private_image, GENERIC_WRITE, 0, &security,
        CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (output == INVALID_HANDLE_VALUE) goto done;
    worker->image_created = TRUE;
    if (!SetFilePointerEx(worker->image, zero, NULL, FILE_BEGIN)) goto done;
    for (;;) {
        if (!ReadFile(worker->image, buffer, sizeof(buffer), &read, NULL)) goto done;
        if (!read) break;
        if (!WriteFile(output, buffer, read, &written, NULL) || written != read) goto done;
    }
    if (!FlushFileBuffers(output)) goto done;
    close_handle(&output);
    memcpy(digest, worker->image_hash, sizeof(digest));
    close_handle(&worker->image);
    if (!image_identity(worker, worker->private_image) ||
        memcmp(digest, worker->image_hash, sizeof(digest))) goto done;
    ok = TRUE;
done:
    close_handle(&output);
    if (descriptor) LocalFree(descriptor);
    if (app_sid) LocalFree(app_sid);
    if (user_sid) LocalFree(user_sid);
    SecureZeroMemory(buffer, sizeof(buffer));
    return ok;
}

BOOL writ_worker_create(WRIT_WORKER *worker, const wchar_t *image,
    wchar_t *command, HANDLE *inherited, DWORD inherited_count, BOOL lpac)
{
    STARTUPINFOEXW startup = {0};
    PROCESS_INFORMATION process = {0};
    SECURITY_CAPABILITIES capabilities = {0};
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    JOBOBJECT_BASIC_UI_RESTRICTIONS ui = {0};
    SECURITY_ATTRIBUTES process_sa = { sizeof(process_sa), NULL, FALSE };
    SIZE_T attribute_size = 0;
    BOOL attributes_initialized = FALSE, ok = FALSE;
    HANDLE token = NULL, launch_token = NULL;
    LPWSTR app_sid_string = NULL, app_folder = NULL;
    DWORD opt_out = PROCESS_CREATION_ALL_APPLICATION_PACKAGES_OPT_OUT;
    DWORD child_policy = PROCESS_CREATION_CHILD_PROCESS_RESTRICTED;
    DWORD64 mitigations = PROCESS_CREATION_MITIGATION_POLICY_WIN32K_SYSTEM_CALL_DISABLE_ALWAYS_ON;
    DWORD error = ERROR_INVALID_PARAMETER;
    const char *stage = "image-identity";
    wchar_t system_root[MAX_PATH], environment[WRIT_ENVIRONMENT_CAPACITY];
    ZeroMemory(worker, sizeof(*worker));
    worker->lpac = lpac;
    if (!inherited_count || inherited_count > 3 || wcschr(image, L'"') || !image_identity(worker, image))
        goto failed;
    if (lpac) {
        stage = "reduced-primary-token";
        if (!reduced_primary(&launch_token, worker->user_sid)) goto failed;
        stage = "appcontainer-profile";
        BYTE nonce[16];
        if (BCryptGenRandom(NULL, nonce, sizeof(nonce), BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0)
            goto failed;
        if (FAILED(StringCchPrintfW(worker->profile, ARRAYSIZE(worker->profile),
            L"Writ.Canary.%08lx.%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            GetCurrentProcessId(), nonce[0], nonce[1], nonce[2], nonce[3], nonce[4], nonce[5],
            nonce[6], nonce[7], nonce[8], nonce[9], nonce[10], nonce[11], nonce[12], nonce[13], nonce[14], nonce[15])))
            goto done;
        HRESULT hr = CreateAppContainerProfile(worker->profile, L"Writ native canary", L"Ephemeral public test",
            NULL, 0, &worker->app_sid);
        if (FAILED(hr)) { error = HRESULT_CODE(hr); goto done; }
        worker->profile_created = TRUE;
        capabilities.AppContainerSid = worker->app_sid;
        /* No capability SIDs, including network, registryRead or lpacCom. */
        stage = "private-image";
        if (!private_image(worker)) goto failed;
    }

    stage = "job";
    worker->job = CreateJobObjectW(NULL, NULL);
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE |
        JOB_OBJECT_LIMIT_ACTIVE_PROCESS | JOB_OBJECT_LIMIT_PROCESS_MEMORY |
        JOB_OBJECT_LIMIT_DIE_ON_UNHANDLED_EXCEPTION;
    limits.BasicLimitInformation.ActiveProcessLimit = 1;
    limits.ProcessMemoryLimit = 64 * 1024 * 1024;
    ui.UIRestrictionsClass = JOB_OBJECT_UILIMIT_HANDLES | JOB_OBJECT_UILIMIT_READCLIPBOARD |
        JOB_OBJECT_UILIMIT_WRITECLIPBOARD | JOB_OBJECT_UILIMIT_SYSTEMPARAMETERS |
        JOB_OBJECT_UILIMIT_DISPLAYSETTINGS | JOB_OBJECT_UILIMIT_GLOBALATOMS |
        JOB_OBJECT_UILIMIT_DESKTOP | JOB_OBJECT_UILIMIT_EXITWINDOWS;
    if (!worker->job || !SetInformationJobObject(worker->job, JobObjectExtendedLimitInformation,
        &limits, sizeof(limits)) || (lpac && !SetInformationJobObject(worker->job, JobObjectBasicUIRestrictions,
        &ui, sizeof(ui)))) goto failed;

    /* The fixture requires an elevated broker. New process ownership is the
       administrators group, not the user's SID; the LPAC receives no process-object grant. */
    stage = "process-security-and-attributes";
    if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(
        L"O:BAG:BAD:P(A;;GA;;;SY)(A;;GA;;;BA)", SDDL_REVISION_1, &process_sa.lpSecurityDescriptor, NULL))
        goto failed;
    DWORD attribute_count = lpac ? 6 : 3;
    InitializeProcThreadAttributeList(NULL, attribute_count, 0, &attribute_size);
    startup.lpAttributeList = HeapAlloc(GetProcessHeap(), 0, attribute_size);
    if (!startup.lpAttributeList) { error = ERROR_NOT_ENOUGH_MEMORY; goto done; }
    if (!InitializeProcThreadAttributeList(startup.lpAttributeList, attribute_count, 0, &attribute_size))
        goto failed;
    attributes_initialized = TRUE;
    if (!UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
        inherited, inherited_count * sizeof(HANDLE), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_CHILD_PROCESS_POLICY,
        &child_policy, sizeof(child_policy), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_JOB_LIST,
        &worker->job, sizeof(worker->job), NULL, NULL)) goto failed;
    if (lpac && (!UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES,
        &capabilities, sizeof(capabilities), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_ALL_APPLICATION_PACKAGES_POLICY,
        &opt_out, sizeof(opt_out), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_MITIGATION_POLICY,
        &mitigations, sizeof(mitigations), NULL, NULL))) goto failed;
    startup.StartupInfo.cb = sizeof(startup);
    startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    /* No inherited console or standard I/O. Only the three private test handles
       in HANDLE_LIST can survive. The fixed probe uses WriteFile explicitly. */
    stage = "environment";
    if (lpac) {
        if (!ConvertSidToStringSidW(worker->app_sid, &app_sid_string)) goto failed;
        HRESULT hr = GetAppContainerFolderPath(app_sid_string, &app_folder);
        if (FAILED(hr)) { error = HRESULT_CODE(hr); goto done; }
    }
    if (!writ_child_environment(system_root, ARRAYSIZE(system_root), environment,
        ARRAYSIZE(environment), app_folder)) goto failed;
    stage = "create-process";
    DWORD creation_flags = EXTENDED_STARTUPINFO_PRESENT | CREATE_SUSPENDED |
        DETACHED_PROCESS | CREATE_UNICODE_ENVIRONMENT;
    BOOL created = lpac ?
        CreateProcessAsUserW(launch_token, worker->image_path, command, &process_sa, &process_sa, TRUE,
            creation_flags, environment, system_root, &startup.StartupInfo, &process) :
        CreateProcessW(worker->image_path, command, &process_sa, &process_sa, TRUE,
            creation_flags, environment, system_root, &startup.StartupInfo, &process);
    if (!created) goto failed;
    worker->process = process.hProcess; worker->thread = process.hThread; worker->pid = process.dwProcessId;
    stage = "native-lifetime";
    FILETIME exited, kernel, user;
    BOOL in_job = FALSE;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION actual_limits = {0};
    JOBOBJECT_BASIC_UI_RESTRICTIONS actual_ui = {0};
    PROCESS_MITIGATION_CHILD_PROCESS_POLICY actual_children = {0};
    PROCESS_MITIGATION_SYSTEM_CALL_DISABLE_POLICY actual_system_calls = {0};
    if (!GetProcessTimes(worker->process, &worker->created, &exited, &kernel, &user) ||
        !IsProcessInJob(worker->process, worker->job, &in_job)) goto failed;
    if (!in_job) { error = ERROR_ACCESS_DENIED; goto done; }
    stage = "job-limit-readback";
    if (!QueryInformationJobObject(worker->job, JobObjectExtendedLimitInformation,
        &actual_limits, sizeof(actual_limits), NULL)) goto failed;
    if (actual_limits.BasicLimitInformation.LimitFlags != limits.BasicLimitInformation.LimitFlags ||
        actual_limits.BasicLimitInformation.ActiveProcessLimit != 1 ||
        actual_limits.ProcessMemoryLimit != limits.ProcessMemoryLimit) {
        error = ERROR_ACCESS_DENIED; goto done;
    }
    stage = "child-policy-readback";
    if (!GetProcessMitigationPolicy(worker->process, ProcessChildProcessPolicy,
        &actual_children, sizeof(actual_children))) goto failed;
    if (!actual_children.NoChildProcessCreation) { error = ERROR_ACCESS_DENIED; goto done; }
    if (lpac) {
        stage = "ui-job-readback";
        if (!QueryInformationJobObject(worker->job, JobObjectBasicUIRestrictions, &actual_ui, sizeof(actual_ui), NULL)) goto failed;
        if (actual_ui.UIRestrictionsClass != ui.UIRestrictionsClass) { error = ERROR_ACCESS_DENIED; goto done; }
        stage = "win32k-policy-readback";
        if (!GetProcessMitigationPolicy(worker->process, ProcessSystemCallDisablePolicy,
            &actual_system_calls, sizeof(actual_system_calls))) goto failed;
        if (!actual_system_calls.DisallowWin32kSystemCalls) { error = ERROR_ACCESS_DENIED; goto done; }
    }
    stage = "native-token";
    BYTE actual_user[SECURITY_MAX_SID_SIZE];
    if (!OpenProcessToken(worker->process, TOKEN_QUERY | TOKEN_DUPLICATE, &token) ||
        !capture_user(token, actual_user) ||
        !token_blob(token, TokenStatistics, &worker->token, sizeof(worker->token))) goto failed;
    if (lpac && !EqualSid(actual_user, worker->user_sid)) { error = ERROR_ACCESS_DENIED; goto done; }
    if (!CopySid(sizeof(worker->user_sid), worker->user_sid, actual_user)) goto failed;
    stage = "lpac-token";
    if (lpac && !lpac_token(token, worker->app_sid, NULL, TRUE)) goto failed;
    if (lpac) printf("NATIVE_PASS actual LPAC token AccessCheck exact-package=allow restricted-packages=allow all-packages=deny user-only=deny\n");
    stage = "wfp";
    if (lpac && !install_network_filters(worker)) goto failed;
    ok = TRUE;
    goto done;
failed:
    error = GetLastError();
    if (!error) error = ERROR_ACCESS_DENIED;
done:
    if (!ok) fprintf(stderr, "FAIL worker setup stage=%s error=%lu\n", stage, error);
    close_handle(&token);
    close_handle(&launch_token);
    if (attributes_initialized) DeleteProcThreadAttributeList(startup.lpAttributeList);
    if (startup.lpAttributeList) HeapFree(GetProcessHeap(), 0, startup.lpAttributeList);
    if (process_sa.lpSecurityDescriptor) LocalFree(process_sa.lpSecurityDescriptor);
    if (app_folder) CoTaskMemFree(app_folder);
    if (app_sid_string) LocalFree(app_sid_string);
    if (!ok) { writ_worker_stop(worker); SetLastError(error); }
    return ok;
}

BOOL writ_worker_alive(const WRIT_WORKER *worker)
{
    FILETIME created, exited, kernel, user;
    return worker->process && WaitForSingleObject(worker->process, 0) == WAIT_TIMEOUT &&
        GetProcessId(worker->process) == worker->pid &&
        GetProcessTimes(worker->process, &created, &exited, &kernel, &user) &&
        CompareFileTime(&created, &worker->created) == 0;
}

BOOL writ_worker_matches(const WRIT_WORKER *worker, DWORD pid, HANDLE request_token)
{
    TOKEN_STATISTICS facts;
    BYTE sid[SECURITY_MAX_SID_SIZE];
    if (!pid || pid != worker->pid || !request_token || !writ_worker_alive(worker) ||
        !capture_user(request_token, sid) || !EqualSid(sid, (PSID)worker->user_sid) ||
        !token_blob(request_token, TokenStatistics, &facts, sizeof(facts)) ||
        facts.AuthenticationId.HighPart != worker->token.AuthenticationId.HighPart ||
        facts.AuthenticationId.LowPart != worker->token.AuthenticationId.LowPart)
        return FALSE;
    /* A native request token is inspected, never impersonated. Identification
       is sufficient for this equality check; anonymous tokens are not. */
    if (facts.TokenType == TokenImpersonation && facts.ImpersonationLevel < SecurityIdentification)
        return FALSE;
    return !worker->lpac || lpac_token(request_token, worker->app_sid, NULL, FALSE);
}

BOOL writ_worker_resume(WRIT_WORKER *worker)
{
    return writ_worker_alive(worker) && ResumeThread(worker->thread) != (DWORD)-1;
}

BOOL writ_worker_diagnostic(const WRIT_WORKER *worker, const unsigned short ports[4], DWORD phase)
{
    HANDLE launch = NULL, token = NULL, input = NULL, output = NULL, job = NULL;
    PROCESS_INFORMATION process = {0};
    STARTUPINFOEXW startup = {0};
    SECURITY_ATTRIBUTES security = {0}, inherited = { sizeof(inherited), NULL, TRUE };
    SECURITY_CAPABILITIES capabilities = {0};
    SID_AND_ATTRIBUTES registry = {0};
    PSID *groups = NULL, *sids = NULL;
    DWORD group_count = 0, sid_count = 0;
    LPWSTR package_string = NULL, folder = NULL;
    BYTE user[SECURITY_MAX_SID_SIZE], actual_user[SECURITY_MAX_SID_SIZE];
    TOKEN_STATISTICS actual_identity = {0};
    DWORD opt_out = PROCESS_CREATION_ALL_APPLICATION_PACKAGES_OPT_OUT;
    DWORD child_policy = PROCESS_CREATION_CHILD_PROCESS_RESTRICTED;
    DWORD error = ERROR_ACCESS_DENIED, exit_code = STILL_ACTIVE, available = 0, got = 0;
    SIZE_T attribute_size = 0;
    BOOL attributes_ready = FALSE, ok = FALSE, in_job = FALSE;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0}, actual_limits = {0};
    JOBOBJECT_BASIC_UI_RESTRICTIONS ui = {0}, actual_ui = {0};
    PROCESS_MITIGATION_CHILD_PROCESS_POLICY children = {0};
    PROCESS_MITIGATION_SYSTEM_CALL_DISABLE_POLICY system_calls = {0};
    wchar_t command[32768], root[MAX_PATH], environment[WRIT_ENVIRONMENT_CAPACITY];
    WRIT_PROBE_REPORT report = {0};
    const char *stage = "profile";
    if (!worker->lpac || !writ_worker_alive(worker) || (phase != 1 && phase != 2)) goto done;
    if (!reduced_primary(&launch, user) || !EqualSid(user, (PSID)worker->user_sid) ||
        !DeriveCapabilitySidsFromName(L"registryRead", &groups, &group_count, &sids, &sid_count)) goto failed;
    if (sid_count != 1 || !IsValidSid(sids[0])) { error = ERROR_INVALID_SID; goto done; }
    registry.Sid = sids[0]; registry.Attributes = SE_GROUP_ENABLED;
    capabilities.AppContainerSid = worker->app_sid;
    capabilities.Capabilities = &registry; capabilities.CapabilityCount = 1;
    stage = "job-and-handles";
    if (!writ_process_security(&security) || !CreatePipe(&input, &output, &inherited, 0) ||
        !SetHandleInformation(input, HANDLE_FLAG_INHERIT, 0)) goto failed;
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE |
        JOB_OBJECT_LIMIT_ACTIVE_PROCESS | JOB_OBJECT_LIMIT_PROCESS_MEMORY | JOB_OBJECT_LIMIT_PROCESS_TIME;
    limits.BasicLimitInformation.ActiveProcessLimit = 1;
    limits.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart = 10LL * 10000000LL;
    limits.ProcessMemoryLimit = 64 * 1024 * 1024;
    ui.UIRestrictionsClass = JOB_OBJECT_UILIMIT_HANDLES | JOB_OBJECT_UILIMIT_READCLIPBOARD |
        JOB_OBJECT_UILIMIT_WRITECLIPBOARD | JOB_OBJECT_UILIMIT_SYSTEMPARAMETERS |
        JOB_OBJECT_UILIMIT_DISPLAYSETTINGS | JOB_OBJECT_UILIMIT_GLOBALATOMS |
        JOB_OBJECT_UILIMIT_DESKTOP | JOB_OBJECT_UILIMIT_EXITWINDOWS;
    job = CreateJobObjectW(NULL, NULL);
    if (!job || !SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits)) ||
        !SetInformationJobObject(job, JobObjectBasicUIRestrictions, &ui, sizeof(ui))) goto failed;
    stage = "attributes";
    InitializeProcThreadAttributeList(NULL, 5, 0, &attribute_size);
    startup.lpAttributeList = HeapAlloc(GetProcessHeap(), 0, attribute_size);
    if (!startup.lpAttributeList ||
        !InitializeProcThreadAttributeList(startup.lpAttributeList, 5, 0, &attribute_size)) goto failed;
    attributes_ready = TRUE;
    if (!UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
        &output, sizeof(output), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_JOB_LIST,
            &job, sizeof(job), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_CHILD_PROCESS_POLICY,
            &child_policy, sizeof(child_policy), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES,
            &capabilities, sizeof(capabilities), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_ALL_APPLICATION_PACKAGES_POLICY,
            &opt_out, sizeof(opt_out), NULL, NULL)) goto failed;
    stage = "environment";
    if (!ConvertSidToStringSidW(worker->app_sid, &package_string)) goto failed;
    HRESULT hr = GetAppContainerFolderPath(package_string, &folder);
    if (FAILED(hr)) { error = HRESULT_CODE(hr); goto done; }
    if (!writ_child_environment(root, ARRAYSIZE(root), environment, ARRAYSIZE(environment), folder) ||
        FAILED(StringCchPrintfW(command, ARRAYSIZE(command), L"\"%s\" --lpac-diagnostic %llu %u %u %u %u",
            worker->image_path, (unsigned long long)(ULONG_PTR)output, ports[0], ports[1], ports[2], ports[3]))) goto failed;
    startup.StartupInfo.cb = sizeof(startup);
    startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    stage = "create-process";
    /* No canary bytes, mount name, input handle, policy pipe or admission route
       appears in this fixed diagnostic's arguments or inherited handle list. */
    if (!CreateProcessAsUserW(launch, worker->image_path, command, &security, &security, TRUE,
        EXTENDED_STARTUPINFO_PRESENT | CREATE_SUSPENDED | DETACHED_PROCESS | CREATE_UNICODE_ENVIRONMENT,
        environment, root, &startup.StartupInfo, &process)) goto failed;
    CloseHandle(output); output = NULL;
    stage = "actual-profile-readback";
    if (!IsProcessInJob(process.hProcess, job, &in_job) || !in_job ||
        !QueryInformationJobObject(job, JobObjectExtendedLimitInformation, &actual_limits, sizeof(actual_limits), NULL) ||
        !QueryInformationJobObject(job, JobObjectBasicUIRestrictions, &actual_ui, sizeof(actual_ui), NULL) ||
        !GetProcessMitigationPolicy(process.hProcess, ProcessChildProcessPolicy, &children, sizeof(children)) ||
        !GetProcessMitigationPolicy(process.hProcess, ProcessSystemCallDisablePolicy, &system_calls, sizeof(system_calls)) ||
        !OpenProcessToken(process.hProcess, TOKEN_QUERY | TOKEN_DUPLICATE, &token) ||
        !capture_user(token, actual_user) || !token_blob(token, TokenStatistics, &actual_identity, sizeof(actual_identity)) ||
        !lpac_token(token, worker->app_sid, registry.Sid, TRUE)) goto failed;
    if (actual_limits.BasicLimitInformation.LimitFlags != limits.BasicLimitInformation.LimitFlags ||
        actual_limits.BasicLimitInformation.ActiveProcessLimit != 1 ||
        actual_limits.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart != limits.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart ||
        actual_limits.ProcessMemoryLimit != limits.ProcessMemoryLimit || actual_ui.UIRestrictionsClass != ui.UIRestrictionsClass ||
        !children.NoChildProcessCreation || system_calls.DisallowWin32kSystemCalls ||
        !EqualSid(actual_user, (PSID)worker->user_sid) ||
        actual_identity.AuthenticationId.LowPart != worker->token.AuthenticationId.LowPart ||
        actual_identity.AuthenticationId.HighPart != worker->token.AuthenticationId.HighPart) {
        error = ERROR_ACCESS_DENIED; goto done;
    }
    printf("DIAGNOSTIC_PROFILE phase=%lu no_data=1 capabilities=registryRead win32k_disabled=0 pid=%lu\n",
        phase, process.dwProcessId);
    stage = "run-and-report";
    if (ResumeThread(process.hThread) == (DWORD)-1) goto failed;
    DWORD waited = WaitForSingleObject(process.hProcess, 20000);
    if (waited != WAIT_OBJECT_0) { if (waited == WAIT_FAILED) goto failed; error = ERROR_TIMEOUT; goto done; }
    if (!GetExitCodeProcess(process.hProcess, &exit_code) ||
        !PeekNamedPipe(input, NULL, 0, NULL, &available, NULL) || available != sizeof(report) ||
        !ReadFile(input, &report, sizeof(report), &got, NULL) || got != sizeof(report)) goto failed;
    printf("DIAGNOSTIC_RESULT phase=%lu passed=%08x failed=%08x tcp4=%u tcp6=%u udp4=%u udp6=%u child=%u clipboard_stage=%u clipboard=%08x com_stage=%u com=%08x wsa_startup=%u tcp4_stage=%u tcp6_stage=%u udp4_stage=%u udp6_stage=%u\n",
        phase, report.passed, report.failed, report.errors[7], report.errors[8], report.errors[9], report.errors[10],
        report.errors[12], report.clipboard_stage, report.errors[15], report.com_stage, report.errors[16],
        report.network_startup_error, report.network_stage[0], report.network_stage[1], report.network_stage[2], report.network_stage[3]);
    if (report.magic != WRIT_PROBE_MAGIC || report.phase != 5 || exit_code || report.failed ||
        report.passed != WRIT_PROBE_DIAGNOSTIC_MASK ||
        !writ_network_report_valid(&report, WRIT_PROBE_DIAGNOSTIC_MASK)) { error = ERROR_INVALID_DATA; goto done; }
    ok = TRUE;
    goto done;
failed:
    error = GetLastError();
done:
    if (job) TerminateJobObject(job, ERROR_OPERATION_ABORTED);
    /* Retire this retained child even if exceptional setup failed before the
       job association could be verified. Never leave a suspended orphan. */
    if (process.hProcess) TerminateProcess(process.hProcess, ERROR_OPERATION_ABORTED);
    if (process.hProcess && WaitForSingleObject(process.hProcess, 5000) != WAIT_OBJECT_0) {
        ok = FALSE; error = ERROR_TIMEOUT; stage = "process-retirement";
    }
    close_handle(&process.hThread); close_handle(&process.hProcess); close_handle(&job);
    close_handle(&token); close_handle(&launch); close_handle(&input); close_handle(&output);
    if (attributes_ready) DeleteProcThreadAttributeList(startup.lpAttributeList);
    if (startup.lpAttributeList) HeapFree(GetProcessHeap(), 0, startup.lpAttributeList);
    if (security.lpSecurityDescriptor) LocalFree(security.lpSecurityDescriptor);
    if (folder) CoTaskMemFree(folder);
    if (package_string) LocalFree(package_string);
    if (groups) for (DWORD i = 0; i < group_count; ++i) LocalFree(groups[i]);
    if (sids) for (DWORD i = 0; i < sid_count; ++i) LocalFree(sids[i]);
    if (groups) LocalFree(groups);
    if (sids) LocalFree(sids);
    if (!ok) {
        fprintf(stderr, "FAIL no-data LPAC diagnostic phase=%lu stage=%s error=%lu exit=%08lx\n", phase, stage, error, exit_code);
        SetLastError(error ? error : ERROR_ACCESS_DENIED);
    }
    return ok;
}

BOOL writ_worker_remove_network_filters(WRIT_WORKER *worker)
{
    if (!worker->network) return TRUE;
    DWORD error = FwpmEngineClose0(worker->network);
    if (error != ERROR_SUCCESS) { SetLastError(error); return FALSE; }
    worker->network = NULL;
    return TRUE;
}

BOOL writ_worker_terminate(WRIT_WORKER *worker)
{
    /* Keep identity and network objects valid while filesystem callbacks drain. */
    if (worker->job) TerminateJobObject(worker->job, ERROR_OPERATION_ABORTED);
    if (worker->process) {
        TerminateProcess(worker->process, ERROR_OPERATION_ABORTED);
        if (WaitForSingleObject(worker->process, 5000) != WAIT_OBJECT_0) return FALSE;
    }
    return TRUE;
}

BOOL writ_worker_stop(WRIT_WORKER *worker)
{
    BOOL ok = TRUE;
    /* The mount must quiesce callbacks before releasing this retained identity. */
    if (!writ_worker_terminate(worker)) return FALSE;
    if (!writ_worker_remove_network_filters(worker)) ok = FALSE;
    close_handle(&worker->thread); close_handle(&worker->process);
    close_handle(&worker->job); close_handle(&worker->image);
    if (worker->image_created && !DeleteFileW(worker->private_image)) ok = FALSE;
    if (worker->directory_created && !RemoveDirectoryW(worker->private_directory)) ok = FALSE;
    if (worker->profile_created && FAILED(DeleteAppContainerProfile(worker->profile))) ok = FALSE;
    if (worker->app_sid) FreeSid(worker->app_sid);
    ZeroMemory(worker, sizeof(*worker));
    return ok;
}
