#define FUSE_USE_VERSION 31
#include <fuse.h>
#include "native.hpp"
#include <atomic>
#include <fstream>
#include <poll.h>
#include <set>
#include <signal.h>
#include <sstream>
#include <sys/socket.h>
#include <sys/un.h>
#include <thread>
extern "C" {
#include "../policy_pipe.h"
}
#ifndef WRIT_VERSION
#define WRIT_VERSION "development"
#define WRIT_SOURCE_COMMIT "unknown"
#endif

namespace writ {
constexpr const char* stub_attribute = "user.writ.stub";
constexpr const char* sync_attribute = "user.writ.synced";
static volatile sig_atomic_t interrupted = 0;
static void interrupt(int) { interrupted = 1; }
static std::mutex output_mutex;
static void event(const std::string& text) {
    std::lock_guard<std::mutex> guard(output_mutex); std::cout << text << std::endl;
}
static std::string path_key(const fs::path& root) {
    auto name = root.native(); return digest(name.data(), name.size());
}
static fs::path state_path(const Store& store, const fs::path& root) { return store.path / "roots" / path_key(root); }
static std::string identity(const Store& store, const fs::path& root) { return root.native() + "\n" + store.path.native() + "\n"; }
static std::string mount_name(const Store& store, const fs::path& root) {
    auto name = identity(store, root); return "writ-public-" + digest(name.data(), name.size());
}
static fs::path runtime_directory() {
    fs::path path = "/tmp/writ-public-" + std::to_string(::getuid());
    // A short, private socket path avoids sockaddr_un's 108-byte limit even
    // when the account's XDG/home path is long. Never follow a precreated link.
    private_directory(path); return path;
}
static fs::path control_path(const fs::path& root) { return runtime_directory() / (path_key(root) + ".sock"); }
static Fd root_lock(const fs::path& root) {
    auto fd = open_file(runtime_directory() / (path_key(root) + ".lock"), O_RDWR | O_CREAT);
    auto s = file_stat(fd);
    if (s.st_uid != ::getuid() || !S_ISREG(s.st_mode) || s.st_nlink != 1) throw Error("owned root lock required", EACCES);
    check(::flock(fd, LOCK_EX | LOCK_NB) == 0, "root already served"); return fd;
}
static std::string unescape_mount(std::string value) {
    std::string result;
    for (size_t i = 0; i < value.size(); ++i) {
        if (value[i] == '\\' && i + 3 < value.size()) {
            auto code = value.substr(i + 1, 3);
            if (code == "040") result += ' ';
            else if (code == "011") result += '\t';
            else if (code == "012") result += '\n';
            else if (code == "134") result += '\\';
            else throw Error("unknown mount escape", EINVAL);
            i += 3;
        } else result += value[i];
    }
    return result;
}
static bool owned_mount(const fs::path& root, const Store& store) {
    std::ifstream input("/proc/self/mountinfo");
    if (!input) throw Error("native mount inventory", EIO);
    std::string line; size_t count = 0;
    while (std::getline(input, line)) {
        if (++count > 8192 || line.size() > 16384) throw Error("mount inventory bound", E2BIG);
        std::istringstream fields(line); std::string field, point;
        for (int i = 0; i < 5; ++i) { if (!(fields >> field)) throw Error("mount inventory framing", EIO); point = field; }
        if (unescape_mount(point) != root.native()) continue;
        while (fields >> field && field != "-") {}
        std::string type, source; fields >> type >> source;
        if (type != "fuse.writ-public" || source != mount_name(store, root)) throw Error("foreign mount at requested root", EACCES);
        return true;
    }
    return false;
}
static void unmount_owned(const fs::path& root, const Store& store) {
    if (!owned_mount(root, store)) return;
    pid_t child = ::fork(); check(child >= 0, "spawn owned unmount");
    if (!child) { ::execl("/usr/bin/fusermount3", "fusermount3", "-u", root.c_str(), static_cast<char*>(nullptr)); ::_exit(127); }
    int status = 0; pid_t waited;
    do { waited = ::waitpid(child, &status, 0); } while (waited < 0 && errno == EINTR);
    if (waited != child || !WIFEXITED(status) || WEXITSTATUS(status)) throw Error("owned mount is busy or unmount failed", EBUSY);
    if (owned_mount(root, store)) throw Error("owned mount remained attached", EBUSY);
}
static void owned_registration(const fs::path& root, const Store& store) {
    auto fd = open_file(state_path(store, root) / "identity", O_RDONLY);
    auto bytes = read_bytes(fd); auto expected = identity(store, root);
    if (std::string(bytes.begin(), bytes.end()) != expected) throw Error("foreign root registration", EACCES);
}
static void owned_directory(const fs::path& path) {
    struct stat s{};
    if (::lstat(path.c_str(), &s) == 0) {
        if (!S_ISDIR(s.st_mode) || s.st_uid != ::getuid()) throw Error("owned directory required", EACCES);
    } else { if (errno != ENOENT) throw Error("root inspection"); check(::mkdir(path.c_str(), 0700) == 0, "create root"); }
}
static std::string entry_name(const char* path) {
    if (!path || path[0] != '/' || !path[1]) throw Error("file name required", ENOENT);
    std::string name(path + 1);
    if (name.size() > 255 || name == "." || name == ".." || name.find('/') != std::string::npos ||
        std::any_of(name.begin(), name.end(), [](unsigned char c){ return c < 32 || c == 127; }))
        throw Error("one-level regular file name required", EINVAL);
    return name;
}
static std::vector<fs::path> entries(const fs::path& directory) {
    std::vector<fs::path> result;
    for (const auto& item : fs::directory_iterator(directory)) {
        if (result.size() >= 256) throw Error("256 local file limit", ENOSPC);
        struct stat s{}; check(::lstat(item.path().c_str(), &s) == 0, "local entry metadata");
        if (!S_ISREG(s.st_mode) || s.st_nlink != 1 || s.st_uid != ::getuid() || s.st_size < 0 ||
            static_cast<uint64_t>(s.st_size) > max_bytes) throw Error("bounded owned regular files required", EINVAL);
        entry_name(("/" + item.path().filename().native()).c_str()); result.push_back(item.path());
    }
    return result;
}
static void materialize(const fs::path& root, const fs::path& cache) {
    // Unmount first. Preserve unexpected user files instead of overwriting them.
    owned_directory(root);
    for (const auto& path : entries(cache)) {
        auto fd = open_file(path, O_RDONLY); Meta stub;
        if (attribute(fd, stub_attribute, stub)) continue;
        auto bytes = read_bytes(fd); auto destination = root / path.filename();
        if (fs::exists(destination)) {
            auto existing = open_file(destination, O_RDONLY);
            if (read_bytes(existing) != bytes) throw Error("different materialized user file retained", EEXIST);
        } else atomic_file(destination, bytes.data(), bytes.size());
    }
}
static Fd connect_control(const fs::path& root) {
    Fd fd(::socket(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0)); check(fd.value >= 0, "control socket");
    struct sockaddr_un address{}; address.sun_family = AF_UNIX;
    auto path = control_path(root).native();
    if (path.size() >= sizeof(address.sun_path)) throw Error("control socket path bound", ENAMETOOLONG);
    std::memcpy(address.sun_path, path.c_str(), path.size() + 1);
    check(::connect(fd, reinterpret_cast<struct sockaddr*>(&address), sizeof(address)) == 0, "connect owned provider");
    struct ucred peer{}; socklen_t size = sizeof(peer);
    check(::getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &peer, &size) == 0 && peer.uid == ::getuid(), "control peer identity");
    return fd;
}
static void send_control(int fd, const std::string& text) {
    if (text.size() > 1024 || ::send(fd, text.data(), text.size(), MSG_NOSIGNAL) != static_cast<ssize_t>(text.size()))
        throw Error("control write", EIO);
}
static std::string receive_control(int fd, int timeout = 30000) {
    struct pollfd request{fd, POLLIN, 0}; int ready;
    do { ready = ::poll(&request, 1, timeout); } while (ready < 0 && errno == EINTR);
    if (ready != 1) throw Error("control timeout", ETIMEDOUT);
    std::array<char, 1025> buffer{}; ssize_t count = ::recv(fd, buffer.data(), buffer.size(), MSG_TRUNC);
    if (count <= 0 || count > 1024) throw Error("control frame", EIO);
    return std::string(buffer.data(), static_cast<size_t>(count));
}
class Monitor {
    struct writ_policy pipe{};
public:
    Monitor(const char* node, const char* bridge, const char* module) {
        if (writ_policy_start(&pipe, node, bridge, module)) throw Error("start Bend monitor", EIO);
    }
    ~Monitor() { writ_policy_stop(&pipe); }
    struct writ_reply call(const char* op, uint32_t a = 0, uint32_t b = 0, const std::string& body = "-") {
        struct writ_reply reply{};
        if (writ_policy_call(&pipe, op, a, b, 0, 0, body.c_str(), &reply)) throw Error("Bend transport stopped", EPIPE);
        return reply;
    }
    struct writ_reply require(const char* op, uint32_t a = 0, uint32_t b = 0, const std::string& body = "-") {
        auto reply = call(op, a, b, body);
        if (reply.status != writ_reply::WRIT_OK) throw Error((std::string("Bend: ") + reply.detail).c_str(), EACCES);
        return reply;
    }
};
struct Provider {
    Store store;
    fs::path root, state, cache;
    Monitor monitor;
    Meta base;
    std::mutex mutex;
    std::set<int> handles;
    bool fail_writeback, in_sync = false, stopping = false;
    std::atomic<bool> loop_done{false};
    size_t fetched = 0, recoveries = 0;
    std::string last_attempt;
    struct fuse* mount = nullptr;
    Provider(fs::path r, Store s, const char* node, const char* bridge, const char* module, bool fail)
        : store(std::move(s)), root(std::move(r)), state(state_path(store, root)), cache(state / "cache"),
          monitor(node, bridge, module), fail_writeback(fail) {}

