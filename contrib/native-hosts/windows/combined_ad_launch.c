/* Diagnostic-only launcher: no Writ session, policy, or caller-supplied data. */
#include <stdio.h>
#include <stdarg.h>
static int writ_ad_log(const char *format, ...)
{
    va_list args;
    int result;
    fputs("NO_DATA_AD_LAUNCH ", stdout);
    va_start(args, format); result = vfprintf(stdout, format, args); va_end(args);
    return result;
}
#define printf writ_ad_log
/* Access the unchanged canary launch primitives only inside this diagnostic TU. */
#include "worker.c"
#undef printf
#include "combined_ad_launch.h"
#include "combined_ad_checked.h"

static BOOL close_ad(HANDLE *handle, const char *label)
{
    if (!*handle || *handle == INVALID_HANDLE_VALUE) return TRUE;
    BOOL ok = CloseHandle(*handle);
    if (!ok) fprintf(stderr, "AD_CLEANUP_FAILED %s error=%lu\n", label, GetLastError());
    *handle = NULL;
    return ok;
}
static BOOL derive_capability(WRIT_AD_SHARED *shared)
{
    /* The documented contract does not guarantee usable outputs on failure. */
    if (!DeriveCapabilitySidsFromName(L"registryRead", &shared->groups, &shared->group_count,
        &shared->capabilities, &shared->capability_count)) {
        shared->cleanup_uncertain = TRUE;
        return FALSE;
    }
    if (shared->group_count > 16 || shared->capability_count != 1 ||
        (shared->group_count && !shared->groups) || !shared->capabilities) {
        shared->cleanup_uncertain = TRUE; SetLastError(ERROR_INVALID_DATA); return FALSE;
    }
    for (DWORD i = 0; i < shared->group_count; ++i) if (!shared->groups[i] || !IsValidSid(shared->groups[i])) {
        shared->cleanup_uncertain = TRUE; SetLastError(ERROR_INVALID_SID); return FALSE;
    }
    if (!shared->capabilities[0] || !IsValidSid(shared->capabilities[0])) {
        shared->cleanup_uncertain = TRUE; SetLastError(ERROR_INVALID_SID); return FALSE;
    }
    shared->derived = TRUE;
    return TRUE;
}
/* Diagnostic-owned dynamic session. Failed output values are never adopted. */
static BOOL ad_install_network_filters(WRIT_AD_SHARED *shared)
{
    FWPM_SESSION0 session = {0};
    FWPM_SUBLAYER0 sublayer = {0};
    FWPM_FILTER_CONDITION0 condition = {0};
    const GUID *layers[4] = { &FWPM_LAYER_ALE_AUTH_CONNECT_V4, &FWPM_LAYER_ALE_AUTH_CONNECT_V6,
        &FWPM_LAYER_ALE_AUTH_RECV_ACCEPT_V4, &FWPM_LAYER_ALE_AUTH_RECV_ACCEPT_V6 };
    HANDLE network = NULL;
    BOOL transaction = FALSE;
    DWORD status;
    session.displayData.name = L"Writ no-data AD diagnostic";
    session.flags = FWPM_SESSION_FLAG_DYNAMIC;
    status = FwpmEngineOpen0(NULL, RPC_C_AUTHN_WINNT, NULL, &session, &network);
    if (status != ERROR_SUCCESS) { network = NULL; goto failed; }
    if (!network) { status = ERROR_INVALID_DATA; goto failed; }
    shared->owner.network = network;
    status = FwpmTransactionBegin0(network, 0);
    if (status != ERROR_SUCCESS) goto failed;
    transaction = TRUE;
    RPC_STATUS uuid_status = UuidCreate(&sublayer.subLayerKey);
    if (uuid_status != RPC_S_OK) {
        fprintf(stderr, "INCOMPLETE AD wfp-uuid domain=rpc status=%lu\n", (unsigned long)uuid_status);
        status = ERROR_INVALID_DATA; goto failed;
    }
    sublayer.displayData.name = L"Writ diagnostic egress blocks";
    sublayer.weight = 0xffff;
    status = FwpmSubLayerAdd0(network, &sublayer, NULL);
    if (status != ERROR_SUCCESS) goto failed;
    condition.fieldKey = FWPM_CONDITION_ALE_PACKAGE_ID;
    condition.matchType = FWP_MATCH_EQUAL;
    condition.conditionValue.type = FWP_SID;
    condition.conditionValue.sid = shared->owner.app_sid;
    for (DWORD i = 0; i < 4; ++i) {
        FWPM_FILTER0 filter = {0};
        UINT64 id = 0;
        filter.displayData.name = L"Writ diagnostic no network";
        filter.layerKey = *layers[i];
        filter.subLayerKey = sublayer.subLayerKey;
        filter.action.type = FWP_ACTION_BLOCK;
        filter.weight.type = FWP_UINT8;
        filter.weight.uint8 = 15;
        filter.numFilterConditions = 1;
        filter.filterCondition = &condition;
        status = FwpmFilterAdd0(network, &filter, NULL, &id);
        if (status != ERROR_SUCCESS) goto failed;
        if (!id) { status = ERROR_INVALID_DATA; goto failed; }
        shared->owner.filters[i] = id;
    }
    status = FwpmTransactionCommit0(network);
    if (status != ERROR_SUCCESS) goto failed;
    transaction = FALSE;
    if (!writ_ad_filters_checked(shared)) { status = GetLastError(); goto failed; }
    return TRUE;
failed:
    fprintf(stderr, "INCOMPLETE AD wfp-install domain=win32 status=%lu cleanup_unverified=1\n", status);
    shared->cleanup_uncertain = TRUE;
    if (transaction) {
        DWORD aborted = FwpmTransactionAbort0(network);
        if (aborted != ERROR_SUCCESS) fprintf(stderr, "AD_CLEANUP_FAILED wfp-abort status=%lu\n", aborted);
    }
    /* The retained owned session is closed and its IDs checked by shared_stop. */
    SetLastError(status);
    return FALSE;
}
BOOL writ_ad_shared_create(WRIT_AD_SHARED *shared, const wchar_t *fixed_image)
{
    BYTE nonce[16];
    LPWSTR sid_string = NULL, folder = NULL;
    BOOL ok = FALSE;
    const char *stage = "derive-capability";
    if (!shared || !fixed_image || !writ_ad_can_init(shared->initialized,
        shared->owner.image || shared->owner.network || shared->owner.app_sid ||
        shared->launch_token || shared->groups || shared->capabilities ||
        shared->owner.profile_created || shared->owner.image_created || shared->owner.directory_created)) {
        SetLastError(ERROR_INVALID_PARAMETER); return FALSE;
    }
    ZeroMemory(shared, sizeof(*shared));
    shared->initialized = TRUE;
    if (!derive_capability(shared)) goto done;
    stage = "source-image";
    if (!writ_ad_image_identity(&shared->owner, fixed_image)) goto done;
    stage = "reduced-primary";
    if (!writ_ad_reduced_primary(&shared->launch_token, shared->owner.user_sid)) goto done;
    stage = "fresh-profile";
    NTSTATUS random_status = BCryptGenRandom(NULL, nonce, sizeof(nonce), BCRYPT_USE_SYSTEM_PREFERRED_RNG);
    if (random_status < 0) {
        fprintf(stderr, "INCOMPLETE AD stage=nonce domain=ntstatus status=0x%08lx\n", (unsigned long)(ULONG)random_status); goto done;
    }
    HRESULT hr = StringCchPrintfW(shared->owner.profile, ARRAYSIZE(shared->owner.profile),
            L"Writ.AD.%08lx.%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            GetCurrentProcessId(), nonce[0], nonce[1], nonce[2], nonce[3], nonce[4], nonce[5], nonce[6], nonce[7],
            nonce[8], nonce[9], nonce[10], nonce[11], nonce[12], nonce[13], nonce[14], nonce[15]);
    if (FAILED(hr)) { fprintf(stderr, "INCOMPLETE AD stage=profile-name domain=hresult status=0x%08lx\n", (unsigned long)(ULONG)hr); goto done; }
    PSID created_sid = NULL;
    hr = CreateAppContainerProfile(shared->owner.profile, L"Writ diagnostic AD", L"No-data diagnostic", NULL, 0, &created_sid);
    if (FAILED(hr)) { fprintf(stderr, "INCOMPLETE AD stage=profile-create domain=hresult status=0x%08lx\n", (unsigned long)(ULONG)hr); goto done; }
    shared->owner.profile_created = TRUE;
    if (!created_sid || !IsValidSid(created_sid)) {
        shared->cleanup_uncertain = TRUE; fprintf(stderr, "INCOMPLETE AD stage=profile-sid status=invalid-or-unknown\n"); goto done;
    }
    shared->owner.app_sid = created_sid;
    stage = "private-image";
    if (!writ_ad_private_image(&shared->owner)) goto done;
    stage = "environment";
    if (!ConvertSidToStringSidW(shared->owner.app_sid, &sid_string)) { DWORD e = GetLastError(); sid_string = NULL; fprintf(stderr, "INCOMPLETE AD package-string domain=win32 status=%lu output=unverified\n", e); goto done; }
    hr = GetAppContainerFolderPath(sid_string, &folder);
    if (FAILED(hr)) { folder = NULL; fprintf(stderr, "INCOMPLETE AD stage=profile-folder domain=hresult status=0x%08lx output=unverified\n", (unsigned long)(ULONG)hr); goto done; }
    if (!writ_child_environment(shared->root, ARRAYSIZE(shared->root), shared->environment,
        ARRAYSIZE(shared->environment), folder)) goto done;
    BOOL terminated = FALSE;
    for (size_t i = 0; i + 1 < ARRAYSIZE(shared->environment); ++i) {
        if (!shared->environment[i] && !shared->environment[i+1]) { terminated = TRUE; break; }
    }
    if (!terminated) { SetLastError(ERROR_INVALID_DATA); goto done; }
    memcpy(shared->expected_root, shared->root, sizeof(shared->root));
    memcpy(shared->expected_environment, shared->environment, sizeof(shared->environment));
    shared->environment_frozen = TRUE;
    stage = "owned-wfp";
    if (!ad_install_network_filters(shared)) goto done;
    ok = TRUE;
done:
    /* CoTaskMemFree has no return status. The OS-owned folder cannot be
       independently checked; this is inventoried as a diagnostic limit. */
    if (folder) CoTaskMemFree(folder);
    if (sid_string && LocalFree(sid_string) != NULL) {
        stage = "package-sid-string-free";
        shared->cleanup_uncertain = TRUE;
        ok = FALSE;
    }
    if (!ok) {
        shared->cleanup_uncertain = TRUE;
        fprintf(stderr, "INCOMPLETE AD setup stage=%s status=see-stage-diagnostic cleanup_unverified=1\n", stage);
    }
    return ok;
}
BOOL writ_ad_environment_checked(const WRIT_AD_SHARED *shared)
{
    return shared && shared->environment_frozen &&
        !memcmp(shared->root, shared->expected_root, sizeof(shared->root)) &&
        !memcmp(shared->environment, shared->expected_environment, sizeof(shared->environment));
}
BOOL writ_ad_filters_checked(WRIT_AD_SHARED *shared)
{
    const GUID *layers[4] = { &FWPM_LAYER_ALE_AUTH_CONNECT_V4, &FWPM_LAYER_ALE_AUTH_CONNECT_V6,
        &FWPM_LAYER_ALE_AUTH_RECV_ACCEPT_V4, &FWPM_LAYER_ALE_AUTH_RECV_ACCEPT_V6 };
    if (!shared || !shared->owner.network || !shared->owner.app_sid) return FALSE;
    for (DWORD i = 0; i < 4; ++i) {
        FWPM_FILTER0 *readback = NULL;
        DWORD status = shared->owner.filters[i] ? FwpmFilterGetById0(shared->owner.network, shared->owner.filters[i], &readback) : ERROR_INVALID_DATA;
        if (status != ERROR_SUCCESS) { shared->cleanup_uncertain = TRUE; SetLastError(status); return FALSE; }
        BOOL match = readback && readback->action.type == FWP_ACTION_BLOCK &&
            IsEqualGUID(&readback->layerKey, layers[i]) && readback->numFilterConditions == 1 && readback->filterCondition &&
            IsEqualGUID(&readback->filterCondition[0].fieldKey, &FWPM_CONDITION_ALE_PACKAGE_ID) &&
            readback->filterCondition[0].matchType == FWP_MATCH_EQUAL &&
            readback->filterCondition[0].conditionValue.type == FWP_SID &&
            readback->filterCondition[0].conditionValue.sid && IsValidSid(readback->filterCondition[0].conditionValue.sid) &&
            EqualSid(readback->filterCondition[0].conditionValue.sid, shared->owner.app_sid);
        if (readback) FwpmFreeMemory0((void **)&readback);
        if (!match) { SetLastError(ERROR_INVALID_DATA); return FALSE; }
    }
    return TRUE;
}

