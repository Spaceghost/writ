#include "native.hpp"
extern "C" {
#include "../policy_pipe.h"
}
#ifndef WRIT_VERSION
#define WRIT_VERSION "development"
#define WRIT_SOURCE_COMMIT "unknown"
#endif

namespace writ {
// Windows SDK ntstatus.h: STATUS_CLOUD_FILE_UNSUCCESSFUL.
static constexpr NTSTATUS cloud_failure = static_cast<NTSTATUS>(0xC000CF12L);
static std::mutex output_mutex;
static void event(const std::string& line) {
    std::lock_guard<std::mutex> lock(output_mutex);
    std::cout << line << std::endl;
}
static std::string path_key(const fs::path& path) {
    auto text = folded(path);
    return digest(text.data(), text.size() * sizeof(wchar_t));
}
static std::wstring stop_name(const fs::path& root) {
    auto key = path_key(root);
    return L"Local\\WritPublicDemo-" + std::wstring(key.begin(), key.end());
}
struct Reply { bool ok; DWORD value; std::string detail; };
class Monitor {
    WRIT_POLICY_PIPE pipe{};
public:
    Monitor(const wchar_t* node, const wchar_t* bridge, const wchar_t* module) {
        check(writ_policy_start(&pipe, node, bridge, module), "start Bend monitor");
    }
    ~Monitor() { writ_policy_stop(&pipe); }
    Reply call(const char* op, DWORD a = 0, DWORD b = 0, const std::string& body = "-") {
        std::string request = "WRITFS1\t" + std::string(op) + "\t" + std::to_string(a) +
            "\t" + std::to_string(b) + "\t0\t0\t" + body + "\n";
        char response[WRIT_POLICY_REPLY_MAX];
        check(writ_policy_exchange(&pipe, request.c_str(), response, sizeof(response)), "Bend transport stopped");
        // policy_pipe has already validated the full canonical reply and sequence.
        std::string text(response); size_t p = text.find('\t'); p = text.find('\t', p + 1);
        size_t q = text.find('\t', p + 1), r = text.find('\t', q + 1);
        return {text.substr(p + 1, q - p - 1) == "OK",
            static_cast<DWORD>(std::stoul(text.substr(q + 1, r - q - 1))), text.substr(r + 1)};
    }
    Reply require(const char* op, DWORD a = 0, DWORD b = 0, const std::string& body = "-") {
        auto r = call(op, a, b, body);
        if (!r.ok) throw Error(("Bend: " + r.detail).c_str(), ERROR_INVALID_DATA);
        return r;
    }
};

struct Placeholder {
    bool cloud = false, in_sync = false;
    LONGLONG size = 0, on_disk = 0;
    Meta identity{};
};
static Placeholder inspect(HANDLE h) {
    PlaceholderVisibility visible;
    FILE_ATTRIBUTE_TAG_INFO attr{};
    FILE_STANDARD_INFO standard{};
    check(GetFileInformationByHandleEx(h, FileAttributeTagInfo, &attr, sizeof(attr)), "attributes");
    check(GetFileInformationByHandleEx(h, FileStandardInfo, &standard, sizeof(standard)), "file info");
    if (standard.Directory || standard.NumberOfLinks != 1) throw Error("regular single-link file required", ERROR_NOT_SUPPORTED);
    Placeholder result; result.size = standard.EndOfFile.QuadPart;
    auto state = CfGetPlaceholderStateFromAttributeTag(attr.FileAttributes, attr.ReparseTag);
    result.cloud = (state & CF_PLACEHOLDER_STATE_PLACEHOLDER) != 0;
    if (!result.cloud) {
        if (attr.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) throw Error("non-cloud reparse file", ERROR_NOT_SUPPORTED);
        result.on_disk = result.size;
        return result;
    }
    alignas(CF_PLACEHOLDER_STANDARD_INFO) unsigned char buffer[sizeof(CF_PLACEHOLDER_STANDARD_INFO) + sizeof(Meta)]{};
    DWORD returned = 0;
    hr(CfGetPlaceholderInfo(h, CF_PLACEHOLDER_INFO_STANDARD, buffer, sizeof(buffer), &returned), "placeholder info");
    auto info = reinterpret_cast<CF_PLACEHOLDER_STANDARD_INFO*>(buffer);
    if (info->FileIdentityLength != sizeof(Meta) || returned < offsetof(CF_PLACEHOLDER_STANDARD_INFO, FileIdentity) + sizeof(Meta))
        throw Error("foreign placeholder identity", ERROR_INVALID_DATA);
    memcpy(&result.identity, info->FileIdentity, sizeof(Meta)); valid(result.identity);
    result.in_sync = info->InSyncState == CF_IN_SYNC_STATE_IN_SYNC;
    result.on_disk = info->OnDiskDataSize.QuadPart;
    return result;
}
static USN file_usn(HANDLE h) {
    // Request the documented V2 record, and never reinterpret an unknown layout.
    READ_FILE_USN_DATA request{2, 2};
    alignas(USN_RECORD_V2) unsigned char buffer[4096]{};
    DWORD got = 0;
    check(DeviceIoControl(h, FSCTL_READ_FILE_USN_DATA, &request, sizeof(request),
        buffer, sizeof(buffer), &got, nullptr), "read NTFS USN");
    auto record = reinterpret_cast<USN_RECORD_V2*>(buffer);
    if (got < offsetof(USN_RECORD_V2, FileName) || record->MajorVersion != 2 || !record->Usn)
        throw Error("usable NTFS USN required", ERROR_INVALID_DATA);
    return record->Usn;
}
static std::string fingerprint(HANDLE h) {
    FILE_ID_INFO id{};
    check(GetFileInformationByHandleEx(h, FileIdInfo, &id, sizeof(id)), "file identity");
    return hex(reinterpret_cast<unsigned char*>(&id), sizeof(id)) + ":" + std::to_string(file_usn(h));
}
static fs::path state_path(const Store& store, const fs::path& root) {
    return store.path / L"roots" / path_key(root);
}
static void owned_registration(const fs::path& root, const Store& store) {
    alignas(CF_SYNC_ROOT_STANDARD_INFO) unsigned char buffer[sizeof(CF_SYNC_ROOT_STANDARD_INFO) + 256]{};
    DWORD returned = 0;
    hr(CfGetSyncRootInfoByPath(root.c_str(), CF_SYNC_ROOT_INFO_STANDARD, buffer, sizeof(buffer), &returned), "sync root info");
    auto info = reinterpret_cast<CF_SYNC_ROOT_STANDARD_INFO*>(buffer);
    auto identity = "WritPublic01:" + path_key(store.path) + ":" + path_key(root);
    if (info->SyncRootIdentityLength != identity.size() ||
        returned < offsetof(CF_SYNC_ROOT_STANDARD_INFO, SyncRootIdentity) + identity.size() ||
        memcmp(info->SyncRootIdentity, identity.data(), identity.size()))
        throw Error("not this demo's sync root", ERROR_ACCESS_DENIED);
}

class Provider {
    Store store;
    fs::path root, state;
    Monitor monitor;
    std::mutex mutex;
    Meta base;
    CF_CONNECTION_KEY connection{};
    bool connected = false, fail_writeback;
    std::atomic<unsigned long long> fetched_bytes{0};
    std::string last_attempt;
    size_t recoveries = 0;