    void initialize() {
        private_directory(store.path / "roots"); private_directory(state);
        bool fresh = !fs::exists(state / "identity");
        if (fresh) {
            if (owned_mount(root, store)) throw Error("unrecorded mounted root", EACCES);
            owned_directory(root);
            if (!fs::is_empty(root)) throw Error("new root must be empty", ENOTEMPTY);
            auto name = identity(store, root); durable_file(state / "identity", name.data(), name.size());
        } else { owned_registration(root, store); unmount_owned(root, store); owned_directory(root); }
        private_directory(cache); private_directory(state / "recovery");
        if (!fs::exists(state / "base")) {
            auto lock = store.lock(); base = store.head(); atomic_file(state / "base", &base, sizeof(base));
        } else base = read_meta(state / "base");
        size_t recovery_entries = 0;
        for (const auto& item : fs::directory_iterator(state / "recovery")) {
            if (++recovery_entries > 512) throw Error("recovery entry capacity", ENOSPC);
            if (item.path().extension() == ".bin" && ++recoveries > 256) throw Error("recovery capacity", ENOSPC);
        }
        // Offline edits in the materialized root are imported without replacing
        // a different retained cache blindly. The old cache remains recoverable.
        for (const auto& path : entries(root)) {
            auto source = open_file(path, O_RDONLY); auto bytes = read_bytes(source);
            auto target = cache / path.filename(); bool equal = false;
            if (fs::exists(target)) {
                auto previous = open_file(target, O_RDONLY); Meta stub;
                if (!attribute(previous, stub_attribute, stub)) equal = read_bytes(previous) == bytes;
                if (!equal && path.filename() == "hello.txt" && !attribute(previous, stub_attribute, stub)) {
                    auto old = read_bytes(previous); recovery(old);
                }
            }
            if (!equal) atomic_file(target, bytes.data(), bytes.size());
            check(::unlink(path.c_str()) == 0, "import offline user file"); sync_directory(root);
        }
        monitor.require("INIT", base.version, base.size, hash(base));
        auto listing = monitor.require("LIST", 0, 0, "hello.txt");
        if (listing.value != base.size || listing.detail != hash(base)) throw Error("Bend listing metadata", EIO);
        auto hello = cache / "hello.txt";
        if (!fs::exists(hello)) {
            auto fd = open_file(hello, O_RDWR | O_CREAT | O_EXCL);
            set_attribute(fd, stub_attribute, base); set_attribute(fd, sync_attribute, base);
            check(::ftruncate(fd, base.size) == 0 && ::fsync(fd) == 0, "create metadata-only placeholder"); sync_directory(cache);
        }
        auto fd = open_file(hello, O_RDONLY); Meta receipt, stub;
        in_sync = attribute(fd, sync_attribute, receipt) && same(receipt, base);
        if (in_sync && !attribute(fd, stub_attribute, stub)) {
            auto bytes = read_bytes(fd);
            in_sync = same(metadata(base.version, bytes), base);
            if (in_sync) monitor.require("READ", base.version, 0, hex(bytes));
        }
    }
    void hydrate(int fd) {
        Meta stub; if (!attribute(fd, stub_attribute, stub)) return;
        auto bytes = store.read(stub); monitor.require("READ", stub.version, 0, hex(bytes));
        fetched += bytes.size();
        check(::ftruncate(fd, 0) == 0 && ::lseek(fd, 0, SEEK_SET) == 0, "hydrate position");
        write_all(fd, bytes.data(), bytes.size()); check(::fsync(fd) == 0, "flush hydrated payload");
        clear_attribute(fd, stub_attribute); check(::fsync(fd) == 0, "flush hydration state");
        event("FETCH bytes=" + std::to_string(bytes.size()) + " version=" + std::to_string(stub.version));
    }
    bool current_file(int fd) {
        struct stat current{}; auto actual = file_stat(fd);
        return ::lstat((cache / "hello.txt").c_str(), &current) == 0 && current.st_ino == actual.st_ino && current.st_dev == actual.st_dev;
    }
    void dirty(int fd) {
        clear_attribute(fd, sync_attribute);
        if (current_file(fd)) { in_sync = false; last_attempt.clear(); }
    }
    void recovery(const Bytes& bytes) {
        if (recoveries >= 256) throw Error("recovery capacity; edits retained", ENOSPC);
        auto name = nonce(); durable_file(state / "recovery" / (name + ".bin"), bytes.data(), bytes.size());
        ++recoveries; durable_file(state / "recovery" / (name + ".base"), &base, sizeof(base)); event("RECOVERY " + name + ".bin");
    }
    static std::string fingerprint(int fd) {
        auto s = file_stat(fd);
        return std::to_string(s.st_dev) + ":" + std::to_string(s.st_ino) + ":" + std::to_string(s.st_size) + ":" +
            std::to_string(s.st_mtim.tv_sec) + ":" + std::to_string(s.st_mtim.tv_nsec) + ":" +
            std::to_string(s.st_ctim.tv_sec) + ":" + std::to_string(s.st_ctim.tv_nsec);
    }
    void commit() {
        // Every caller holds mutex, as do ALL FUSE data/metadata mutations.
        // Direct I/O and no shared mmap keep accepted writes inside this guard.
        if (in_sync || !fs::exists(cache / "hello.txt")) return;
        auto fd = open_file(cache / "hello.txt", O_RDWR); Meta stub;
        if (attribute(fd, stub_attribute, stub)) return;
        auto before = fingerprint(fd); if (before == last_attempt) return;
        auto bytes = read_bytes(fd); bool attempted = false;
        try {
            auto lock = store.lock(); recovery(bytes);
            auto observed = store.head(); auto proposal = monitor.call("PREPARE", base.version, observed.version, hex(bytes));
            if (proposal.status != writ_reply::WRIT_OK) {
                last_attempt = before; event(std::string("WRITEBACK_FAILED ") + proposal.detail + " local_edit_retained"); return;
            }
            attempted = true; auto replacement = metadata(proposal.value, bytes);
            if (hash(replacement) != proposal.detail) throw Error("candidate checksum", EIO);
            if (fail_writeback) throw Error("injected writeback failure", EIO);
            store.publish(replacement, bytes);
            monitor.require("PERSISTED", replacement.version, replacement.size, hash(replacement));
            atomic_file(state / "base", &replacement, sizeof(replacement)); base = replacement;
            monitor.require("MATCH", base.version, 0, hex(read_bytes(fd)));
            if (!current_file(fd) || fingerprint(fd) != before) throw Error("local identity changed during writeback", ESTALE);
            set_attribute(fd, sync_attribute, base); check(::fsync(fd) == 0, "flush native in-sync receipt");
            in_sync = true; last_attempt.clear(); event("COMMIT version=" + std::to_string(base.version) + " sha256=" + hash(base));
        } catch (const Error& e) {
            if (!attempted && (e.code == EWOULDBLOCK || e.code == EAGAIN)) return;
            if (e.code == EPIPE) throw;
            if (attempted) monitor.require("FAILED");
            last_attempt = fingerprint(fd); event(std::string("WRITEBACK_FAILED ") + e.what() + " local_edit_retained");
        }
    }
    int retained(struct fuse_file_info* fi) {
        if (!fi || fi->fh > INT32_MAX || !handles.count(static_cast<int>(fi->fh))) throw Error("native handle lifetime", EBADF);
        return static_cast<int>(fi->fh);
    }
    int remember(Fd fd, struct fuse_file_info* fi) {
        if (handles.size() >= 128) throw Error("128 open handle limit", EMFILE);
        fi->fh = static_cast<uint64_t>(fd.value); fi->direct_io = 1; fi->keep_cache = 0;
        handles.insert(fd.release()); return 0;
    }
    std::string status() {
        auto fd = open_file(cache / "hello.txt", O_RDONLY); auto s = file_stat(fd); Meta stub;
        bool pending = attribute(fd, stub_attribute, stub);
        return "{\"mounted\":true,\"placeholder\":true,\"inSync\":" + std::string(in_sync ? "true" : "false") +
            ",\"size\":" + std::to_string(s.st_size) + ",\"onDisk\":" + std::to_string(pending ? 0 : s.st_size) +
            ",\"fetchedBytes\":" + std::to_string(fetched) + ",\"openHandles\":" + std::to_string(handles.size()) + "}";
    }
    void run();
};
template<class Function> static int callback(Function action) noexcept {
    auto* p = static_cast<Provider*>(fuse_get_context()->private_data);
    std::lock_guard<std::mutex> guard(p->mutex);
    try { if (p->stopping) return -ESHUTDOWN; return action(*p); }
    catch (const Error& e) { if (e.code == EPIPE) interrupted = 1; return -e.code; }
    catch (...) { interrupted = 1; return -EIO; }
}
static struct fuse_operations operations() {
    struct fuse_operations ops{};
    ops.init = [](struct fuse_conn_info*, struct fuse_config* cfg) -> void* {
        cfg->entry_timeout = cfg->attr_timeout = cfg->negative_timeout = 0;
        cfg->direct_io = 1; cfg->kernel_cache = 0; cfg->hard_remove = 1; cfg->nullpath_ok = 1;
        return fuse_get_context()->private_data;
    };
    ops.getattr = [](const char* path, struct stat* out, struct fuse_file_info* fi) {
        return callback([&](Provider& p) {
            if (path && !std::strcmp(path, "/")) { *out = {}; out->st_mode = S_IFDIR | 0700; out->st_nlink = 2; out->st_uid = ::getuid(); out->st_gid = ::getgid(); return 0; }
            Fd temporary(fi ? -1 : open_file(p.cache / entry_name(path), O_RDONLY).release());
            int fd = fi ? p.retained(fi) : temporary.value; *out = file_stat(fd); Meta stub;
            if (attribute(fd, stub_attribute, stub)) out->st_blocks = 0;
            return 0;
        });
    };
    ops.readdir = [](const char* path, void* buffer, fuse_fill_dir_t fill, off_t, struct fuse_file_info*, enum fuse_readdir_flags) {
        return callback([&](Provider& p) {
            // With nullpath_ok, FUSE omits the path for an already-open
            // directory. This bounded profile has only the root directory.
            if (path && std::strcmp(path, "/")) return -ENOTDIR;
            p.monitor.require("LIST", 0, 0, "hello.txt");
            fill(buffer, ".", nullptr, 0, static_cast<fuse_fill_dir_flags>(0)); fill(buffer, "..", nullptr, 0, static_cast<fuse_fill_dir_flags>(0));
            for (const auto& file : entries(p.cache)) if (fill(buffer, file.filename().c_str(), nullptr, 0, static_cast<fuse_fill_dir_flags>(0))) break;
            return 0;
        });
    };
    ops.open = [](const char* path, struct fuse_file_info* fi) {
        return callback([&](Provider& p) {
            auto fd = open_file(p.cache / entry_name(path), O_RDWR);
            // FUSE may negotiate atomic O_TRUNC, in which case open itself
            // must discard the old contents before acknowledging the handle.
            if (fi->flags & O_TRUNC) {
                clear_attribute(fd, stub_attribute); p.dirty(fd);
                check(::ftruncate(fd, 0) == 0 && ::fsync(fd) == 0, "truncate on open");
            }
            return p.remember(std::move(fd), fi);
        });
    };
    ops.create = [](const char* path, mode_t, struct fuse_file_info* fi) {
        return callback([&](Provider& p) {
            auto name = entry_name(path); if (entries(p.cache).size() >= 256) return -ENOSPC;
            auto fd = open_file(p.cache / name, O_RDWR | O_CREAT | O_EXCL); sync_directory(p.cache);
            if (name == "hello.txt") p.in_sync = false;
            return p.remember(std::move(fd), fi);
        });
    };
    ops.read = [](const char*, char* buffer, size_t size, off_t offset, struct fuse_file_info* fi) {
        return callback([&](Provider& p) {
            if (offset < 0) return -EINVAL;
            int fd = p.retained(fi); p.hydrate(fd); size = std::min(size, max_bytes);
            ssize_t count; do { count = ::pread(fd, buffer, size, offset); } while (count < 0 && errno == EINTR);
            check(count >= 0, "read cached file"); return static_cast<int>(count);
        });
    };
    ops.write = [](const char*, const char* buffer, size_t size, off_t offset, struct fuse_file_info* fi) {
        return callback([&](Provider& p) {
            if (offset < 0 || static_cast<uint64_t>(offset) > max_bytes || size > max_bytes - static_cast<size_t>(offset)) return -EFBIG;
            int fd = p.retained(fi); p.hydrate(fd); p.dirty(fd);
            ssize_t count; do { count = ::pwrite(fd, buffer, size, offset); } while (count < 0 && errno == EINTR);
            check(count >= 0, "write cached edit"); check(::fsync(fd) == 0, "flush local edit"); return static_cast<int>(count);
        });
    };
    ops.truncate = [](const char* path, off_t size, struct fuse_file_info* fi) {
        return callback([&](Provider& p) {
            if (size < 0 || static_cast<uint64_t>(size) > max_bytes) return -EFBIG;
            Fd temporary(fi ? -1 : open_file(p.cache / entry_name(path), O_RDWR).release());
            int fd = fi ? p.retained(fi) : temporary.value;
            if (size) p.hydrate(fd); else clear_attribute(fd, stub_attribute);
            p.dirty(fd); check(::ftruncate(fd, size) == 0 && ::fsync(fd) == 0, "truncate local edit"); return 0;
        });
    };
    ops.flush = [](const char*, struct fuse_file_info* fi) {
        return callback([&](Provider& p) { check(::fsync(p.retained(fi)) == 0, "flush local file"); p.commit(); return 0; });
    };
    ops.fsync = [](const char*, int, struct fuse_file_info* fi) {
        return callback([&](Provider& p) { check(::fsync(p.retained(fi)) == 0, "fsync local file"); p.commit(); return 0; });
    };
    ops.release = [](const char*, struct fuse_file_info* fi) {
        return callback([&](Provider& p) { int fd = p.retained(fi); p.handles.erase(fd); check(::close(fd) == 0, "close local file"); return 0; });
    };
    ops.rename = [](const char* from, const char* to, unsigned int flags) {
        return callback([&](Provider& p) {
            if (flags) return -EINVAL;
            auto a = entry_name(from), b = entry_name(to);
            auto fd = open_file(p.cache / a, O_RDWR); p.hydrate(fd);
            check(::rename((p.cache / a).c_str(), (p.cache / b).c_str()) == 0, "editor replacement"); sync_directory(p.cache);
            if (a == "hello.txt" || b == "hello.txt") { p.in_sync = false; p.last_attempt.clear(); }
            if (b == "hello.txt") { p.dirty(fd); check(::fsync(fd) == 0, "flush replacement identity"); p.commit(); }
            return 0;
        });
    };
    ops.unlink = [](const char* path) {
        return callback([&](Provider& p) {
            auto name = entry_name(path); auto fd = open_file(p.cache / name, O_RDWR);
            if (name == "hello.txt") { p.hydrate(fd); p.recovery(read_bytes(fd)); p.in_sync = false; }
            check(::unlink((p.cache / name).c_str()) == 0, "unlink local file"); sync_directory(p.cache); return 0;
        });
    };
    ops.chmod = [](const char* path, mode_t mode, struct fuse_file_info* fi) {
        return callback([&](Provider& p) {
            Fd temporary(fi ? -1 : open_file(p.cache / entry_name(path), O_RDWR).release());
            check(::fchmod(fi ? p.retained(fi) : temporary.value, mode & 0600) == 0, "local file mode"); return 0;
        });
    };
    ops.utimens = [](const char* path, const struct timespec times[2], struct fuse_file_info* fi) {
        return callback([&](Provider& p) {
            Fd temporary(fi ? -1 : open_file(p.cache / entry_name(path), O_RDWR).release());
            check(::futimens(fi ? p.retained(fi) : temporary.value, times) == 0, "local file timestamps"); return 0;
        });
    };
    ops.statfs = [](const char*, struct statvfs* out) {
        return callback([&](Provider& p) { check(::statvfs(p.cache.c_str(), out) == 0, "cache capacity"); return 0; });
    };
    ops.lseek = [](const char*, off_t offset, int whence, struct fuse_file_info* fi) -> off_t {
        // The missing payload is logical data, not a zero-filled sparse hole.
        auto* p = static_cast<Provider*>(fuse_get_context()->private_data); std::lock_guard<std::mutex> guard(p->mutex);
        try {
            int fd = p->retained(fi); auto s = file_stat(fd); Meta stub;
            if (attribute(fd, stub_attribute, stub) && (whence == SEEK_DATA || whence == SEEK_HOLE)) {
                if (offset < 0 || offset >= s.st_size) return -ENXIO;
                return whence == SEEK_DATA ? offset : s.st_size;
            }
            off_t result = ::lseek(fd, offset, whence); return result < 0 ? -errno : result;
        } catch (const Error& e) { return -e.code; } catch (...) { return -EIO; }
    };
    return ops;
}