/* Same native LPAC access facts as the canary, with checked local cleanup. */
static BOOL ad_access_check(WRIT_AD_SHARED *shared, HANDLE token)
{
    HANDLE duplicate = NULL;
    LPWSTR package_string = NULL, user_string = NULL;
    const wchar_t *classes[4];
    const BOOL expected[4] = { TRUE, TRUE, FALSE, FALSE };
    BOOL ok = FALSE;
    DWORD error = ERROR_INVALID_DATA, needed = 0;
    TOKEN_TYPE type;
    if (!GetTokenInformation(token, TokenType, &type, sizeof(type), &needed) || needed != sizeof(type)) goto failed;
    if (type != TokenPrimary) { error = ERROR_INVALID_DATA; goto done; }
    if (!DuplicateTokenEx(token, TOKEN_QUERY, NULL, SecurityIdentification, TokenImpersonation, &duplicate)) { duplicate = NULL; shared->cleanup_uncertain = TRUE; goto failed; }
    if (!ConvertSidToStringSidW(shared->owner.app_sid, &package_string)) { package_string = NULL; shared->cleanup_uncertain = TRUE; goto failed; }
    if (!ConvertSidToStringSidW(shared->owner.user_sid, &user_string)) { user_string = NULL; shared->cleanup_uncertain = TRUE; goto failed; }
    classes[0] = package_string; classes[1] = L"S-1-15-2-2";
    classes[2] = L"S-1-15-2-1"; classes[3] = NULL;
    for (unsigned int i = 0; i < 4; ++i) {
        wchar_t sddl[1024];
        PSECURITY_DESCRIPTOR descriptor = NULL;
        GENERIC_MAPPING mapping = { FILE_GENERIC_READ, FILE_GENERIC_WRITE, FILE_GENERIC_EXECUTE, FILE_ALL_ACCESS };
        PRIVILEGE_SET privileges = {0};
        DWORD privilege_size = sizeof(privileges), granted = 0;
        BOOL permitted = FALSE;
        HRESULT formatted = classes[i] ?
            StringCchPrintfW(sddl, ARRAYSIZE(sddl), L"O:SYG:SYD:P(A;;0x1;;;%s)(A;;0x1;;;%s)", user_string, classes[i]) :
            StringCchPrintfW(sddl, ARRAYSIZE(sddl), L"O:SYG:SYD:P(A;;0x1;;;%s)", user_string);
        if (FAILED(formatted)) { error = ERROR_INSUFFICIENT_BUFFER; goto done; }
        if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, SDDL_REVISION_1, &descriptor, NULL)) { descriptor = NULL; shared->cleanup_uncertain = TRUE; goto failed; }
        BOOL completed = AccessCheck(descriptor, duplicate, FILE_READ_DATA, &mapping,
            &privileges, &privilege_size, &granted, &permitted);
        DWORD access_error = completed ? ERROR_SUCCESS : GetLastError();
        if (LocalFree(descriptor) != NULL) {
            fprintf(stderr, "AD_CLEANUP_FAILED access-descriptor error=%lu\n", GetLastError());
            shared->cleanup_uncertain = TRUE; error = ERROR_INVALID_DATA; goto done;
        }
        if (!completed) { error = access_error; goto done; }
        if (permitted != expected[i] || granted != (expected[i] ? FILE_READ_DATA : 0) || privileges.PrivilegeCount) {
            error = ERROR_INVALID_DATA; goto done;
        }
    }
    ok = TRUE;
    goto done;
