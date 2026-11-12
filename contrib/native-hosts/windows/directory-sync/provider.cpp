#include "directory.hpp"
#include "s3.hpp"
#include <chrono>

namespace writ_sync {
inline fs::path home_directory() {
    wchar_t path[MAX_PATH]; writ::hr(SHGetFolderPathW(nullptr, CSIDL_PROFILE, nullptr, SHGFP_TYPE_CURRENT, path), "User profile");
    return writ::canonical(path);
}
inline fs::path app_directory() {
    wchar_t path[MAX_PATH]; writ::hr(SHGetFolderPathW(nullptr, CSIDL_LOCAL_APPDATA, nullptr, SHGFP_TYPE_CURRENT, path), "Local app data");
    auto result = writ::canonical(path) / L"WritSync"; writ::private_directory(result); return result;
}
inline std::wstring object_name(const fs::path& root, const wchar_t* suffix) {
    auto path = writ::folded(root); auto key = writ::digest(path.data(), path.size() * sizeof(wchar_t));
    return L"Local\\WritDirectory-" + utf16(key) + suffix;
}
struct Temporary {
    fs::path path;
    writ::Handle handle;
    explicit Temporary(const fs::path& directory) : path(directory / ("stage-" + writ::nonce())),
        handle(writ::open(path, GENERIC_READ | GENERIC_WRITE | DELETE, 0, CREATE_NEW, FILE_FLAG_WRITE_THROUGH)) {}
    ~Temporary() {
        // Only this object's generated file is removed. Once renamed for an
        // admitted apply, its original pathname no longer exists.
        if (handle.value != INVALID_HANDLE_VALUE) { CloseHandle(handle.value); handle.value = INVALID_HANDLE_VALUE; }
        DeleteFileW(path.c_str());
    }
    void close() { if (handle.value != INVALID_HANDLE_VALUE) { CloseHandle(handle.value); handle.value = INVALID_HANDLE_VALUE; } }
};
static void scan(const fs::path& root, const fs::path& directory, Catalog& found) {
    Parents parents(directory);
    for (const auto& entry : fs::directory_iterator(directory)) {
        auto name = utf8(entry.path().lexically_relative(root).generic_wstring()); relative_path(name);
        auto handle = frozen(entry.path());
        if (handle.value == INVALID_HANDLE_VALUE) continue;
        auto value = inspect(handle); value.version = 1;
        if (found.size() == maximum_entries) throw writ::Error("2048-path sync limit reached", ERROR_FILE_TOO_LARGE);
        found.emplace(name, value);
        if (value.kind == 2) scan(root, entry.path(), found);
    }
}
class Provider {
    fs::path package, root, state, recovery;
    S3 s3;
    Catalog baseline;
    writ::Handle stopped, ownership;
    std::string last_error;