    void create_placeholder() {
        auto listing = monitor.require("LIST", 0, 0, "hello.txt");
        if (listing.value != base.size || listing.detail != hash(base)) throw Error("listing metadata", ERROR_INVALID_DATA);
        // No backing payload is read anywhere on this startup/listing path.
        CF_PLACEHOLDER_CREATE_INFO file{};
        file.RelativeFileName = L"hello.txt";
        file.FsMetadata.FileSize.QuadPart = listing.value;
        file.FsMetadata.BasicInfo.FileAttributes = FILE_ATTRIBUTE_NORMAL;
        FILETIME now; GetSystemTimeAsFileTime(&now);
        memcpy(&file.FsMetadata.BasicInfo.CreationTime, &now, sizeof(now));
        file.FsMetadata.BasicInfo.LastWriteTime = file.FsMetadata.BasicInfo.CreationTime;
        file.FsMetadata.BasicInfo.LastAccessTime = file.FsMetadata.BasicInfo.CreationTime;
        file.FsMetadata.BasicInfo.ChangeTime = file.FsMetadata.BasicInfo.CreationTime;
        file.FileIdentity = &base; file.FileIdentityLength = sizeof(base);
        file.Flags = CF_PLACEHOLDER_CREATE_FLAG_MARK_IN_SYNC;
        DWORD count = 0;
        hr(CfCreatePlaceholders(root.c_str(), &file, 1, CF_CREATE_FLAG_NONE, &count), "create placeholder");
        hr(file.Result, "placeholder result");
        if (count != 1) throw Error("placeholder count", ERROR_INVALID_DATA);
    }
    static void CALLBACK fetch(const CF_CALLBACK_INFO* info, const CF_CALLBACK_PARAMETERS* request) noexcept {
        auto self = static_cast<Provider*>(info->CallbackContext);
        CF_OPERATION_INFO operation{};
        operation.StructSize = sizeof(operation); operation.Type = CF_OPERATION_TYPE_TRANSFER_DATA;
        operation.ConnectionKey = info->ConnectionKey; operation.TransferKey = info->TransferKey;
        operation.RequestKey = info->RequestKey; operation.CorrelationVector = info->CorrelationVector;
        CF_OPERATION_PARAMETERS params{};
        params.ParamSize = static_cast<ULONG>(offsetof(CF_OPERATION_PARAMETERS, TransferData) + sizeof(params.TransferData));
        params.TransferData.Offset = request->FetchData.RequiredFileOffset;
        params.TransferData.Length = request->FetchData.RequiredLength;
        params.TransferData.CompletionStatus = cloud_failure;
        try {
            std::lock_guard<std::mutex> lock(self->mutex);
            event("FETCH_REQUEST");
            if (info->FileIdentityLength != sizeof(Meta)) throw Error("fetch identity", ERROR_INVALID_DATA);
            Meta identity; memcpy(&identity, info->FileIdentity, sizeof(identity)); valid(identity);
            auto bytes = self->store.read(identity);
            self->fetched_bytes.fetch_add(bytes.size());
            self->monitor.require("READ", identity.version, 0, hex(bytes));
            params.TransferData.CompletionStatus = 0;
            params.TransferData.Buffer = bytes.data(); params.TransferData.Offset.QuadPart = 0;
            params.TransferData.Length.QuadPart = static_cast<LONGLONG>(bytes.size());
            hr(CfExecute(&operation, &params), "transfer data");
            event("FETCH bytes=" + std::to_string(bytes.size()) + " version=" + std::to_string(identity.version));
            return;
        } catch (const std::exception& e) { event(std::string("FETCH_FAILED ") + e.what()); }
        // Always complete a failed callback; no pending user read waits for timeout.
        params.TransferData.Buffer = nullptr;
        params.TransferData.Offset = request->FetchData.RequiredFileOffset;
        params.TransferData.Length = request->FetchData.RequiredLength;
        params.TransferData.CompletionStatus = cloud_failure;
        CfExecute(&operation, &params);
    }
    void recovery_copy(const Bytes& bytes) {
        if (recoveries >= 256) throw Error("recovery capacity; retain edits and archive recovery files", ERROR_DISK_FULL);
        auto name = nonce();
        durable_file(state / L"recovery" / (name + ".bin"), bytes.data(), static_cast<DWORD>(bytes.size()));
        ++recoveries;
        durable_file(state / L"recovery" / (name + ".base"), &base, sizeof(base));
        event("RECOVERY " + name + ".bin");
    }
    void reconcile() {
        std::lock_guard<std::mutex> lock(mutex);
        auto path = root / L"hello.txt";
        // Attribute-only scans never cause hydration. Polling one known name
        // also catches replacement and provider-offline edits without relying
        // on close notifications, which are not a complete write journal.
        Placeholder attributes;
        {
            auto h = open(path, FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                          OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT);
            attributes = inspect(h);
        }
        if (attributes.cloud && attributes.in_sync && same(attributes.identity, base)) return;
        if (attributes.size < 0 || attributes.size > max_bytes) throw Error("64 KiB edit limit; local file retained", ERROR_FILE_TOO_LARGE);
        if (attributes.cloud && attributes.on_disk < attributes.size)
            throw Error("partial dirty placeholder retained; open to finish hydration", ERROR_CLOUD_FILE_NOT_IN_SYNC);

        // This excludes existing writers and replacement/deletion until the
        // entire snapshot/commit/readback/mark operation has finished. Sharing
        // violations defer the attempt; they are not successful saves.
        auto file = open(path, GENERIC_READ | WRITE_DAC, FILE_SHARE_READ, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT);
        // ReplaceFile can change the object between the metadata scan and open.
        // Conversion and completeness checks must describe this retained handle.
        attributes = inspect(file);
        if (attributes.cloud && attributes.in_sync && same(attributes.identity, base)) return;
        if (attributes.cloud && attributes.on_disk < attributes.size)
            throw Error("partial dirty replacement retained", ERROR_CLOUD_FILE_NOT_IN_SYNC);
        auto before = fingerprint(file);
        if (before == last_attempt) return;
        auto bytes = read_bytes(file);
        bool attempted = false;
        try {
            auto store_lock = store.lock();
            recovery_copy(bytes);
            auto observed = store.head();
            auto proposal = monitor.call("PREPARE", base.version, observed.version, hex(bytes));
            if (!proposal.ok) {
                last_attempt = before;
                event("WRITEBACK_FAILED " + proposal.detail + " local_edit_retained");
                return;
            }
            attempted = true;
            Meta replacement = metadata(proposal.value, bytes);
            if (hash(replacement) != proposal.detail) throw Error("candidate checksum", ERROR_CRC);
            if (fail_writeback) throw Error("injected writeback failure", ERROR_WRITE_FAULT);
            store.publish(replacement, bytes);
            monitor.require("PERSISTED", replacement.version, replacement.size, hash(replacement));
            // Keep the local expected base across provider restarts and across
            // ReplaceFile, where the old placeholder identity may disappear.
            atomic_file(state / L"base", &replacement, sizeof(replacement));
            base = replacement;
            if (attributes.cloud) {
                hr(CfUpdatePlaceholder(file, nullptr, &base, sizeof(base), nullptr, 0,
                    CF_UPDATE_FLAG_NONE, nullptr, nullptr), "update identity");
            } else {
                hr(CfConvertToPlaceholder(file, &base, sizeof(base), CF_CONVERT_FLAG_NONE,
                    nullptr, nullptr), "convert replacement");
            }
            USN usn = file_usn(file);
            monitor.require("MATCH", base.version, 0, hex(read_bytes(file)));
            hr(CfSetInSyncState(file, CF_IN_SYNC_STATE_IN_SYNC, CF_SET_IN_SYNC_FLAG_NONE, &usn), "mark in sync with USN");
            last_attempt.clear();
            event("COMMIT version=" + std::to_string(base.version) + " sha256=" + hash(base));
        } catch (const Error& e) {
            if (!attempted && e.code == ERROR_SHARING_VIOLATION) throw;
            if (attempted) monitor.require("FAILED");
            last_attempt = fingerprint(file);
            event(std::string("WRITEBACK_FAILED ") + e.what() + " code=" + std::to_string(e.code) + " local_edit_retained");
        }
    }
public:
    Provider(fs::path r, Store s, const wchar_t* node, const wchar_t* bridge, const wchar_t* module, bool fail)
        : store(std::move(s)), root(std::move(r)), state(state_path(store, root)),
          monitor(node, bridge, module), fail_writeback(fail) {
        bool fresh = !fs::exists(state / L"base");
        if (fresh && !fs::is_empty(root)) throw Error("a new sync root must be empty", ERROR_DIR_NOT_EMPTY);
        private_directory(store.path / L"roots"); private_directory(state); private_directory(state / L"recovery");
    }
    void run() {
        // Move assignment is deliberately avoided for the ownership handles.
        Handle owned = open(state / L"provider.lock", GENERIC_READ | GENERIC_WRITE, 0, OPEN_ALWAYS);
        bool fresh = !fs::exists(state / L"base");
        if (fresh) {
            auto locked = store.lock(); base = store.head();
            atomic_file(state / L"base", &base, sizeof(base));
        } else base = read_meta(state / L"base");
        for (const auto& item : fs::directory_iterator(state / L"recovery")) {
            if (item.path().extension() == L".bin") ++recoveries;
            if (recoveries > 256) throw Error("recovery capacity", ERROR_DISK_FULL);
        }
        monitor.require("INIT", base.version, base.size, hash(base));
        auto identity = "WritPublic01:" + path_key(store.path) + ":" + path_key(root);
        CF_SYNC_REGISTRATION registration{}; registration.StructSize = sizeof(registration);
        registration.ProviderName = L"Writ public demo"; registration.ProviderVersion = L"1.0";
        registration.SyncRootIdentity = identity.data(); registration.SyncRootIdentityLength = static_cast<DWORD>(identity.size());
        registration.ProviderId = {0x296ba32d, 0xf698, 0x4c4e, {0xa4, 0x01, 0x21, 0x64, 0xc7, 0xdd, 0xae, 0x11}};
        CF_SYNC_POLICIES policies{}; policies.StructSize = sizeof(policies);
        policies.Hydration.Primary = CF_HYDRATION_POLICY_FULL;
        policies.Population.Primary = CF_POPULATION_POLICY_ALWAYS_FULL;
        policies.InSync = CF_INSYNC_POLICY_TRACK_ALL | CF_INSYNC_POLICY_PRESERVE_INSYNC_FOR_SYNC_ENGINE;
        policies.HardLink = CF_HARDLINK_POLICY_NONE;
        HRESULT registration_result = CfRegisterSyncRoot(root.c_str(), &registration, &policies,
            CF_REGISTER_FLAG_DISABLE_ON_DEMAND_POPULATION_ON_ROOT | CF_REGISTER_FLAG_MARK_IN_SYNC_ON_ROOT);
        if (FAILED(registration_result)) owned_registration(root, store);
        CF_CALLBACK_REGISTRATION callbacks[] = {{CF_CALLBACK_TYPE_FETCH_DATA, fetch}, CF_CALLBACK_REGISTRATION_END};
        hr(CfConnectSyncRoot(root.c_str(), callbacks, this, CF_CONNECT_FLAG_BLOCK_SELF_IMPLICIT_HYDRATION, &connection), "connect sync root");
        connected = true;
        if (fs::is_empty(root)) create_placeholder();
        Handle stopped(CreateEventW(nullptr, TRUE, FALSE, stop_name(root).c_str()));
        check(stopped.value != nullptr, "stop event");
        event("READY version=" + std::to_string(base.version) + " payload_bytes_fetched=" + std::to_string(fetched_bytes.load()));
        DWORD last_error = 0;
        while (WaitForSingleObject(stopped, 500) == WAIT_TIMEOUT) {
            try { reconcile(); last_error = 0; }
            catch (const Error& e) {
                if (e.code != ERROR_SHARING_VIOLATION && e.code != ERROR_FILE_NOT_FOUND && e.code != last_error)
                    event(std::string("DEFERRED ") + e.what() + " code=" + std::to_string(e.code));
                if (std::string(e.what()) == "Bend transport stopped") throw;
                last_error = e.code;
            }
        }
        hr(CfDisconnectSyncRoot(connection), "disconnect"); connected = false;
        event("STOPPED");
    }
    ~Provider() { if (connected) CfDisconnectSyncRoot(connection); }
};

static void seed(const Store& store) {
    private_directory(store.path);
    auto locked = store.lock();
    if (fs::exists(store.path / L"head")) { valid(store.head()); event("SEEDED existing_store"); return; }
    const char text[] = "Hello from Writ!\r\nThis is public fixture data. Edit and save me in Notepad.\r\n";
    Bytes bytes(text, text + sizeof(text) - 1);
    store.publish(metadata(1, bytes), bytes);
    event("SEEDED public_hello");
}
static void remove(const fs::path& root, const Store& store) {
    auto state = state_path(store, root);
    auto lock = open(state / L"provider.lock", GENERIC_READ | GENERIC_WRITE, 0, OPEN_EXISTING);
    owned_registration(root, store);
    size_t count = 0;
    for (const auto& item : fs::directory_iterator(root)) {
        if (++count > 256 || item.is_directory()) throw Error("inspect extra entries before removal", ERROR_NOT_SUPPORTED);
        auto file = open(item.path(), FILE_READ_ATTRIBUTES, FILE_SHARE_READ, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT);
        auto p = inspect(file);
        if (p.cloud && !p.in_sync && p.on_disk < p.size)
            throw Error("refuse removal of partially hydrated dirty data", ERROR_CLOUD_FILE_NOT_IN_SYNC);
    }
    hr(CfUnregisterSyncRoot(root.c_str()), "unregister");
    event("REMOVED registration; hydrated files, backing store and recovery copies retained");
}
// Packaging conveniences only: the same Provider and Bend monitor handle I/O.
static fs::path default_path(int folder, const wchar_t* suffix) {
    wchar_t path[MAX_PATH];
    hr(SHGetFolderPathW(nullptr, folder, nullptr, SHGFP_TYPE_CURRENT, path), "user folder");
    return writ::canonical(fs::path(path) / suffix);
}
static void stop(const fs::path& root) {
    Handle signal(OpenEventW(EVENT_MODIFY_STATE, FALSE, stop_name(root).c_str()));
    if (!signal.value && GetLastError() == ERROR_FILE_NOT_FOUND) return;
    check(signal.value != nullptr, "open stop event"); check(SetEvent(signal), "stop");
}
static void cleanup_default() {
    auto root = default_path(CSIDL_PROFILE, L"Writ");
    auto path = default_path(CSIDL_LOCAL_APPDATA, L"WritDemo\\store");
    local_user_path(root); local_user_path(path);
    Store store(path);
    auto lock_path = state_path(store, root) / L"provider.lock";
    // Installation alone does not create a registration or backing store.
    if (!fs::exists(lock_path) || !fs::exists(root)) return;
    stop(root);
    const auto deadline = GetTickCount64() + 20000;
    for (;;) {
        try {
            auto lock = open(lock_path, GENERIC_READ | GENERIC_WRITE, 0);
            break;
        } catch (const Error& e) {
            if (e.code != ERROR_SHARING_VIOLATION || GetTickCount64() >= deadline) throw;
            Sleep(100);
        }
    }
    try { remove(root, store); }
    catch (const Error& e) {
        // Repeated uninstall/cleanup is harmless only for an absent registration.
        if (e.code != static_cast<DWORD>(HRESULT_FROM_WIN32(ERROR_CLOUD_FILE_NOT_UNDER_SYNC_ROOT))) throw;
    }
}
static void start_default() {
    wchar_t executable[32768];
    DWORD length = GetModuleFileNameW(nullptr, executable, 32768);
    check(length && length < 32768, "package directory");
    auto package = fs::path(executable).parent_path();
    auto node = package / L"node.exe", bridge = package / L"node-policy.mjs", module = package / L"public-sync.mjs";
    for (const auto& dependency : {node, bridge, module})
        if (!fs::is_regular_file(dependency)) throw Error("extract the entire portable ZIP or install Writ Setup", ERROR_FILE_NOT_FOUND);
    auto root = default_path(CSIDL_PROFILE, L"Writ");
    auto path = default_path(CSIDL_LOCAL_APPDATA, L"WritDemo\\store");
    local_user_path(root); local_user_path(path);
    private_directory(path.parent_path()); seed(Store(path)); private_directory(root);
    std::wcout << L"Writ public preview: " << root << L"\\hello.txt\nKeep this window open while editing.\n";
    Provider provider(root, Store(path), node.c_str(), bridge.c_str(), module.c_str(), false);
    provider.run();
}
} // namespace writ