failed:
    error = GetLastError();
done:
    if (!close_ad(&duplicate, "access-check-token")) { shared->cleanup_uncertain = TRUE; ok = FALSE; }
    if (package_string && LocalFree(package_string) != NULL) {
        fprintf(stderr, "AD_CLEANUP_FAILED access-package-string error=%lu\n", GetLastError());
        shared->cleanup_uncertain = TRUE; ok = FALSE;
    }
    if (user_string && LocalFree(user_string) != NULL) {
        fprintf(stderr, "AD_CLEANUP_FAILED access-user-string error=%lu\n", GetLastError());
        shared->cleanup_uncertain = TRUE; ok = FALSE;
    }
    if (!ok) SetLastError(error ? error : ERROR_INVALID_DATA);
    return ok;
}

BOOL writ_ad_child_create(WRIT_AD_SHARED *shared, WRIT_AD_ARM arm,
    HANDLE report_writer, WRIT_AD_CHILD *child, WRIT_AD_TOKEN *facts)
{
    STARTUPINFOEXW startup = {0};
    PROCESS_INFORMATION process = {0};
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limit = {0}, actual = {0};
    JOBOBJECT_BASIC_UI_RESTRICTIONS ui = {0}, actual_ui = {0};
    PROCESS_MITIGATION_CHILD_PROCESS_POLICY actual_children = {0};
    PROCESS_MITIGATION_SYSTEM_CALL_DISABLE_POLICY actual_system_calls = {0};
    SECURITY_ATTRIBUTES process_sa = { sizeof(process_sa), NULL, FALSE };
    SECURITY_CAPABILITIES caps = {0};
    SID_AND_ATTRIBUTES registry = {0};
    HANDLE token = NULL;
    SIZE_T attribute_size = 0;
    BOOL ready = FALSE, ok = FALSE, in_job = FALSE;
    DWORD opt_out = PROCESS_CREATION_ALL_APPLICATION_PACKAGES_OPT_OUT;
    DWORD child_policy = PROCESS_CREATION_CHILD_PROCESS_RESTRICTED;
    DWORD64 mitigation = arm == WRIT_AD_ZERO ?
        PROCESS_CREATION_MITIGATION_POLICY_WIN32K_SYSTEM_CALL_DISABLE_ALWAYS_ON :
        PROCESS_CREATION_MITIGATION_POLICY_WIN32K_SYSTEM_CALL_DISABLE_ALWAYS_OFF;
    DWORD error = ERROR_INVALID_PARAMETER;
    wchar_t command[128];
    const char *stage = "parameters";
    if (!shared || !child || !writ_ad_can_launch(shared->cleanup_uncertain || shared->cleanup_attempted,
        shared->child_exit_unverified, child->process || child->thread || child->job || child->cleanup_attempted)) { SetLastError(ERROR_INVALID_PARAMETER); return FALSE; }
    ZeroMemory(child, sizeof(*child));
    if (!facts || !report_writer || !shared->derived ||
        (arm != WRIT_AD_ZERO && arm != WRIT_AD_COMBINED) || !writ_ad_environment_checked(shared) ||
        !writ_ad_filters_checked(shared)) goto done;
    if (FAILED(StringCchPrintfW(command, ARRAYSIZE(command), L"writ-init-child %llu",
        (unsigned long long)(ULONG_PTR)report_writer))) goto done;
    caps.AppContainerSid = shared->owner.app_sid;
    if (arm == WRIT_AD_COMBINED) {
        registry.Sid = shared->capabilities[0]; registry.Attributes = SE_GROUP_ENABLED;
        caps.Capabilities = &registry; caps.CapabilityCount = 1;
    }
    stage = "job";
    child->job = CreateJobObjectW(NULL, NULL);
    limit.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE |
        JOB_OBJECT_LIMIT_ACTIVE_PROCESS | JOB_OBJECT_LIMIT_PROCESS_MEMORY | JOB_OBJECT_LIMIT_DIE_ON_UNHANDLED_EXCEPTION;
    limit.BasicLimitInformation.ActiveProcessLimit = 1;
    limit.ProcessMemoryLimit = 64 * 1024 * 1024;
    ui.UIRestrictionsClass = JOB_OBJECT_UILIMIT_HANDLES | JOB_OBJECT_UILIMIT_READCLIPBOARD |
        JOB_OBJECT_UILIMIT_WRITECLIPBOARD | JOB_OBJECT_UILIMIT_SYSTEMPARAMETERS |
        JOB_OBJECT_UILIMIT_DISPLAYSETTINGS | JOB_OBJECT_UILIMIT_GLOBALATOMS |
        JOB_OBJECT_UILIMIT_DESKTOP | JOB_OBJECT_UILIMIT_EXITWINDOWS;
    if (!child->job || !SetInformationJobObject(child->job, JobObjectExtendedLimitInformation, &limit, sizeof(limit)) ||
        !SetInformationJobObject(child->job, JobObjectBasicUIRestrictions, &ui, sizeof(ui))) goto failed;
    stage = "attributes";
    if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(L"O:BAG:BAD:P(A;;GA;;;SY)(A;;GA;;;BA)",
        SDDL_REVISION_1, &process_sa.lpSecurityDescriptor, NULL)) { process_sa.lpSecurityDescriptor = NULL; shared->cleanup_uncertain = TRUE; goto failed; }
    InitializeProcThreadAttributeList(NULL, 6, 0, &attribute_size);
    if (!attribute_size) goto failed;
    startup.lpAttributeList = HeapAlloc(GetProcessHeap(), 0, attribute_size);
    if (!startup.lpAttributeList) { error = ERROR_NOT_ENOUGH_MEMORY; goto done; }
    if (!InitializeProcThreadAttributeList(startup.lpAttributeList, 6, 0, &attribute_size)) goto failed;
    ready = TRUE;
    if (!UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, &report_writer, sizeof(report_writer), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_CHILD_PROCESS_POLICY, &child_policy, sizeof(child_policy), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_JOB_LIST, &child->job, sizeof(child->job), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES, &caps, sizeof(caps), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_ALL_APPLICATION_PACKAGES_POLICY, &opt_out, sizeof(opt_out), NULL, NULL) ||
        !UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_MITIGATION_POLICY, &mitigation, sizeof(mitigation), NULL, NULL)) goto failed;
    startup.StartupInfo.cb = sizeof(startup);
    startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    stage = "create-suspended";
    /* Until creation returns a retained process and its exit is observed,
       shared WFP/profile retirement is unverified even on API failure. */
    shared->child_exit_unverified = TRUE;
    if (!CreateProcessAsUserW(shared->launch_token, shared->owner.image_path, command, &process_sa, &process_sa, TRUE,
        EXTENDED_STARTUPINFO_PRESENT | CREATE_SUSPENDED | DETACHED_PROCESS | CREATE_UNICODE_ENVIRONMENT,
        shared->environment, shared->root, &startup.StartupInfo, &process)) goto failed;
    child->process = process.hProcess; child->thread = process.hThread; child->pid = process.dwProcessId;
    if (!writ_ad_environment_checked(shared)) { error = ERROR_INVALID_DATA; goto done; }
    FILETIME exited, kernel, user;
    stage = "native-readback";
    if (!GetProcessTimes(child->process, &child->created, &exited, &kernel, &user) ||
        !IsProcessInJob(child->process, child->job, &in_job) || !in_job ||
        !QueryInformationJobObject(child->job, JobObjectExtendedLimitInformation, &actual, sizeof(actual), NULL) ||
        !QueryInformationJobObject(child->job, JobObjectBasicUIRestrictions, &actual_ui, sizeof(actual_ui), NULL) ||
        !GetProcessMitigationPolicy(child->process, ProcessChildProcessPolicy, &actual_children, sizeof(actual_children)) ||
        !GetProcessMitigationPolicy(child->process, ProcessSystemCallDisablePolicy, &actual_system_calls, sizeof(actual_system_calls))) goto failed;
    if (!OpenProcessToken(child->process, TOKEN_QUERY | TOKEN_DUPLICATE, &token)) { token = NULL; shared->cleanup_uncertain = TRUE; goto failed; }
    if (actual.BasicLimitInformation.LimitFlags != limit.BasicLimitInformation.LimitFlags ||
        actual.BasicLimitInformation.ActiveProcessLimit != 1 || actual.ProcessMemoryLimit != limit.ProcessMemoryLimit ||
        actual_ui.UIRestrictionsClass != ui.UIRestrictionsClass || !actual_children.NoChildProcessCreation) { error = ERROR_INVALID_DATA; goto done; }
    if (!writ_ad_token_snapshot(token, facts)) goto failed;
    PSID integrity = (PSID)facts->integrity.bytes;
    BYTE integrity_count = *GetSidSubAuthorityCount(integrity);
    if (facts->appcontainer != 1 || facts->elevated != 0 || !integrity_count ||
        *GetSidSubAuthority(integrity, integrity_count - 1) > SECURITY_MANDATORY_LOW_RID ||
        !EqualSid((PSID)facts->user.bytes, shared->owner.user_sid) ||
        !EqualSid((PSID)facts->package.bytes, shared->owner.app_sid)) { error = ERROR_INVALID_DATA; goto done; }
    if (!ad_access_check(shared, token)) goto failed;
    /* Classify the actual bounded token capability, never the launch input.
       Reject any attribute bits other than exactly SE_GROUP_ENABLED. */
    int sid_matches = 0, enabled = 0;
    if (facts->capability_count == 1) {
        sid_matches = EqualSid((PSID)facts->capabilities[0].bytes, shared->capabilities[0]) != FALSE;
        enabled = facts->capabilities[0].attributes == SE_GROUP_ENABLED;
    }
    if (!writ_ad_capabilities(arm, facts->capability_count, sid_matches, enabled)) {
        error = ERROR_INVALID_DATA; goto done;
    }
    DWORD other = actual_system_calls.Flags & ~1u;
    if (!shared->mitigation_baseline_set) {
        shared->mitigation_other = other;
        shared->mitigation_baseline_set = TRUE;
    }
    int mitigation_valid = writ_ad_mitigation(arm, mitigation, actual_system_calls.Flags, shared->mitigation_other);
    printf("AD_MITIGATION arm=%c pid=%lu creation_policy=%016llx observed_disabled=%u observed_flags=%08lx validation=%s no_data=1\n",
        arm == WRIT_AD_ZERO ? 'A' : 'D', child->pid, (unsigned long long)mitigation,
        actual_system_calls.DisallowWin32kSystemCalls ? 1u : 0u, (unsigned long)actual_system_calls.Flags,
        mitigation_valid ? "pass" : "incomplete");
    if (!mitigation_valid) { error = ERROR_INVALID_DATA; goto done; }
    if (!writ_ad_filters_checked(shared)) goto failed;
    ok = TRUE;
    goto done;
