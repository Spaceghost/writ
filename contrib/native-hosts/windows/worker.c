#define _WIN32_WINNT 0x0A00
#include "worker.h"
#include <bcrypt.h>
#include <fwpmu.h>
#include <rpc.h>
#include <sddl.h>
#include <strsafe.h>
#include <userenv.h>
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

static BOOL lpac_token(HANDLE token, PSID expected)
{
    DWORD app = 0, lpac = 0, elevated = 1;
    BYTE package_storage[sizeof(TOKEN_APPCONTAINER_INFORMATION) + SECURITY_MAX_SID_SIZE];
    BYTE capability_storage[sizeof(TOKEN_GROUPS) + 16 * sizeof(SID_AND_ATTRIBUTES) + 16 * SECURITY_MAX_SID_SIZE];
    BYTE label_storage[sizeof(TOKEN_MANDATORY_LABEL) + SECURITY_MAX_SID_SIZE];
    TOKEN_APPCONTAINER_INFORMATION *package = (TOKEN_APPCONTAINER_INFORMATION *)package_storage;
    TOKEN_GROUPS *capabilities = (TOKEN_GROUPS *)capability_storage;
    TOKEN_MANDATORY_LABEL *label = (TOKEN_MANDATORY_LABEL *)label_storage;
    if (!token_blob(token, TokenIsAppContainer, &app, sizeof(app)) || app != 1 ||
        !token_blob(token, TokenIsLessPrivilegedAppContainer, &lpac, sizeof(lpac)) || lpac != 1 ||
        !token_blob(token, TokenElevation, &elevated, sizeof(elevated)) || elevated != 0 ||
        !token_blob(token, TokenAppContainerSid, package_storage, sizeof(package_storage)) ||
        !package->TokenAppContainer || !IsValidSid(package->TokenAppContainer) ||
        !EqualSid(package->TokenAppContainer, expected) ||
        !token_blob(token, TokenCapabilities, capability_storage, sizeof(capability_storage)) ||
        capabilities->GroupCount != 0 ||
        !token_blob(token, TokenIntegrityLevel, label_storage, sizeof(label_storage)) ||
        !IsValidSid(label->Label.Sid)) return FALSE;
    BYTE subauthorities = *GetSidSubAuthorityCount(label->Label.Sid);
    return subauthorities > 0 &&
        *GetSidSubAuthority(label->Label.Sid, subauthorities - 1) <= SECURITY_MANDATORY_LOW_RID;
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
    LPWSTR app_sid = NULL;
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
        FAILED(StringCchPrintfW(worker->private_directory, ARRAYSIZE(worker->private_directory),
            L"%s%s", temporary, worker->profile)) ||
        FAILED(StringCchPrintfW(worker->private_image, ARRAYSIZE(worker->private_image),
            L"%s\\reader.exe", worker->private_directory)) ||
        FAILED(StringCchPrintfW(sddl, ARRAYSIZE(sddl),
            L"O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;GRGX;;;%s)", app_sid)) ||
        !ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, SDDL_REVISION_1,
            &descriptor, NULL)) goto done;
    security.lpSecurityDescriptor = descriptor;
    if (!CreateDirectoryW(worker->private_directory, &security)) {
        /* No adoption or cleanup of an existing directory. */
        worker->private_directory[0] = 0; worker->private_image[0] = 0;
        goto done;
    }
    output = CreateFileW(worker->private_image, GENERIC_WRITE, 0, &security,
        CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (output == INVALID_HANDLE_VALUE || !SetFilePointerEx(worker->image, zero, NULL, FILE_BEGIN))
        goto done;
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
    HANDLE token = NULL;
    DWORD opt_out = PROCESS_CREATION_ALL_APPLICATION_PACKAGES_OPT_OUT;
    DWORD child_policy = PROCESS_CREATION_CHILD_PROCESS_RESTRICTED;
    DWORD64 mitigations = PROCESS_CREATION_MITIGATION_POLICY_WIN32K_SYSTEM_CALL_DISABLE_ALWAYS_ON;
    DWORD error = ERROR_INVALID_PARAMETER;
    wchar_t system_root[MAX_PATH], environment[MAX_PATH + 32];
    ZeroMemory(worker, sizeof(*worker));
    worker->lpac = lpac;
    if (!inherited_count || inherited_count > 3 || wcschr(image, L'"') || !image_identity(worker, image))
        goto failed;
    if (lpac) {
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
        if (!private_image(worker)) goto failed;
    }

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
        &limits, sizeof(limits)) || !SetInformationJobObject(worker->job, JobObjectBasicUIRestrictions,
        &ui, sizeof(ui))) goto failed;

    /* The fixture requires an elevated broker. New process ownership is the
       administrators group, not the user's SID; the LPAC receives no process-object grant. */
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
    ZeroMemory(environment, sizeof(environment));
    DWORD root_length = GetWindowsDirectoryW(system_root, ARRAYSIZE(system_root));
    if (!root_length || root_length >= ARRAYSIZE(system_root) ||
        FAILED(StringCchPrintfW(environment, ARRAYSIZE(environment) - 1, L"SystemRoot=%s", system_root)))
        goto failed;
    if (!CreateProcessW(worker->image_path, command, &process_sa, &process_sa, TRUE,
        EXTENDED_STARTUPINFO_PRESENT | CREATE_SUSPENDED | CREATE_NO_WINDOW |
        CREATE_UNICODE_ENVIRONMENT, environment, system_root, &startup.StartupInfo, &process))
        goto failed;
    worker->process = process.hProcess; worker->thread = process.hThread; worker->pid = process.dwProcessId;
    FILETIME exited, kernel, user;
    BOOL in_job = FALSE;
    if (!GetProcessTimes(worker->process, &worker->created, &exited, &kernel, &user) ||
        !IsProcessInJob(worker->process, worker->job, &in_job) || !in_job ||
        !OpenProcessToken(worker->process, TOKEN_QUERY, &token) ||
        !capture_user(token, worker->user_sid) ||
        !token_blob(token, TokenStatistics, &worker->token, sizeof(worker->token)) ||
        (lpac && !lpac_token(token, worker->app_sid))) goto failed;
    if (lpac && !install_network_filters(worker)) goto failed;
    ok = TRUE;
    goto done;
