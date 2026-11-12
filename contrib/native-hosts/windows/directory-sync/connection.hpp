#pragma once
#include "../cloud-files/native.hpp"
#include <wincred.h>
#include <optional>

namespace writ_sync {
using writ::Bytes;
namespace fs = std::filesystem;
constexpr wchar_t connection_key[] = L"Software\\Writ\\S3";

inline std::string utf8(const std::wstring& value) {
    if (value.empty()) return {};
    int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
    writ::check(size > 0, "UTF-8 path");
    std::string result(static_cast<size_t>(size), 0);
    writ::check(WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()), result.data(), size, nullptr, nullptr) == size, "UTF-8 path");
    return result;
}
inline std::wstring utf16(const std::string& value) {
    if (value.empty()) return {};
    int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()), nullptr, 0);
    writ::check(size > 0, "UTF-16 path");
    std::wstring result(static_cast<size_t>(size), 0);
    writ::check(MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()), result.data(), size) == size, "UTF-16 path");
    return result;
}
inline bool printable(const std::string& text, size_t minimum, size_t maximum) {
    return text.size() >= minimum && text.size() <= maximum &&
        std::all_of(text.begin(), text.end(), [](unsigned char c) { return c >= 33 && c <= 126; });
}
struct Connection {
    std::string endpoint, bucket, prefix, region;
    void validate() const {
        if (!printable(endpoint, 9, 2048) || endpoint.rfind("https://", 0) != 0 ||
            !printable(bucket, 3, 63) || !printable(prefix, 1, 256) || !printable(region, 1, 32))
            throw writ::Error("Enter an HTTPS endpoint, bucket, prefix and region", ERROR_INVALID_PARAMETER);
        for (char c : bucket) if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '.'))
            throw writ::Error("Bucket must use lowercase S3 bucket characters", ERROR_INVALID_PARAMETER);
        for (char c : region) if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-'))
            throw writ::Error("Invalid S3 region", ERROR_INVALID_PARAMETER);
        if (prefix.front() == '/' || prefix.back() == '/' || prefix.find("..") != std::string::npos || prefix.find('\\') != std::string::npos)
            throw writ::Error("Use a relative S3 prefix without parent segments", ERROR_INVALID_PARAMETER);
    }
    std::string encoded() const { return endpoint + "\n" + bucket + "\n" + prefix + "\n" + region + "\n"; }
    std::wstring credential_target() const {
        auto bytes = encoded(); return L"Writ/S3/" + utf16(writ::digest(bytes.data(), bytes.size()));
    }
    std::string identity() const { auto bytes = encoded(); return writ::digest(bytes.data(), bytes.size()); }
    static std::optional<Connection> load() {
        char bytes[4096]; DWORD size = sizeof(bytes);
        LSTATUS result = RegGetValueW(HKEY_CURRENT_USER, connection_key, L"Connection", RRF_RT_REG_BINARY, nullptr, bytes, &size);
        if (result == ERROR_FILE_NOT_FOUND) return std::nullopt;
        if (result != ERROR_SUCCESS || !size || size > sizeof(bytes)) throw writ::Error("Read S3 connection settings", result);
        std::string text(bytes, size); std::array<std::string, 4> fields;
        size_t start = 0;
        for (auto& field : fields) {
            auto end = text.find('\n', start);
            if (end == std::string::npos) throw writ::Error("Invalid S3 settings framing", ERROR_INVALID_DATA);
            field = text.substr(start, end - start); start = end + 1;
        }
        if (start != text.size()) throw writ::Error("Extra S3 settings fields", ERROR_INVALID_DATA);
        Connection connection{fields[0], fields[1], fields[2], fields[3]}; connection.validate(); return connection;
    }
    void save() const {
        validate(); HKEY key = nullptr;
        LSTATUS result = RegCreateKeyExW(HKEY_CURRENT_USER, connection_key, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &key, nullptr);
        if (result != ERROR_SUCCESS) throw writ::Error("Open S3 settings", result);
        auto bytes = encoded();
        result = RegSetValueExW(key, L"Connection", 0, REG_BINARY, reinterpret_cast<const BYTE*>(bytes.data()), static_cast<DWORD>(bytes.size()));
        RegCloseKey(key);
        if (result != ERROR_SUCCESS) throw writ::Error("Save S3 settings", result);
    }
};

struct Credentials {
    std::string access, secret, token;
    Credentials(std::string a, std::string s, std::string t) : access(std::move(a)), secret(std::move(s)), token(std::move(t)) {}
    Credentials(const Credentials&) = delete;
    Credentials& operator=(const Credentials&) = delete;
    ~Credentials() {
        SecureZeroMemory(secret.data(), secret.size()); SecureZeroMemory(token.data(), token.size());
    }
    void validate() const {
        if (!printable(access, 1, 128) || !printable(secret, 1, 256) || (!token.empty() && !printable(token, 1, 2000)))
            throw writ::Error("Invalid S3 credential fields", ERROR_INVALID_PARAMETER);
    }
    void save(const Connection& connection) const {
        validate(); auto target = connection.credential_target(); auto user = utf16(access);
        std::string blob = secret + "\n" + token;
        CREDENTIALW credential{}; credential.Type = CRED_TYPE_GENERIC;
        credential.TargetName = target.data(); credential.UserName = user.data();
        credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
        credential.CredentialBlobSize = static_cast<DWORD>(blob.size());
        credential.CredentialBlob = reinterpret_cast<BYTE*>(blob.data());
        BOOL ok = CredWriteW(&credential, 0); DWORD error = GetLastError();
        SecureZeroMemory(blob.data(), blob.size());
        if (!ok) throw writ::Error("Save credentials in Windows Credential Manager", error);
    }
    static Credentials load(const Connection& connection) {
        PCREDENTIALW credential = nullptr;
        writ::check(CredReadW(connection.credential_target().c_str(), CRED_TYPE_GENERIC, 0, &credential), "Read credentials from Windows Credential Manager");
        if (!credential->UserName || credential->CredentialBlobSize > CRED_MAX_CREDENTIAL_BLOB_SIZE) {
            CredFree(credential); throw writ::Error("Invalid stored credentials", ERROR_INVALID_DATA);
        }
        std::string access = utf8(credential->UserName);
        std::string blob(reinterpret_cast<char*>(credential->CredentialBlob), credential->CredentialBlobSize);
        SecureZeroMemory(credential->CredentialBlob, credential->CredentialBlobSize); CredFree(credential);
        auto newline = blob.find('\n');
        if (newline == std::string::npos) { SecureZeroMemory(blob.data(), blob.size()); throw writ::Error("Invalid stored credentials", ERROR_INVALID_DATA); }
        std::string secret = blob.substr(0, newline), token = blob.substr(newline + 1);
        SecureZeroMemory(blob.data(), blob.size());
        return Credentials(std::move(access), std::move(secret), std::move(token));
    }
};
} // namespace writ_sync