void Provider::run() {
    initialize();
    auto lease = open_file(state / "provider.lock", O_RDWR | O_CREAT);
    check(::flock(lease, LOCK_EX | LOCK_NB) == 0, "provider already running");
    auto socket_path = control_path(root);
    struct stat old{};
    if (::lstat(socket_path.c_str(), &old) == 0) {
        if (!S_ISSOCK(old.st_mode) || old.st_uid != ::getuid()) throw Error("foreign control path", EACCES);
        check(::unlink(socket_path.c_str()) == 0, "retire stale control socket");
    } else if (errno != ENOENT) throw Error("control path inspection");
    Fd listener(::socket(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0)); check(listener.value >= 0, "create control listener");
    struct sockaddr_un address{}; address.sun_family = AF_UNIX;
    auto socket_name = socket_path.native();
    if (socket_name.size() >= sizeof(address.sun_path)) throw Error("control path bound", ENAMETOOLONG);
    std::memcpy(address.sun_path, socket_name.c_str(), socket_name.size() + 1);
    check(::bind(listener, reinterpret_cast<struct sockaddr*>(&address), sizeof(address)) == 0 && ::listen(listener, 8) == 0, "bind control listener");
    std::string options = "fsname=" + mount_name(store, root) + ",subtype=writ-public,default_permissions";
    std::string program = "writ-linux", option = "-o";
    char* argv[] = {program.data(), option.data(), options.data()};
    struct fuse_args arguments = FUSE_ARGS_INIT(3, argv);
    auto ops = operations(); mount = fuse_new(&arguments, &ops, sizeof(ops), this); fuse_opt_free_args(&arguments);
    if (!mount) throw Error("initialize native FUSE", EIO);
    if (fuse_mount(mount, root.c_str()) != 0) {
        fuse_destroy(mount); mount = nullptr; materialize(root, cache);
        throw Error("mount FUSE; system fusermount3 and /dev/fuse are required", EIO);
    }
    int loop_result = 0;
    std::thread loop([&] { loop_result = fuse_loop(mount); loop_done = true; });
    auto finish = [&] {
        {
            std::lock_guard<std::mutex> guard(mutex);
            if (!loop_done && !handles.empty()) throw Error("close files before stopping Writ", EBUSY);
            commit(); stopping = true;
        }
        try { unmount_owned(root, store); }
        catch (...) { std::lock_guard<std::mutex> guard(mutex); stopping = false; throw; }
        if (loop.joinable()) loop.join();
        fuse_destroy(mount); mount = nullptr;
        for (int fd : handles) ::close(fd);
        handles.clear(); materialize(root, cache);
        check(::unlink(socket_path.c_str()) == 0, "retire control socket");
        event("STOPPED hydrated files, backing state and recoveries retained");
        if (loop_result) throw Error("native FUSE loop failed", EIO);
    };
    try {
        event("READY version=" + std::to_string(base.version) + " payload_bytes_fetched=" + std::to_string(fetched));
        for (;;) {
            if (loop_done) { finish(); return; }
            if (interrupted) {
                try { finish(); return; }
                catch (const Error& e) {
                    if (!mount) throw;
                    interrupted = 0; event(std::string("STOP_FAILED ") + e.what());
                }
            }
            struct pollfd request{listener, POLLIN, 0}; int ready = ::poll(&request, 1, 500);
            if (ready < 0 && errno == EINTR) continue;
            check(ready >= 0, "poll native control");
            if (ready) {
                Fd client(::accept4(listener, nullptr, nullptr, SOCK_CLOEXEC)); check(client.value >= 0, "accept native control");
                try {
                    struct ucred peer{}; socklen_t length = sizeof(peer);
                    check(::getsockopt(client, SOL_SOCKET, SO_PEERCRED, &peer, &length) == 0 && peer.uid == ::getuid(), "control caller identity");
                    auto command = receive_control(client, 5000);
                    if (command == "STOP") { finish(); send_control(client, "STOPPED"); return; }
                    if (command == "STATUS") { std::lock_guard<std::mutex> guard(mutex); send_control(client, status()); }
                    else if (command == "PROBE_LOCK") {
                        // The same guard used by snapshot/persistence/readback
                        // blocks real FUSE write and rename callbacks in Smoke.
                        std::lock_guard<std::mutex> guard(mutex);
                        send_control(client, "LOCK_PROBE_READY");
                        if (receive_control(client) != "RELEASE") throw Error("lock probe release framing", EINVAL);
                        send_control(client, "RELEASED");
                    } else throw Error("unknown control operation", EINVAL);
                } catch (const Error& e) {
                    try { send_control(client, std::string("ERROR ") + e.what()); } catch (...) {}
                    if (!mount) throw;
                }
            }
            std::lock_guard<std::mutex> guard(mutex); commit();
        }
    } catch (const std::exception& e) {
        if (loop.joinable()) {
            // An uncertain transport/control failure is fail-stop. Kernel
            // disconnect and the retained cache allow explicit owned recovery.
            event(std::string("FATAL ") + e.what() + "; cache and recovery retained"); std::_Exit(1);
        }
        throw;
    }
}
static void seed(const Store& store) {
    local_store(store.path); private_directory(store.path); auto lock = store.lock();
    if (fs::exists(store.path / "head")) { valid(store.head()); event("SEEDED existing_store"); return; }
    const char text[] = "Hello from Writ!\r\nThis is public fixture data. Edit and save me in Notepad.\r\n";
    Bytes bytes(text, text + sizeof(text) - 1); store.publish(metadata(1, bytes), bytes); event("SEEDED public_hello");
}
static fs::path default_root() {
    const char* home = ::getenv("HOME"); return writ::canonical((home && *home ? fs::path(home) : account_home()) / "Writ");
}
static fs::path default_store() {
    const char* data = ::getenv("XDG_DATA_HOME"), *home = ::getenv("HOME");
    auto parent = data && *data ? fs::path(data) : (home && *home ? fs::path(home) : account_home()) / ".local/share";
    return writ::canonical(parent / "WritDemo/store");
}
static fs::path package_directory() {
    std::array<char, 4096> path{}; ssize_t length = ::readlink("/proc/self/exe", path.data(), path.size());
    if (length <= 0 || static_cast<size_t>(length) == path.size()) throw Error("package executable path", EINVAL);
    return fs::path(std::string(path.data(), static_cast<size_t>(length))).parent_path();
}
static void stop(const fs::path& root) {
    try {
        // close(2) may return before FUSE dispatches its release callback.
        // Give only that native lifetime observation a bounded drain window;
        // a retained handle still refuses shutdown, and no unmount is forced.
        for (int attempt = 0;; ++attempt) {
            auto client = connect_control(root); send_control(client, "STOP");
            auto result = receive_control(client);
            if (result == "STOPPED") return;
            if (result != "ERROR close files before stopping Writ" || attempt == 10)
                throw Error(result.c_str(), EBUSY);
            if (attempt == 0) std::cout << "WAITING for open files to close before stopping Writ\n" << std::flush;
            ::usleep(100000);
        }
    } catch (const Error& e) { if (e.code != ENOENT && e.code != ECONNREFUSED) throw; }
}
static void remove(const fs::path& root, const Store& store) {
    auto lock = root_lock(root); local_store(store.path); user_path(root, true);
    owned_registration(root, store); unmount_owned(root, store); user_path(root);
    materialize(root, state_path(store, root) / "cache");
    event("REMOVED mount; local files, backing store and recovery retained");
}
static void cleanup_default() {
    auto root = default_root(); Store store(default_store());
    if (!fs::exists(state_path(store, root) / "identity")) return;
    stop(root);
    for (int attempt = 0;; ++attempt) {
        try { remove(root, store); return; }
        catch (const Error& e) {
            if ((e.code != EWOULDBLOCK && e.code != EAGAIN) || attempt == 100) throw;
            ::usleep(100000);
        }
    }
}
static void serve(const fs::path& root, const Store& store, const fs::path& node, const fs::path& bridge, const fs::path& module, bool fail) {
    local_store(store.path); user_path(root, true);
    if (root == store.path || inside(root, store.path) || inside(store.path, root)) throw Error("root and backing store must be independent", EINVAL);
    auto lock = root_lock(root);
    if (!owned_mount(root, store)) user_path(root);
    for (const auto& path : {node, bridge, module}) if (!fs::is_regular_file(path)) throw Error("extract the complete portable archive or install Writ", ENOENT);
    Provider provider(root, store, node.c_str(), bridge.c_str(), module.c_str(), fail); provider.run();
}
} // namespace writ