failed:
    error = GetLastError();
    if (!error) error = ERROR_ACCESS_DENIED;
done:
    close_handle(&token);
    if (attributes_initialized) DeleteProcThreadAttributeList(startup.lpAttributeList);
    if (startup.lpAttributeList) HeapFree(GetProcessHeap(), 0, startup.lpAttributeList);
    if (process_sa.lpSecurityDescriptor) LocalFree(process_sa.lpSecurityDescriptor);
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
    return !worker->lpac || lpac_token(request_token, worker->app_sid);
}

BOOL writ_worker_resume(WRIT_WORKER *worker)
{
    return writ_worker_alive(worker) && ResumeThread(worker->thread) != (DWORD)-1;
}

BOOL writ_worker_remove_network_filters(WRIT_WORKER *worker)
{
    if (!worker->network) return TRUE;
    DWORD error = FwpmEngineClose0(worker->network);
    if (error != ERROR_SUCCESS) { SetLastError(error); return FALSE; }
    worker->network = NULL;
    return TRUE;
}

BOOL writ_worker_stop(WRIT_WORKER *worker)
{
    BOOL ok = TRUE;
    /* Keep network controls until the process has stopped retaining plaintext. */
    if (worker->job) TerminateJobObject(worker->job, ERROR_OPERATION_ABORTED);
    if (worker->process) {
        TerminateProcess(worker->process, ERROR_OPERATION_ABORTED);
        if (WaitForSingleObject(worker->process, 5000) != WAIT_OBJECT_0) return FALSE;
    }
    if (!writ_worker_remove_network_filters(worker)) ok = FALSE;
    close_handle(&worker->thread); close_handle(&worker->process);
    close_handle(&worker->job); close_handle(&worker->image);
    if (worker->private_image[0] && !DeleteFileW(worker->private_image)) ok = FALSE;
    if (worker->private_directory[0] && !RemoveDirectoryW(worker->private_directory)) ok = FALSE;
    if (worker->profile_created && FAILED(DeleteAppContainerProfile(worker->profile))) ok = FALSE;
    if (worker->app_sid) FreeSid(worker->app_sid);
    ZeroMemory(worker, sizeof(*worker));
    return ok;
}