int wmain(int argc, wchar_t** argv) {
    using namespace writ;
    try {
        if (argc == 1 || (argc == 2 && !wcscmp(argv[1], L"start"))) { start_default(); return 0; }
        if (argc == 2 && !wcscmp(argv[1], L"version")) {
            std::cout << "Writ " WRIT_VERSION " (" WRIT_SOURCE_COMMIT ") public Files On-Demand preview\n"; return 0;
        }
        if (argc == 2 && !wcscmp(argv[1], L"cleanup")) { cleanup_default(); return 0; }
        if (argc == 2 && !wcscmp(argv[1], L"stop")) { stop(default_path(CSIDL_PROFILE, L"Writ")); return 0; }
        if (argc == 3 && !wcscmp(argv[1], L"seed")) {
            auto path = canonical(argv[2]); local_user_path(path); seed(Store(path)); return 0;
        }
        if (argc == 3 && !wcscmp(argv[1], L"stop")) {
            stop(canonical(argv[2])); return 0;
        }
        if (argc == 3 && !wcscmp(argv[1], L"inspect")) {
            auto file = open(canonical(argv[2]) / L"hello.txt", FILE_READ_ATTRIBUTES,
                FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT);
            auto p = inspect(file);
            std::cout << "{\"placeholder\":" << (p.cloud ? "true" : "false") << ",\"inSync\":" <<
                (p.in_sync ? "true" : "false") << ",\"size\":" << p.size << ",\"onDisk\":" << p.on_disk << "}" << std::endl;
            return 0;
        }
        if ((argc == 7 || argc == 8) && !wcscmp(argv[1], L"serve")) {
            bool fail = argc == 8 && !wcscmp(argv[7], L"--fail-writeback");
            if (argc == 8 && !fail) throw Error("unknown option", ERROR_INVALID_PARAMETER);
            auto root = canonical(argv[2]), path = canonical(argv[3]);
            local_user_path(root); local_user_path(path);
            if (folded(root) == folded(path) || inside(root, path) || inside(path, root))
                throw Error("backing store and sync root must be independent", ERROR_INVALID_PARAMETER);
            private_directory(root);
            Provider provider(root, Store(path), argv[4], argv[5], argv[6], fail); provider.run(); return 0;
        }
        if (argc == 4 && !wcscmp(argv[1], L"remove")) {
            auto root = canonical(argv[2]), path = canonical(argv[3]); local_user_path(root); local_user_path(path);
            remove(root, Store(path)); return 0;
        }
        std::cout << "start (default) | stop [ROOT] | cleanup | version\n"
            "seed STORE | serve ROOT STORE NODE BRIDGE MODULE [--fail-writeback] | inspect ROOT | remove ROOT STORE\n";
        return argc == 2 && !wcscmp(argv[1], L"--help") ? 0 : 2;
    } catch (const Error& e) {
        std::cerr << e.what() << " (" << e.code << ")\n"; return 1;
    } catch (const std::exception& e) {
        std::cerr << e.what() << "\n"; return 1;
    }
}
