#pragma once
#define WIN32_LEAN_AND_MEAN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <winternl.h>
#include <winioctl.h>
#include <cfapi.h>
#include <bcrypt.h>
#include <sddl.h>
#include <shlobj.h>
#include <algorithm>
#include <array>
#include <atomic>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <mutex>
#include <stdexcept>
#include <string>
#include <vector>

namespace writ {
namespace fs = std::filesystem;
using Bytes = std::vector<unsigned char>;
constexpr DWORD max_bytes = 65536;

struct Error : std::runtime_error {
    DWORD code;
    Error(const char* what, DWORD value) : std::runtime_error(what), code(value) {}
};
inline void check(bool ok, const char* what) {
    if (!ok) throw Error(what, GetLastError());
}
inline void hr(HRESULT result, const char* what) {
    if (FAILED(result)) throw Error(what, static_cast<DWORD>(result));
}
struct Handle {
    HANDLE value = INVALID_HANDLE_VALUE;
    explicit Handle(HANDLE h = INVALID_HANDLE_VALUE) : value(h) {}
    Handle(const Handle&) = delete;
    Handle& operator=(const Handle&) = delete;
    Handle(Handle&& h) noexcept : value(h.value) { h.value = INVALID_HANDLE_VALUE; }
    ~Handle() { if (value && value != INVALID_HANDLE_VALUE) CloseHandle(value); }
    operator HANDLE() const { return value; }
};
inline Handle open(const fs::path& path, DWORD access, DWORD share, DWORD create = OPEN_EXISTING,
                   DWORD flags = FILE_ATTRIBUTE_NORMAL) {
    Handle h(CreateFileW(path.c_str(), access, share, nullptr, create, flags, nullptr));
    check(h.value != INVALID_HANDLE_VALUE, "CreateFile");
    return h;
}
inline void read_exact(HANDLE h, void* out, DWORD size) {
    DWORD got = 0;
    check(ReadFile(h, out, size, &got, nullptr), "ReadFile");
    if (got != size) throw Error("short read", ERROR_INVALID_DATA);
}
inline void write_exact(HANDLE h, const void* data, DWORD size) {
    DWORD wrote = 0;
    check(WriteFile(h, data, size, &wrote, nullptr), "WriteFile");
    if (wrote != size) throw Error("short write", ERROR_WRITE_FAULT);
}
inline std::string hex(const unsigned char* data, size_t size) {
    static constexpr char digits[] = "0123456789abcdef";
    std::string out(size * 2, '0');
    for (size_t i = 0; i < size; ++i) {
        out[2 * i] = digits[data[i] >> 4]; out[2 * i + 1] = digits[data[i] & 15];
    }
    return out;
}
inline std::string hex(const Bytes& b) { return hex(b.data(), b.size()); }
inline std::string digest(const void* data, size_t size) {
    std::array<unsigned char, 32> hash{};
    if (size > MAXDWORD || BCryptHash(BCRYPT_SHA256_ALG_HANDLE, nullptr, 0,
        static_cast<PUCHAR>(const_cast<void*>(data)), static_cast<ULONG>(size),
        hash.data(), static_cast<ULONG>(hash.size())) < 0)
        throw Error("BCryptHash", ERROR_INVALID_DATA);
    return hex(hash.data(), hash.size());
}
inline std::string nonce() {
    std::array<unsigned char, 16> bytes{};
    if (BCryptGenRandom(nullptr, bytes.data(), static_cast<ULONG>(bytes.size()),
        BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0) throw Error("BCryptGenRandom", ERROR_GEN_FAILURE);
    return hex(bytes.data(), bytes.size());
}
inline Bytes read_bytes(HANDLE h) {
    LARGE_INTEGER size{}, zero{};
    check(GetFileSizeEx(h, &size), "GetFileSizeEx");
    if (size.QuadPart < 0 || size.QuadPart > max_bytes) throw Error("64 KiB limit", ERROR_FILE_TOO_LARGE);
    check(SetFilePointerEx(h, zero, nullptr, FILE_BEGIN), "seek");
    Bytes bytes(static_cast<size_t>(size.QuadPart));
    read_exact(h, bytes.data(), static_cast<DWORD>(bytes.size()));
    return bytes;
}
inline fs::path canonical(const fs::path& input) {
    auto p = fs::absolute(input).lexically_normal();
    auto s = p.native();
    if (s.size() < 4 || s.size() > 220 || s[1] != L':' || s[2] != L'\\' ||
        s.find(L'"') != std::wstring::npos || s.find(L':', 2) != std::wstring::npos)
        throw Error("use a local absolute path shorter than 221 characters", ERROR_BAD_PATHNAME);
    while (s.size() > 3 && s.back() == L'\\') s.pop_back();
    return fs::path(s);
}
inline std::wstring folded(const fs::path& p) {
    std::wstring s = p.native();
    if (!s.empty()) CharLowerBuffW(s.data(), static_cast<DWORD>(s.size()));
    return s;
}
inline bool inside(const fs::path& child, const fs::path& parent) {
    auto a = folded(child), b = folded(parent) + L"\\";
    return a.compare(0, b.size(), b) == 0;
}
inline void local_user_path(const fs::path& p) {
    wchar_t profile[MAX_PATH], volume[MAX_PATH], filesystem[MAX_PATH];
    hr(SHGetFolderPathW(nullptr, CSIDL_PROFILE, nullptr, SHGFP_TYPE_CURRENT, profile), "profile");
    if (!inside(p, canonical(profile))) throw Error("demo paths must be beneath this user's profile", ERROR_ACCESS_DENIED);
    check(GetVolumePathNameW(p.c_str(), volume, MAX_PATH), "volume path");
    check(GetVolumeInformationW(volume, nullptr, 0, nullptr, nullptr, nullptr, filesystem, MAX_PATH), "volume");
    if (_wcsicmp(filesystem, L"NTFS") || GetDriveTypeW(volume) != DRIVE_FIXED)
        throw Error("local NTFS required", ERROR_NOT_SUPPORTED);
    for (auto part = p; part.has_relative_path(); part = part.parent_path()) {
        DWORD attr = GetFileAttributesW(part.c_str());
        if (attr != INVALID_FILE_ATTRIBUTES && (attr & FILE_ATTRIBUTE_REPARSE_POINT))
            throw Error("reparse point in demo path", ERROR_REPARSE_TAG_MISMATCH);
    }
}
inline void private_directory(const fs::path& p) {
    if (fs::exists(p)) {
        auto attr = GetFileAttributesW(p.c_str());
        if (!(attr & FILE_ATTRIBUTE_DIRECTORY) || (attr & FILE_ATTRIBUTE_REPARSE_POINT))
            throw Error("unsafe directory", ERROR_ACCESS_DENIED);
        return;
    }
    Handle token;
    check(OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token.value), "token");
    std::array<unsigned char, 512> user{}; DWORD needed = 0;
    check(GetTokenInformation(token, TokenUser, user.data(), static_cast<DWORD>(user.size()), &needed), "user SID");
    LPWSTR sid = nullptr;
    check(ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(user.data())->User.Sid, &sid), "SID string");
    std::wstring acl = L"D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;" + std::wstring(sid) + L")";
    LocalFree(sid);
    PSECURITY_DESCRIPTOR sd = nullptr;
    check(ConvertStringSecurityDescriptorToSecurityDescriptorW(acl.c_str(), SDDL_REVISION_1, &sd, nullptr), "ACL");
    SECURITY_ATTRIBUTES sa{sizeof(sa), sd, FALSE};
    BOOL ok = CreateDirectoryW(p.c_str(), &sa); DWORD error = GetLastError();
    LocalFree(sd);
    if (!ok) throw Error("CreateDirectory", error);
}
inline void durable_file(const fs::path& p, const void* bytes, DWORD size) {
    auto h = open(p, GENERIC_WRITE, 0, CREATE_NEW, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_WRITE_THROUGH);
    write_exact(h, bytes, size);
    check(FlushFileBuffers(h), "FlushFileBuffers");
}
inline void atomic_file(const fs::path& p, const void* bytes, DWORD size) {
    fs::path temp = p.parent_path() / ("tmp-" + nonce());
    durable_file(temp, bytes, size);
    // A failed/uncertain rename leaves both the old destination and staging data.
    check(MoveFileExW(temp.c_str(), p.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH), "atomic replace");
}