    void persist(const std::string& name, const Snapshot& snapshot) {
        if (snapshot.version) baseline[name] = snapshot;
        auto bytes = encode(baseline); writ::atomic_file(state / L"baseline", bytes.data(), static_cast<DWORD>(bytes.size()));
    }
    std::pair<Catalog, std::string> remote() {
        auto response = s3.request("GET", "manifest.writ");
        if (response.status == 404) {
            if (!baseline.empty()) throw writ::Error("Established remote manifest is missing; local files retained", ERROR_FILE_NOT_FOUND);
            return {{}, ""};
        }
        if (response.status != 200 || response.etag.empty()) throw writ::Error("Cannot read the S3 manifest", response.status);
        auto catalog = decode(response.body);
        return {std::move(catalog), std::move(response.etag)};
    }
    void recovery_capacity() {
        size_t count = 0;
        for (const auto& entry : fs::directory_iterator(recovery)) {
            (void)entry;
            if (++count >= 1024) throw writ::Error("Recovery folder has reached 1024 items; review and move older copies before retrying", ERROR_DISK_FULL);
        }
    }
    void apply(Monitor& monitor, const std::string& name, const Snapshot& remote_value, Temporary& download) {
        auto target = root / relative_path(name);
        Parents parents(target.parent_path(), remote_value.kind == 0);
        auto current = frozen(target, true);
        Snapshot observed = current.value == INVALID_HANDLE_VALUE ? Snapshot{} : inspect(current);
        monitor.require("RECHECK", observed.kind, 0, observed.size);
        monitor.chunks(current, observed.size); monitor.require("RECHECK_END");
        if (observed.kind == 2 && !fs::is_empty(target))
            throw writ::Error("Folder still contains local files; remote replacement deferred", ERROR_DIR_NOT_EMPTY);
        if (current.value != INVALID_HANDLE_VALUE) {
            recovery_capacity();
            auto saved = recovery / (writ::nonce() + "-" + utf8(target.filename().native()));
            // Exact frozen handle, never a second pathname lookup. A new local
            // creator after this rename wins the destination; no replace flag.
            move_retained(current, saved);
            std::cout << "RECOVERY " << utf8(saved.filename().native()) << std::endl;
        }
        if (remote_value.kind == 1) {
            download.close();
            writ::check(MoveFileExW(download.path.c_str(), target.c_str(), MOVEFILE_WRITE_THROUGH), "Install verified remote file without overwriting a new local file");
        } else if (remote_value.kind == 2) {
            writ::check(CreateDirectoryW(target.c_str(), nullptr), "Create remote folder without replacing a local object");
        }
        // For a deletion, a new local creator remains in place and is a new
        // change against this tombstone on the next scan.
        monitor.snapshot("APPLIED", remote_value); persist(name, remote_value);
        std::cout << "COMMIT Downloaded " << name << std::endl;
    }
    void reconcile(const std::string& name, Catalog& catalog, std::string& etag, Monitor& names) {
        auto target = root / relative_path(name);
        // One validated remote snapshot per scan. Exact conditional publication
        // serializes updates; a competing writer is reconsidered next scan.
        auto remote_value = get(catalog, name);
        Monitor monitor(package); monitor.snapshot("OPEN", get(baseline, name));
        Temporary snapshot(state);
        Snapshot local;
        {
            Parents parents(target.parent_path(), true);
            auto source = frozen(target);
            if (source.value != INVALID_HANDLE_VALUE) local = inspect(source);
            monitor.require("LOCAL", local.kind, 0, local.size);
            monitor.chunks(source, local.size, snapshot.handle);
            local.hash = monitor.require("LOCAL_END").detail;
            writ::check(FlushFileBuffers(snapshot.handle), "Flush upload snapshot");
        }
        auto decision = monitor.call("REMOTE", remote_value.kind, remote_value.version, remote_value.size, remote_value.hash);
        if (!decision.ok) throw writ::Error(("Bend: " + decision.detail).c_str(), ERROR_REVISION_MISMATCH);
        if (decision.detail == "ADOPT") { persist(name, remote_value); return; }
        if (decision.detail == "UPLOAD") {
            local.version = decision.value;
            namespace_record(names, "CHECK", name, local);
            if (local.kind == 1) {
                auto upload = s3.request("PUT", "objects/" + local.hash, {}, snapshot.handle, local.size, local.hash, "", true);
                if (upload.status == 412) {
                    // A preexisting content-addressed object is reused only
                    // after its bytes pass the same Bend stream verifier.
                    Temporary existing(state);
                    auto body = s3.request("GET", "objects/" + local.hash, {}, INVALID_HANDLE_VALUE, 0, "", "", false, existing.handle, local.size);
                    if (body.status != 200 || body.bytes != local.size) throw writ::Error("Existing S3 object does not match", ERROR_CRC);
                    Monitor check(package); check.snapshot("OPEN", Snapshot{}); check.require("LOCAL", 1, 0, local.size);
                    check.chunks(existing.handle, local.size);
                    check.require("LOCAL_END");
                    if (check.snapshot("REMOTE", local).detail != "ADOPT") throw writ::Error("Existing S3 object checksum mismatch", ERROR_CRC);
                } else if (upload.status != 200) throw writ::Error("S3 object upload failed", upload.status);
            }
            auto candidate = catalog; candidate[name] = local;
            auto bytes = encode(candidate);
            auto written = s3.request("PUT", "manifest.writ", bytes, INVALID_HANDLE_VALUE, 0, "", etag, etag.empty());
            if (written.status != 200) throw writ::Error("Remote changed or S3 manifest publication failed; local files retained", written.status);
            monitor.snapshot("PUBLISHED", local); persist(name, local);
            namespace_record(names, "SET", name, local);
            catalog = std::move(candidate); etag = written.etag;
            if (etag.empty()) throw writ::Error("S3 did not return the committed manifest ETag", ERROR_INVALID_DATA);
            std::cout << "COMMIT Uploaded " << name << std::endl;
        } else if (decision.detail == "DOWNLOAD") {
            Temporary download(state); monitor.require("READ");
            if (remote_value.kind == 1) {
                auto body = s3.request("GET", "objects/" + remote_value.hash, {}, INVALID_HANDLE_VALUE, 0, "", "", false, download.handle, remote_value.size);
                if (body.status != 200 || body.bytes != remote_value.size) throw writ::Error("S3 download failed or was incomplete", body.status);
                writ::check(FlushFileBuffers(download.handle), "Flush remote download");
                monitor.chunks(download.handle, remote_value.size);
            }
            monitor.require("READ_END"); apply(monitor, name, remote_value, download);
        } else throw writ::Error("Unknown Bend directory action", ERROR_INVALID_DATA);
    }
public:
    Provider(fs::path binaries, fs::path directory, fs::path storage, const Connection& connection) :
        package(std::move(binaries)), root(std::move(directory)), state(std::move(storage)), recovery(state / L"Recovery"), s3(connection) {
        writ::local_user_path(root); writ::local_user_path(state);
        if (writ::inside(state, root) || writ::inside(root, state) || writ::folded(state) == writ::folded(root))
            throw writ::Error("Sync folder and private state must be separate", ERROR_BAD_PATHNAME);
        ownership.value = CreateMutexW(nullptr, TRUE, object_name(root, L"-owner").c_str());
        writ::check(ownership.value != nullptr, "Directory ownership mutex");
        if (GetLastError() == ERROR_ALREADY_EXISTS) throw writ::Error("This folder is already syncing", ERROR_BUSY);
        bool existing_state = fs::exists(state / L"binding");
        if (existing_state && !fs::exists(root)) throw writ::Error("The established sync folder is missing; remote files retained", ERROR_PATH_NOT_FOUND);
        writ::private_directory(root); writ::private_directory(state); writ::private_directory(recovery);
        Parents root_guard(root), state_guard(state);
        auto root_handle = frozen(root); FILE_ID_INFO id{};
        writ::check(GetFileInformationByHandleEx(root_handle, FileIdInfo, &id, sizeof(id)), "Sync root native identity");
        auto identity = profile_id(connection, root) + ":" + writ::hex(reinterpret_cast<const unsigned char*>(&id), sizeof(id));
        auto binding = writ::digest(identity.data(), identity.size());
        if (existing_state) {
            auto file = frozen(state / L"binding"); auto bytes = writ::read_bytes(file);
            if (std::string(bytes.begin(), bytes.end()) != binding) throw writ::Error("Sync state belongs to another folder identity or connection", ERROR_INVALID_DATA);
        } else {
            if (fs::exists(state / L"baseline")) throw writ::Error("Unbound sync state cannot be reused", ERROR_INVALID_DATA);
            writ::durable_file(state / L"binding", binding.data(), static_cast<DWORD>(binding.size()));
        }
        stopped.value = CreateEventW(nullptr, TRUE, FALSE, object_name(root, L"-stop").c_str());
        writ::check(stopped.value != nullptr, "Directory stop event"); ResetEvent(stopped);
        baseline = decode(read_catalog(state / L"baseline"));
        validate_catalog(package, baseline);
    }
    int run(bool once) {
        std::cout << "READY S3 folder sync" << std::endl;
        int errors = 0;
        do {
            errors = 0;
            try {
                Parents root_guard(root), state_guard(state), recovery_guard(recovery);
                Catalog local; scan(root, root, local); validate_catalog(package, local);
                auto [catalog, etag] = remote();
                Monitor names(package, L"directory-namespace.mjs"); validate_catalog(names, catalog);
                std::set<std::string> paths;
                for (const auto* list : {&local, &catalog, &baseline}) for (const auto& [name, value] : *list) { (void)value; paths.insert(name); }
                if (paths.size() > maximum_entries) throw writ::Error("2048-path sync limit reached", ERROR_FILE_TOO_LARGE);
                // Create existing directories parent-first; deletions follow
                // children. Bend namespace validation admits every full update.
                std::vector<std::string> ordered(paths.begin(), paths.end());
                std::stable_sort(ordered.begin(), ordered.end(), [&](const auto& a, const auto& b) {
                    bool ad = get(local, a).kind == 0 || get(catalog, a).kind == 0;
                    bool bd = get(local, b).kind == 0 || get(catalog, b).kind == 0;
                    bool a_remove = (get(baseline, a).kind == 2 && ad), b_remove = (get(baseline, b).kind == 2 && bd);
                    if (a_remove != b_remove) return !a_remove;
                    if (a_remove) return a.size() != b.size() ? a.size() > b.size() : a < b;
                    return a < b;
                });
                for (const auto& name : ordered) {
                    if (WaitForSingleObject(stopped, 0) == WAIT_OBJECT_0) return 0;
                    try { reconcile(name, catalog, etag, names); }
                    catch (const writ::Error& error) {
                        ++errors; std::string message = "ERROR " + name + ": " + error.what() + " (" + std::to_string(error.code) + ")";
                        if (message != last_error) std::cout << message << std::endl;
                        last_error = message;
                    }
                }
                if (!errors) { last_error.clear(); std::cout << "SYNCED Folder scan complete" << std::endl; }
            } catch (const std::exception& error) {
                ++errors; std::string message = "ERROR " + std::string(error.what());
                if (message != last_error) std::cout << message << std::endl;
                last_error = message;
            }
        } while (!once && WaitForSingleObject(stopped, errors ? 15000 : 5000) == WAIT_TIMEOUT);
        return once && errors ? 2 : 0;
    }
};
} // namespace writ_sync