failed:
    error = GetLastError();
done:
    if (token && !CloseHandle(token)) {
        fprintf(stderr, "AD_CLEANUP_FAILED token error=%lu\n", GetLastError());
        shared->cleanup_uncertain = TRUE; ok = FALSE;
    }
    if (ready) DeleteProcThreadAttributeList(startup.lpAttributeList);
    if (startup.lpAttributeList && !HeapFree(GetProcessHeap(), 0, startup.lpAttributeList)) {
        fprintf(stderr, "AD_CLEANUP_FAILED attributes error=%lu\n", GetLastError());
        shared->cleanup_uncertain = TRUE; ok = FALSE;
    }
    if (process_sa.lpSecurityDescriptor && LocalFree(process_sa.lpSecurityDescriptor) != NULL) {
        fprintf(stderr, "AD_CLEANUP_FAILED process-security error=%lu\n", GetLastError());
        shared->cleanup_uncertain = TRUE; ok = FALSE;
    }
    if (!ok) {
        fprintf(stderr, "INCOMPLETE AD child arm=%u stage=%s error=%lu\n", (unsigned int)arm, stage, error);
        SetLastError(error ? error : ERROR_INVALID_DATA);
    }
    return ok;
}

BOOL writ_ad_child_stop(WRIT_AD_SHARED *shared, WRIT_AD_CHILD *child)
{
    BOOL ok = TRUE;
    if (!shared || !child || child->cleanup_attempted) return FALSE;
    child->cleanup_attempted = TRUE;
    if (child->process) {
        if (!child->job || !TerminateJobObject(child->job, ERROR_OPERATION_ABORTED)) {
            fprintf(stderr, "AD_CLEANUP_FAILED terminate-job error=%lu\n", GetLastError());
            ok = FALSE;
            if (!TerminateProcess(child->process, ERROR_OPERATION_ABORTED))
                fprintf(stderr, "AD_CLEANUP_FAILED terminate-process error=%lu\n", GetLastError());
        }
        DWORD waited = WaitForSingleObject(child->process, 5000);
        if (waited == WAIT_OBJECT_0) shared->child_exit_unverified = FALSE;
        else {
            DWORD error = waited == WAIT_FAILED ? GetLastError() : ERROR_TIMEOUT;
            fprintf(stderr, "AD_CLEANUP_FAILED wait-child error=%lu\n", error); ok = FALSE;
        }
    }
    if (!close_ad(&child->thread, "child-thread")) ok = FALSE;
    if (!close_ad(&child->process, "child-process")) ok = FALSE;
    if (!close_ad(&child->job, "child-job")) ok = FALSE;
    if (!ok) shared->cleanup_uncertain = TRUE;
    return ok;
}