// Native disk framing only: little-endian Windows x64, fixed 80-byte metadata.
// The logical entry, CAS decision and writeback lifecycle live in PublicSync.
struct Meta {
    char magic[8] = {'W','R','I','T','P','0','1',0};
    DWORD version = 0, size = 0;
    char sha[64]{};
};
static_assert(sizeof(Meta) == 80, "disk frame");
inline std::string hash(const Meta& m) { return std::string(m.sha, sizeof(m.sha)); }
inline void valid(const Meta& m) {
    if (memcmp(m.magic, "WRITP01", 8) || !m.version || m.version > 4096 || m.size > max_bytes ||
        !std::all_of(m.sha, m.sha + 64, [](char c) { return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'); }))
        throw Error("invalid metadata", ERROR_INVALID_DATA);
}
inline bool same(const Meta& a, const Meta& b) { return memcmp(&a, &b, sizeof(a)) == 0; }
inline Meta metadata(DWORD version, const Bytes& bytes) {
    Meta m; m.version = version; m.size = static_cast<DWORD>(bytes.size());
    auto sha = digest(bytes.data(), bytes.size()); memcpy(m.sha, sha.data(), 64); valid(m); return m;
}
inline Meta read_meta(const fs::path& p) {
    auto h = open(p, GENERIC_READ, FILE_SHARE_READ); Meta m;
    LARGE_INTEGER size{}; check(GetFileSizeEx(h, &size), "metadata size");
    if (size.QuadPart != sizeof(Meta)) throw Error("metadata framing", ERROR_INVALID_DATA);
    read_exact(h, &m, sizeof(m)); valid(m); return m;
}

class Store {
public:
    fs::path path;
    explicit Store(fs::path p) : path(std::move(p)) {}
    Handle lock() const { return open(path / L"store.lock", GENERIC_READ | GENERIC_WRITE, 0, OPEN_ALWAYS); }
    Meta head() const { return read_meta(path / L"head"); }
    fs::path version_path(DWORD n) const { return path / ("version-" + std::to_string(n)); }
    Bytes read(const Meta& m) const {
        auto h = open(version_path(m.version), GENERIC_READ, FILE_SHARE_READ);
        Meta actual; read_exact(h, &actual, sizeof(actual));
        LARGE_INTEGER size{}; check(GetFileSizeEx(h, &size), "record size");
        if (!same(m, actual) || size.QuadPart != sizeof(Meta) + m.size) throw Error("version mismatch", ERROR_INVALID_DATA);
        Bytes bytes(m.size); read_exact(h, bytes.data(), m.size);
        if (digest(bytes.data(), bytes.size()) != hash(m)) throw Error("version checksum", ERROR_CRC);
        return bytes;
    }
    void publish(const Meta& m, const Bytes& bytes) const {
        // Caller holds store.lock from the observed head through Bend PREPARE
        // and this effect. An orphan from a crash can only be reused byte-for-byte.
        auto target = version_path(m.version);
        if (fs::exists(target)) {
            if (read(m) != bytes) throw Error("orphan version collision", ERROR_ALREADY_EXISTS);
        } else {
            auto staging = path / ("version-tmp-" + nonce());
            {
                auto h = open(staging, GENERIC_WRITE, 0, CREATE_NEW, FILE_FLAG_WRITE_THROUGH);
                write_exact(h, &m, sizeof(m)); write_exact(h, bytes.data(), m.size);
                check(FlushFileBuffers(h), "flush version");
            }
            check(MoveFileExW(staging.c_str(), target.c_str(), MOVEFILE_WRITE_THROUGH), "publish immutable version");
        }
        atomic_file(path / L"head", &m, sizeof(m));
        if (!same(head(), m) || read(m) != bytes) throw Error("persistence readback", ERROR_WRITE_FAULT);
    }
};
} // namespace writ