int wmain(int argc, wchar_t** argv) {
    using namespace writ_sync;
    try {
        std::wstring command = argc > 1 ? argv[1] : L"run";
        if (command == L"configure-stdin" && argc == 2) {
            SecretFields<7> scratch; auto& fields = scratch.values;
            for (auto& field : fields) {
                // Bounded character reads; secret values never enter argv/logs.
                for (;;) { int c = std::cin.get(); if (c == '\n') break;
                    if (c == EOF || field.size() >= 2048 || c < 32 || c > 126) throw writ::Error("Invalid connection input", ERROR_INVALID_DATA);
                    field += static_cast<char>(c);
                }
            }
            Connection connection{fields[0], fields[1], fields[2], fields[3]}; connection.validate();
            Credentials credentials(fields[4], fields[5], fields[6]); credentials.save(connection); connection.save();
            std::cout << "CONFIGURED Credentials saved in Windows Credential Manager" << std::endl; return 0;
        }
        auto root = writ::canonical(argc > 2 ? fs::path(argv[2]) : home_directory() / L"Writ Cloud");
        if (command == L"stop" && argc <= 3) {
            writ::Handle stop(OpenEventW(EVENT_MODIFY_STATE, FALSE, object_name(root, L"-stop").c_str()));
            if (stop.value) writ::check(SetEvent(stop), "Stop directory sync");
            else if (GetLastError() != ERROR_FILE_NOT_FOUND) writ::check(false, "Open directory stop event");
            return 0;
        }
        if ((command != L"run" && command != L"once") || argc > 4) throw writ::Error("Usage: writ-sync [run|once [folder [state]]] | stop [folder] | configure-stdin", ERROR_INVALID_PARAMETER);
        auto connection = Connection::load();
        if (!connection) throw writ::Error("Connect S3-compatible storage in Writ Settings", ERROR_NOT_FOUND);
        auto state = writ::canonical(argc > 3 ? fs::path(argv[3]) : app_directory() / profile_id(*connection, root));
        wchar_t binary[32768]; DWORD length = GetModuleFileNameW(nullptr, binary, 32768);
        writ::check(length && length < 32768, "Executable path");
        Provider provider(fs::path(binary).parent_path(), root, state, *connection);
        return provider.run(command == L"once");
    } catch (const writ::Error& error) {
        std::cerr << "ERROR " << error.what() << " (" << error.code << ")\n"; return 2;
    } catch (const std::exception& error) { std::cerr << "ERROR " << error.what() << '\n'; return 2; }
}