BOOL writ_ad_shared_stop(WRIT_AD_SHARED *shared)
{
    BOOL ok = TRUE;
    if (!shared || shared->cleanup_attempted) return FALSE;
    shared->cleanup_attempted = TRUE;
    if (shared->child_exit_unverified) {
        fprintf(stderr, "AD_CLEANUP_UNVERIFIED child-exit-not-observed shared-resources-retained\n");
        return FALSE;
    }
    HANDLE observer = NULL;
    if (shared->owner.network) {
        DWORD rc = FwpmEngineOpen0(NULL, RPC_C_AUTHN_WINNT, NULL, NULL, &observer);
        if (rc != ERROR_SUCCESS) { observer = NULL; fprintf(stderr, "AD_CLEANUP_FAILED wfp-observer status=%lu output=unverified\n", rc); ok = FALSE; }
        else if (!observer) { fprintf(stderr, "AD_CLEANUP_FAILED wfp-observer status=success-null\n"); ok = FALSE; }
        rc = FwpmEngineClose0(shared->owner.network);
        if (rc != ERROR_SUCCESS) { fprintf(stderr, "AD_CLEANUP_FAILED wfp-session status=%lu\n", rc); ok = FALSE; }
        shared->owner.network = NULL;
        if (observer) {
            for (DWORD i = 0; i < 4; ++i) {
                FWPM_FILTER0 *filter = NULL;
                rc = shared->owner.filters[i] ? FwpmFilterGetById0(observer, shared->owner.filters[i], &filter) : ERROR_INVALID_DATA;
                if (rc == ERROR_SUCCESS && filter) FwpmFreeMemory0((void **)&filter);
                if (rc != (DWORD)FWP_E_FILTER_NOT_FOUND) { fprintf(stderr, "AD_CLEANUP_FAILED wfp-filter index=%lu status=%lu\n", i, rc); ok = FALSE; }
            }
            rc = FwpmEngineClose0(observer);
            if (rc != ERROR_SUCCESS) { fprintf(stderr, "AD_CLEANUP_FAILED wfp-observer-close status=%lu\n", rc); ok = FALSE; }
        }
    }
    if (!close_ad(&shared->owner.image, "private-image-handle")) ok = FALSE;
    if (shared->owner.image_created && !DeleteFileW(shared->owner.private_image)) { fprintf(stderr, "AD_CLEANUP_FAILED private-image error=%lu\n", GetLastError()); ok = FALSE; }
    if (shared->owner.directory_created && !RemoveDirectoryW(shared->owner.private_directory)) { fprintf(stderr, "AD_CLEANUP_FAILED private-directory error=%lu\n", GetLastError()); ok = FALSE; }
    if (shared->owner.profile_created) {
        HRESULT hr = DeleteAppContainerProfile(shared->owner.profile);
        if (FAILED(hr)) { fprintf(stderr, "AD_CLEANUP_FAILED package-profile hresult=%08lx\n", (unsigned long)hr); ok = FALSE; }
    }
    if (shared->owner.app_sid && FreeSid(shared->owner.app_sid) != NULL) { fprintf(stderr, "AD_CLEANUP_FAILED package-sid\n"); ok = FALSE; }
    if (!close_ad(&shared->launch_token, "launch-token")) ok = FALSE;
    if (shared->derived) {
        for (DWORD i = 0; i < shared->group_count; ++i) if (LocalFree(shared->groups[i]) != NULL) { fprintf(stderr, "AD_CLEANUP_FAILED capability-group index=%lu\n", i); ok = FALSE; }
        for (DWORD i = 0; i < shared->capability_count; ++i) if (LocalFree(shared->capabilities[i]) != NULL) { fprintf(stderr, "AD_CLEANUP_FAILED capability-sid index=%lu\n", i); ok = FALSE; }
        if (shared->groups && LocalFree(shared->groups) != NULL) { fprintf(stderr, "AD_CLEANUP_FAILED capability-groups-array\n"); ok = FALSE; }
        if (shared->capabilities && LocalFree(shared->capabilities) != NULL) { fprintf(stderr, "AD_CLEANUP_FAILED capability-array\n"); ok = FALSE; }
    }
    if (shared->cleanup_uncertain) ok = FALSE;
    return ok;
}
