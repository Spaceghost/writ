#pragma once
#include "connection.hpp"
#include <map>
#include <set>
extern "C" {
#include "../policy_pipe.h"
}

namespace writ_sync {
constexpr DWORD maximum_file = 1073741824, maximum_catalog = 4 * 1024 * 1024;
constexpr size_t maximum_entries = 2048;
inline std::string empty_hash() { return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"; }
struct Snapshot { DWORD kind = 0, version = 0, size = 0; std::string hash = empty_hash(); };
struct Reply { bool ok; DWORD value; std::string detail; };
class Monitor {
    WRIT_POLICY_PIPE pipe{};
public:
    Monitor(const fs::path& package, const wchar_t* module = L"directory-sync.mjs") {
        writ::check(writ_policy_start(&pipe, (package / L"node.exe").c_str(),
            (package / L"node-policy.mjs").c_str(), (package / module).c_str()), "Start directory Bend monitor");
    }
    ~Monitor() { writ_policy_stop(&pipe); }
    Monitor(const Monitor&) = delete;
    Monitor& operator=(const Monitor&) = delete;
    Reply call(const char* op, DWORD a = 0, DWORD b = 0, DWORD c = 0, const std::string& body = "-") {
        std::string request = "WRITFS1\t" + std::string(op) + "\t" + std::to_string(a) + "\t" +
            std::to_string(b) + "\t" + std::to_string(c) + "\t0\t" + body + "\n";
        char response[WRIT_POLICY_REPLY_MAX];
        writ::check(writ_policy_exchange(&pipe, request.c_str(), response, sizeof(response)), "Directory Bend transport stopped");
        std::string text(response); size_t p = text.find('\t'); p = text.find('\t', p + 1);
        size_t q = text.find('\t', p + 1), r = text.find('\t', q + 1);
        return {text.substr(p + 1, q - p - 1) == "OK",
            static_cast<DWORD>(std::stoul(text.substr(q + 1, r - q - 1))), text.substr(r + 1)};
    }
    Reply require(const char* op, DWORD a = 0, DWORD b = 0, DWORD c = 0, const std::string& body = "-") {
        auto result = call(op, a, b, c, body);
        if (!result.ok) throw writ::Error(("Bend: " + result.detail).c_str(), ERROR_INVALID_DATA);
        return result;
    }
    Reply snapshot(const char* op, const Snapshot& value) { return require(op, value.kind, value.version, value.size, value.hash); }
    void chunks(HANDLE file, DWORD size, HANDLE copy = INVALID_HANDLE_VALUE) {
        if (!size) return;
        LARGE_INTEGER zero{}; writ::check(SetFilePointerEx(file, zero, nullptr, FILE_BEGIN), "Rewind frozen file");
        std::array<unsigned char, 65536> bytes{};
        for (DWORD offset = 0; offset < size;) {
            DWORD count = std::min<DWORD>(size - offset, static_cast<DWORD>(bytes.size()));
            writ::read_exact(file, bytes.data(), count);
            require("CHUNK", offset, 0, 0, writ::hex(bytes.data(), count));
            if (copy != INVALID_HANDLE_VALUE) writ::write_exact(copy, bytes.data(), count);
            offset += count;
        }
    }
};

// This codec is native disk/S3 framing only. Bend validates revisions, object
// kinds, bounds, namespace ancestry, and every proposed reconciliation effect.
using Catalog = std::map<std::string, Snapshot>;
inline void u32(Bytes& out, DWORD value) { for (unsigned i = 0; i < 4; ++i) out.push_back(static_cast<unsigned char>(value >> (i * 8))); }
inline DWORD u32(const Bytes& bytes, size_t& position) {
    if (position > bytes.size() || bytes.size() - position < 4) throw writ::Error("Truncated directory catalog", ERROR_INVALID_DATA);
    DWORD value = 0; for (unsigned i = 0; i < 4; ++i) value |= static_cast<DWORD>(bytes[position++]) << (i * 8);
    return value;
}
inline std::string take(const Bytes& bytes, size_t& position, size_t count) {
    if (position > bytes.size() || count > bytes.size() - position) throw writ::Error("Truncated directory record", ERROR_INVALID_DATA);
    std::string value(reinterpret_cast<const char*>(bytes.data() + position), count); position += count; return value;
}
inline Bytes encode(const Catalog& catalog) {
    if (catalog.size() > maximum_entries) throw writ::Error("Directory entry limit reached", ERROR_FILE_TOO_LARGE);
    Bytes bytes{'W','R','I','T','D','I','R','1'}; u32(bytes, static_cast<DWORD>(catalog.size()));
    for (const auto& [path, value] : catalog) {
        if (path.empty() || path.size() > 2048 || value.hash.size() != 64) throw writ::Error("Directory record framing", ERROR_INVALID_DATA);
        u32(bytes, static_cast<DWORD>(path.size())); bytes.insert(bytes.end(), path.begin(), path.end());
        u32(bytes, value.kind); u32(bytes, value.version); u32(bytes, value.size);
        bytes.insert(bytes.end(), value.hash.begin(), value.hash.end());
    }
    if (bytes.size() > maximum_catalog) throw writ::Error("Directory catalog size limit", ERROR_FILE_TOO_LARGE);
    return bytes;
}
inline Catalog decode(const Bytes& bytes) {
    if (bytes.size() < 12 || bytes.size() > maximum_catalog || memcmp(bytes.data(), "WRITDIR1", 8))
        throw writ::Error("Directory catalog format", ERROR_INVALID_DATA);
    size_t position = 8; DWORD count = u32(bytes, position);
    if (count > maximum_entries) throw writ::Error("Directory entry limit", ERROR_FILE_TOO_LARGE);
    Catalog catalog; std::string previous;
    for (DWORD i = 0; i < count; ++i) {
        DWORD length = u32(bytes, position);
        if (!length || length > 2048) throw writ::Error("Directory path size", ERROR_INVALID_DATA);
        auto path = take(bytes, position, length);
        if (!previous.empty() && path <= previous) throw writ::Error("Noncanonical directory order", ERROR_INVALID_DATA);
        previous = path;
        Snapshot value; value.kind = u32(bytes, position); value.version = u32(bytes, position); value.size = u32(bytes, position);
        value.hash = take(bytes, position, 64); catalog.emplace(std::move(path), std::move(value));
    }
    if (position != bytes.size()) throw writ::Error("Trailing directory bytes", ERROR_INVALID_DATA);
    return catalog;
}
inline fs::path relative_path(const std::string& name) {
    auto value = utf16(name);
    if (value.empty() || value.size() > 512 || value.front() == L'/' || value.back() == L'/')
        throw writ::Error("Unsupported Windows path length", ERROR_BAD_PATHNAME);
    size_t start = 0;
    for (;;) {
        auto end = value.find(L'/', start); auto part = value.substr(start, end == std::wstring::npos ? end : end - start);
        if (part.empty() || part.size() > 120 || part.back() == L'.' || part.back() == L' ')
            throw writ::Error("Ambiguous Windows filename", ERROR_BAD_PATHNAME);
        for (wchar_t c : part) if (c < 32 || wcschr(L"\\:*?\"<>|", c)) throw writ::Error("Unsupported Windows filename", ERROR_BAD_PATHNAME);
        auto stem = part.substr(0, part.find(L'.')); CharUpperBuffW(stem.data(), static_cast<DWORD>(stem.size()));
        if (stem == L"CON" || stem == L"PRN" || stem == L"AUX" || stem == L"NUL" || stem == L"CONIN$" || stem == L"CONOUT$" ||
            (stem.size() == 4 && (stem.substr(0, 3) == L"COM" || stem.substr(0, 3) == L"LPT") &&
              ((stem[3] >= L'0' && stem[3] <= L'9') || stem[3] == L'\u00b9' || stem[3] == L'\u00b2' || stem[3] == L'\u00b3')))
            throw writ::Error("Reserved Windows filename", ERROR_BAD_PATHNAME);
        if (end == std::wstring::npos) break;
        start = end + 1;
    }
    std::replace(value.begin(), value.end(), L'/', L'\\'); return fs::path(value);
}
inline std::string namespace_key(const fs::path& path) {
    if (path.empty()) return "-";
    std::string key;
    for (const auto& component : path) {
    auto value = component.native();
    int length = LCMapStringEx(LOCALE_NAME_INVARIANT, LCMAP_UPPERCASE, value.data(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr, 0);
    writ::check(length > 0, "Windows namespace folding");
    std::wstring folded(static_cast<size_t>(length), 0);
    writ::check(LCMapStringEx(LOCALE_NAME_INVARIANT, LCMAP_UPPERCASE, value.data(), static_cast<int>(value.size()), folded.data(), length, nullptr, nullptr, 0) == length, "Windows namespace folding");
    if (!key.empty()) key += '/';
    key += writ::hex(reinterpret_cast<const unsigned char*>(folded.data()), folded.size() * sizeof(wchar_t));
    }
    return key;
}
inline void namespace_record(Monitor& names, const char* command, const std::string& path, const Snapshot& value) {
    auto relative = relative_path(path);
    names.require(command, value.kind, value.version, value.size, namespace_key(relative) + ":" + namespace_key(relative.parent_path()) + ":" + value.hash);
}
inline void validate_catalog(Monitor& names, const Catalog& catalog) {
    for (const auto& [path, value] : catalog) {
        namespace_record(names, "ENTRY", path, value);
    }
    names.require("END");
}
inline void validate_catalog(const fs::path& package, const Catalog& catalog) {
    Monitor names(package, L"directory-namespace.mjs"); validate_catalog(names, catalog);
}
inline Snapshot get(const Catalog& catalog, const std::string& path) {
    auto found = catalog.find(path); return found == catalog.end() ? Snapshot{} : found->second;
}
inline Snapshot inspect(HANDLE handle) {
    FILE_ATTRIBUTE_TAG_INFO attributes{}; FILE_STANDARD_INFO info{};
    writ::check(GetFileInformationByHandleEx(handle, FileAttributeTagInfo, &attributes, sizeof(attributes)), "Directory file attributes");
    writ::check(GetFileInformationByHandleEx(handle, FileStandardInfo, &info, sizeof(info)), "Directory file metadata");
    if (attributes.FileAttributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DEVICE | FILE_ATTRIBUTE_OFFLINE))
        throw writ::Error("Reparse points and offline files are not supported in this sync folder", ERROR_NOT_SUPPORTED);
    if ((!info.Directory && info.NumberOfLinks != 1) || info.DeletePending || info.EndOfFile.QuadPart < 0 || info.EndOfFile.QuadPart > maximum_file)
        throw writ::Error("Unsupported file or 1 GiB file limit exceeded", ERROR_NOT_SUPPORTED);
    return {info.Directory ? 2u : 1u, 0, info.Directory ? 0u : static_cast<DWORD>(info.EndOfFile.QuadPart), empty_hash()};
}
inline void exact_path(HANDLE handle, const fs::path& expected) {
    std::array<wchar_t, 32768> name{};
    DWORD length = GetFinalPathNameByHandleW(handle, name.data(), static_cast<DWORD>(name.size()), FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
    writ::check(length > 0 && length < name.size(), "Retained file pathname");
    std::wstring actual(name.data(), length);
    if (actual.rfind(L"\\\\?\\", 0) == 0) actual.erase(0, 4);
    auto wanted = expected.native();
    if (CompareStringOrdinal(actual.c_str(), static_cast<int>(actual.size()), wanted.c_str(), static_cast<int>(wanted.size()), TRUE) != CSTR_EQUAL)
        throw writ::Error("Filename alias or renamed object is not an exact sync path", ERROR_BAD_PATHNAME);
}
// Holding each ancestor without WRITE/DELETE sharing excludes replacement or
// reparse-point mutation while opening/applying a descendant. Child I/O remains
// possible; each target is separately frozen and verified through Bend.
class Parents {
    std::vector<writ::Handle> handles;
public:
    explicit Parents(const fs::path& directory, bool allow_missing = false) {
        fs::path path = directory.root_path();
        for (const auto& part : directory.relative_path()) {
            path /= part;
            HANDLE handle = CreateFileW(path.c_str(), FILE_READ_ATTRIBUTES, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
                FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
            if (allow_missing && handle == INVALID_HANDLE_VALUE &&
                (GetLastError() == ERROR_FILE_NOT_FOUND || GetLastError() == ERROR_PATH_NOT_FOUND)) break;
            writ::check(handle != INVALID_HANDLE_VALUE, "Retain directory ancestor");
            handles.emplace_back(handle);
            if (inspect(handles.back()).kind != 2) throw writ::Error("Directory ancestor required", ERROR_DIRECTORY);
            exact_path(handles.back(), path);
        }
    }
};
inline writ::Handle frozen(const fs::path& path, bool deleting = false) {
    HANDLE file = CreateFileW(path.c_str(), GENERIC_READ | (deleting ? DELETE : 0), FILE_SHARE_READ,
        nullptr, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (file == INVALID_HANDLE_VALUE && (GetLastError() == ERROR_FILE_NOT_FOUND || GetLastError() == ERROR_PATH_NOT_FOUND)) return writ::Handle{};
    writ::check(file != INVALID_HANDLE_VALUE, "Freeze local object (close any writer and retry)");
    writ::Handle result(file); inspect(result); exact_path(result, path); return result;
}
inline void move_retained(HANDLE handle, const fs::path& destination) {
    auto name = destination.native();
    size_t bytes = offsetof(FILE_RENAME_INFO, FileName) + name.size() * sizeof(wchar_t);
    std::vector<unsigned char> storage(bytes); auto rename = reinterpret_cast<FILE_RENAME_INFO*>(storage.data());
    rename->ReplaceIfExists = FALSE; rename->RootDirectory = nullptr;
    rename->FileNameLength = static_cast<DWORD>(name.size() * sizeof(wchar_t)); memcpy(rename->FileName, name.data(), rename->FileNameLength);
    writ::check(SetFileInformationByHandle(handle, FileRenameInfo, rename, static_cast<DWORD>(bytes)), "Move retained object to recovery");
}
inline Bytes read_catalog(const fs::path& path) {
    auto handle = frozen(path);
    if (handle.value == INVALID_HANDLE_VALUE) return encode({});
    auto meta = inspect(handle);
    if (meta.kind != 1 || meta.size > maximum_catalog) throw writ::Error("Local catalog bound", ERROR_INVALID_DATA);
    Bytes bytes(meta.size); writ::read_exact(handle, bytes.data(), meta.size); return bytes;
}
} // namespace writ_sync