int main(int argc, char** argv) {
    using namespace writ;
    ::umask(0077); ::signal(SIGPIPE, SIG_IGN);
    struct sigaction action{}; action.sa_handler = interrupt; ::sigemptyset(&action.sa_mask);
    ::sigaction(SIGINT, &action, nullptr); ::sigaction(SIGTERM, &action, nullptr);
    try {
        if (argc == 1 || (argc == 2 && !std::strcmp(argv[1], "app")) ||
            (argc == 3 && !std::strcmp(argv[1], "app") &&
             (!std::strcmp(argv[2], "--no-open") || !std::strcmp(argv[2], "--stop")))) {
            auto package = package_directory(), node = package / "node", app = package / "drive/app.mjs";
            ::execl(node.c_str(), node.c_str(), app.c_str(), argc == 3 ? argv[2] : static_cast<char*>(nullptr), static_cast<char*>(nullptr));
            throw Error("start packaged Writ Drive application");
        }
        if (argc == 2 && !std::strcmp(argv[1], "start")) {
            auto root = default_root(), path = default_store(), package = package_directory();
            local_store(path); user_path(root, true);
            fs::create_directories(path.parent_path()); private_directory(path.parent_path()); seed(Store(path));
            std::cout << "Writ public preview: " << root << "/hello.txt\nKeep this window open while editing.\n";
            serve(root, Store(path), package / "node", package / "node-policy.mjs", package / "public-sync.mjs", false); return 0;
        }
        if (argc == 2 && !std::strcmp(argv[1], "version")) { std::cout << "Writ " WRIT_VERSION " (" WRIT_SOURCE_COMMIT ") Linux desktop preview\n"; return 0; }
        if (argc == 2 && !std::strcmp(argv[1], "cleanup")) { cleanup_default(); return 0; }
        if ((argc == 2 || argc == 3) && !std::strcmp(argv[1], "stop")) { stop(argc == 3 ? writ::canonical(argv[2]) : default_root()); return 0; }
        if (argc == 3 && !std::strcmp(argv[1], "seed")) { seed(Store(writ::canonical(argv[2]))); return 0; }
        if (argc == 3 && !std::strcmp(argv[1], "inspect")) {
            auto root = writ::canonical(argv[2]);
            try { auto client = connect_control(root); send_control(client, "STATUS"); std::cout << receive_control(client) << std::endl; }
            catch (const Error& e) {
                if (e.code != ENOENT && e.code != ECONNREFUSED) throw;
                struct stat s{}; if (::lstat((root / "hello.txt").c_str(), &s) && errno != ENOENT) throw Error("unmounted file metadata");
                std::cout << "{\"mounted\":false,\"placeholder\":false,\"inSync\":false,\"size\":" << s.st_size << "}" << std::endl;
            }
            return 0;
        }
        if (argc == 3 && !std::strcmp(argv[1], "probe-lock")) {
            auto client = connect_control(writ::canonical(argv[2])); send_control(client, "PROBE_LOCK");
            auto ready = receive_control(client); if (ready != "LOCK_PROBE_READY") throw Error(ready.c_str(), EIO);
            event(ready); std::string line; std::getline(std::cin, line);
            if (line != "RELEASE") throw Error("probe release input", EINVAL);
            send_control(client, line); if (receive_control(client) != "RELEASED") throw Error("probe release confirmation", EIO); return 0;
        }
        if ((argc == 7 || argc == 8) && !std::strcmp(argv[1], "serve")) {
            bool fail = argc == 8 && !std::strcmp(argv[7], "--fail-writeback");
            if (argc == 8 && !fail) throw Error("unknown option", EINVAL);
            serve(writ::canonical(argv[2]), Store(writ::canonical(argv[3])), fs::absolute(argv[4]), fs::absolute(argv[5]), fs::absolute(argv[6]), fail); return 0;
        }
        if (argc == 4 && !std::strcmp(argv[1], "remove")) { remove(writ::canonical(argv[2]), Store(writ::canonical(argv[3]))); return 0; }
        std::cout << "app (default) [--no-open | --stop] | start (local FUSE demo) | stop [ROOT] | cleanup | version\n"
            "seed STORE | serve ROOT STORE NODE BRIDGE MODULE [--fail-writeback] | inspect ROOT | remove ROOT STORE\n";
        return argc == 2 && !std::strcmp(argv[1], "--help") ? 0 : 2;
    } catch (const Error& e) { std::cerr << e.what() << " (" << e.code << ": " << std::strerror(e.code) << ")\n"; return 1; }
    catch (const std::exception& e) { std::cerr << e.what() << "\n"; return 1; }
}
