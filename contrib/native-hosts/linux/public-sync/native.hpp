#pragma once
#include <algorithm>
#include <array>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <mutex>
#include <stdexcept>
#include <string>
#include <vector>
#include <fcntl.h>
#include <openssl/evp.h>
#include <pwd.h>
#include <sys/file.h>
#include <sys/random.h>
#include <sys/stat.h>
#include <sys/statfs.h>
#include <sys/wait.h>
#include <sys/xattr.h>
#include <unistd.h>

namespace writ {
namespace fs = std::filesystem;
using Bytes = std::vector<unsigned char>;
constexpr size_t max_bytes = 65536;
struct Error : std::runtime_error {
    int code;
    Error(const char* what, int c = errno) : std::runtime_error(what), code(c ? c : EIO) {}
};
inline void check(bool ok, const char* what) { if (!ok) throw Error(what); }
struct Fd {
    int value = -1;
    explicit Fd(int n = -1) : value(n) {}
    Fd(const Fd&) = delete;
    Fd& operator=(const Fd&) = delete;
    Fd(Fd&& f) noexcept : value(f.value) { f.value = -1; }
    ~Fd() { if (value >= 0) ::close(value); }
    operator int() const { return value; }
    int release() { int n = value; value = -1; return n; }
};
inline Fd open_file(const fs::path& p, int flags, mode_t mode = 0600) {
    Fd fd(::open(p.c_str(), flags | O_CLOEXEC | O_NOFOLLOW, mode));
    check(fd.value >= 0, "open native file"); return fd;
}
inline void write_all(int fd, const void* data, size_t size) {
    auto p = static_cast<const unsigned char*>(data);
    while (size) {
        ssize_t n = ::write(fd, p, size);
        if (n < 0 && errno == EINTR) continue;
        check(n > 0, "write native file"); p += n; size -= static_cast<size_t>(n);
    }
}
inline void read_exact(int fd, void* data, size_t size, off_t offset = 0) {
    auto p = static_cast<unsigned char*>(data);
    while (size) {
        ssize_t n = ::pread(fd, p, size, offset);
        if (n < 0 && errno == EINTR) continue;
        if (!n) throw Error("short native read", EIO);
        check(n > 0, "read native file"); p += n; size -= static_cast<size_t>(n); offset += n;
    }
}
inline struct stat file_stat(int fd) {
    struct stat s{}; check(::fstat(fd, &s) == 0, "native file metadata"); return s;
}
inline Bytes read_bytes(int fd) {
    auto s = file_stat(fd);
    if (!S_ISREG(s.st_mode) || s.st_size < 0 || static_cast<uint64_t>(s.st_size) > max_bytes)
        throw Error("regular file up to 64 KiB required", EFBIG);
    Bytes b(static_cast<size_t>(s.st_size)); read_exact(fd, b.data(), b.size()); return b;
}
inline std::string hex(const void* input, size_t size) {
    auto p = static_cast<const unsigned char*>(input);
    static constexpr char digits[] = "0123456789abcdef";
    std::string out(size * 2, '0');
    for (size_t i = 0; i < size; ++i) { out[2*i] = digits[p[i] >> 4]; out[2*i+1] = digits[p[i] & 15]; }
    return out;
}
inline std::string hex(const Bytes& bytes) { return hex(bytes.data(), bytes.size()); }
inline std::string digest(const void* input, size_t size) {
    unsigned char result[EVP_MAX_MD_SIZE]; unsigned int length = 0;
    if (EVP_Digest(input, size, result, &length, EVP_sha256(), nullptr) != 1 || length != 32)
        throw Error("native SHA-256 observation", EIO);
    return hex(result, length);
}
inline std::string nonce() {
    std::array<unsigned char, 16> data{}; size_t n = 0;
    while (n < data.size()) {
        ssize_t got = ::getrandom(data.data() + n, data.size() - n, 0);
        if (got < 0 && errno == EINTR) continue;
        check(got > 0, "native random bytes"); n += static_cast<size_t>(got);
    }
    return hex(data.data(), data.size());
}
inline bool inside(const fs::path& p, const fs::path& parent) {
    auto a = p.native(), b = parent.native() + "/"; return a.compare(0, b.size(), b) == 0;
}
inline fs::path account_home() {
    std::array<char, 16384> buffer{}; struct passwd entry{}, *result = nullptr;
    check(::getpwuid_r(::getuid(), &entry, buffer.data(), buffer.size(), &result) == 0 && result, "account home");
    return fs::canonical(entry.pw_dir);
}
inline fs::path canonical(const fs::path& input) {
    auto path = fs::absolute(input).lexically_normal();
    // Fedora's system /home alias is resolved only at the known account root.
    std::array<char, 16384> buffer{}; struct passwd entry{}, *result = nullptr;
    check(::getpwuid_r(::getuid(), &entry, buffer.data(), buffer.size(), &result) == 0 && result, "account home");
    fs::path alias = fs::path(entry.pw_dir).lexically_normal();
    if (path == alias) path = account_home();
    else if (inside(path, alias)) path = account_home() / path.lexically_relative(alias);
    const auto text = path.native();
    if (text.size() > 1000 || std::any_of(text.begin(), text.end(), [](unsigned char c){ return c < 32 || c == 127; }))
        throw Error("bounded ordinary native path required", EINVAL);
    return path;
}
inline void user_path(const fs::path& path, bool skip_leaf = false) {
    auto home = account_home();
    if (!inside(path, home)) throw Error("paths must be beneath this account's home", EACCES);
    for (auto p = skip_leaf ? path.parent_path() : path; p != home; p = p.parent_path()) {
        struct stat s{};
        if (::lstat(p.c_str(), &s) == 0) {
            if (S_ISLNK(s.st_mode) || s.st_uid != ::getuid()) throw Error("foreign or symlink path", EACCES);
        } else if (errno != ENOENT) throw Error("path inspection");
    }
}
inline void private_directory(const fs::path& path) {
    struct stat s{};
    if (::lstat(path.c_str(), &s) == 0) {
        if (!S_ISDIR(s.st_mode) || s.st_uid != ::getuid() || (s.st_mode & 0077))
            throw Error("private owned directory required", EACCES);
    } else {
        if (errno != ENOENT) throw Error("directory inspection");
        check(::mkdir(path.c_str(), 0700) == 0, "create private directory");
    }
}
inline void sync_directory(const fs::path& path) {
    auto fd = open_file(path, O_RDONLY | O_DIRECTORY); check(::fsync(fd) == 0, "flush directory");
}
inline void durable_file(const fs::path& path, const void* bytes, size_t size) {
    auto fd = open_file(path, O_WRONLY | O_CREAT | O_EXCL);
    write_all(fd, bytes, size); check(::fsync(fd) == 0, "flush native file"); sync_directory(path.parent_path());
}
inline void atomic_file(const fs::path& path, const void* bytes, size_t size) {
    auto temporary = path.parent_path() / ("tmp-" + nonce());
    durable_file(temporary, bytes, size);
    check(::rename(temporary.c_str(), path.c_str()) == 0, "publish native file"); sync_directory(path.parent_path());
}
inline void local_store(const fs::path& path) {
    user_path(path); auto parent = path;
    while (!fs::exists(parent)) parent = parent.parent_path();
    struct statfs s{}; check(::statfs(parent.c_str(), &s) == 0, "store filesystem");
    // Qualified POSIX persistence targets; never silently use a network/cache FS.
    if (s.f_type != 0xef53 && s.f_type != 0x58465342 && static_cast<uint64_t>(s.f_type) != 0x9123683e)
        throw Error("local ext4, XFS or Btrfs backing required", ENOTSUP);
}

// Native disk framing matches the Windows public preview on little-endian x64.
struct Meta {
    char magic[8] = {'W','R','I','T','P','0','1',0};
    uint32_t version = 0, size = 0;
    char sha[64]{};
};
static_assert(sizeof(Meta) == 80, "WRITP01 frame");
inline std::string hash(const Meta& m) { return std::string(m.sha, sizeof(m.sha)); }
inline void valid(const Meta& m) {
    if (std::memcmp(m.magic, "WRITP01", 8) || !m.version || m.version > 4096 || m.size > max_bytes ||
        !std::all_of(m.sha, m.sha + 64, [](char c){ return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'); }))
        throw Error("invalid metadata", EINVAL);
}
inline bool same(const Meta& a, const Meta& b) { return std::memcmp(&a, &b, sizeof(a)) == 0; }
inline Meta metadata(uint32_t version, const Bytes& bytes) {
    Meta m; m.version = version; m.size = static_cast<uint32_t>(bytes.size());
    auto h = digest(bytes.data(), bytes.size()); std::memcpy(m.sha, h.data(), 64); valid(m); return m;
}
inline Meta read_meta(const fs::path& p) {
    auto fd = open_file(p, O_RDONLY); Meta m;
    if (file_stat(fd).st_size != static_cast<off_t>(sizeof(m))) throw Error("metadata frame size", EINVAL);
    read_exact(fd, &m, sizeof(m)); valid(m); return m;
}
inline bool attribute(int fd, const char* name, Meta& m) {
    ssize_t size = ::fgetxattr(fd, name, &m, sizeof(m));
    if (size < 0 && errno == ENODATA) return false;
    if (size != static_cast<ssize_t>(sizeof(m))) throw Error("native placeholder attribute", EINVAL);
    valid(m); return true;
}
inline void clear_attribute(int fd, const char* name) {
    if (::fremovexattr(fd, name) != 0 && errno != ENODATA) throw Error("clear native attribute");
}
inline void set_attribute(int fd, const char* name, const Meta& m) {
    check(::fsetxattr(fd, name, &m, sizeof(m), 0) == 0, "set native attribute");
}
class Store {
public:
    fs::path path;
    explicit Store(fs::path p) : path(std::move(p)) {}
    Fd lock() const {
        auto fd = open_file(path / "store.lock", O_RDWR | O_CREAT);
        check(::flock(fd, LOCK_EX | LOCK_NB) == 0, "exclusive backing store lock"); return fd;
    }
    Meta head() const { return read_meta(path / "head"); }
    fs::path version_path(uint32_t n) const { return path / ("version-" + std::to_string(n)); }
    Bytes read(const Meta& m) const {
        auto fd = open_file(version_path(m.version), O_RDONLY); Meta actual;
        read_exact(fd, &actual, sizeof(actual));
        if (!same(actual, m) || file_stat(fd).st_size != static_cast<off_t>(sizeof(m) + m.size))
            throw Error("backing version identity", EINVAL);
        Bytes bytes(m.size); read_exact(fd, bytes.data(), bytes.size(), sizeof(m));
        if (digest(bytes.data(), bytes.size()) != hash(m)) throw Error("backing version checksum", EIO);
        return bytes;
    }
    void publish(const Meta& m, const Bytes& bytes) const {
        // The caller retains store.lock across head observation and Bend PREPARE.
        auto target = version_path(m.version);
        if (fs::exists(target)) {
            if (read(m) != bytes) throw Error("orphan version collision", EEXIST);
        } else {
            auto temp = path / ("version-tmp-" + nonce());
            auto fd = open_file(temp, O_WRONLY | O_CREAT | O_EXCL);
            write_all(fd, &m, sizeof(m)); write_all(fd, bytes.data(), bytes.size());
            check(::fsync(fd) == 0, "flush backing version");
            check(::link(temp.c_str(), target.c_str()) == 0, "publish immutable version");
            check(::unlink(temp.c_str()) == 0, "retire version staging link"); sync_directory(path);
        }
        atomic_file(path / "head", &m, sizeof(m));
        if (!same(head(), m) || read(m) != bytes) throw Error("backing persistence readback", EIO);
    }
};
} // namespace writ
