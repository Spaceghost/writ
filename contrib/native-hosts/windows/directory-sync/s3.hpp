#pragma once
#include "connection.hpp"
#include <winhttp.h>
#include <map>

namespace writ_sync {
struct HttpHandle {
    HINTERNET value = nullptr;
    explicit HttpHandle(HINTERNET h) : value(h) { writ::check(h != nullptr, "S3 HTTP handle"); }
    ~HttpHandle() { if (value) WinHttpCloseHandle(value); }
    HttpHandle(const HttpHandle&) = delete;
    HttpHandle& operator=(const HttpHandle&) = delete;
};
inline Bytes hmac(const Bytes& key, const std::string& data) {
    BCRYPT_ALG_HANDLE algorithm = nullptr; BCRYPT_HASH_HANDLE hash = nullptr;
    NTSTATUS result = BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, BCRYPT_ALG_HANDLE_HMAC_FLAG);
    if (result < 0) throw writ::Error("SHA-256 HMAC provider", static_cast<DWORD>(result));
    result = BCryptCreateHash(algorithm, &hash, nullptr, 0, const_cast<PUCHAR>(key.data()), static_cast<ULONG>(key.size()), 0);
    Bytes digest(32);
    if (result >= 0) result = BCryptHashData(hash, reinterpret_cast<PUCHAR>(const_cast<char*>(data.data())), static_cast<ULONG>(data.size()), 0);
    if (result >= 0) result = BCryptFinishHash(hash, digest.data(), static_cast<ULONG>(digest.size()), 0);
    if (hash) BCryptDestroyHash(hash); BCryptCloseAlgorithmProvider(algorithm, 0);
    if (result < 0) throw writ::Error("SHA-256 HMAC", static_cast<DWORD>(result));
    return digest;
}
inline std::string uri(const std::string& path) {
    constexpr char digits[] = "0123456789ABCDEF";
    std::string result;
    for (unsigned char c : path) {
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
            c == '-' || c == '_' || c == '.' || c == '~' || c == '/') result += static_cast<char>(c);
        else { result += '%'; result += digits[c >> 4]; result += digits[c & 15]; }
    }
    return result;
}
inline std::string authorization(const Credentials& credentials, const std::string& region,
    const std::string& method, const std::string& resource, const std::string& timestamp,
    const std::string& payload, const std::map<std::string, std::string>& headers) {
    credentials.validate();
    std::string canonical_headers, signed_headers;
    for (const auto& [name, value] : headers) {
        if (!signed_headers.empty()) signed_headers += ';'; signed_headers += name;
        canonical_headers += name + ":" + value + "\n";
    }
    std::string canonical = method + "\n" + resource + "\n\n" + canonical_headers + "\n" + signed_headers + "\n" + payload;
    std::string date = timestamp.substr(0, 8), scope = date + "/" + region + "/s3/aws4_request";
    std::string to_sign = "AWS4-HMAC-SHA256\n" + timestamp + "\n" + scope + "\n" + writ::digest(canonical.data(), canonical.size());
    Bytes key{'A','W','S','4'}; key.insert(key.end(), credentials.secret.begin(), credentials.secret.end());
    for (const auto& part : {date, region, std::string("s3"), std::string("aws4_request")}) {
        auto next = hmac(key, part); SecureZeroMemory(key.data(), key.size()); key = std::move(next);
    }
    auto signature = hmac(key, to_sign); SecureZeroMemory(key.data(), key.size());
    return "AWS4-HMAC-SHA256 Credential=" + credentials.access + "/" + scope +
        ", SignedHeaders=" + signed_headers + ", Signature=" + writ::hex(signature.data(), signature.size());
}
struct HttpResult { DWORD status = 0; std::string etag; Bytes body; DWORD bytes = 0; };
class S3 {
    Connection config;
    Credentials credentials;
    std::wstring host;
    INTERNET_PORT port = 0;
    std::string authority;
    HttpHandle session;
    static std::string header(HINTERNET request, const wchar_t* name) {
        wchar_t value[256]; DWORD size = sizeof(value);
        if (!WinHttpQueryHeaders(request, WINHTTP_QUERY_CUSTOM, name, value, &size, WINHTTP_NO_HEADER_INDEX)) {
            if (GetLastError() == ERROR_WINHTTP_HEADER_NOT_FOUND) return {};
            throw writ::Error("Bounded S3 response header", GetLastError());
        }
        return utf8(std::wstring(value, size / sizeof(wchar_t)));
    }
public:
    explicit S3(Connection connection) : config(std::move(connection)), credentials(Credentials::load(config)),
        session(WinHttpOpen(L"Writ/0.1", WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0)) {
        config.validate(); credentials.validate();
        auto endpoint = utf16(config.endpoint);
        URL_COMPONENTS parts{}; parts.dwStructSize = sizeof(parts);
        parts.dwHostNameLength = parts.dwUrlPathLength = parts.dwExtraInfoLength = parts.dwUserNameLength = parts.dwPasswordLength = static_cast<DWORD>(-1);
        writ::check(WinHttpCrackUrl(endpoint.c_str(), static_cast<DWORD>(endpoint.size()), 0, &parts), "Parse S3 endpoint");
        if (parts.nScheme != INTERNET_SCHEME_HTTPS || !parts.dwHostNameLength || parts.dwUserNameLength || parts.dwPasswordLength ||
            parts.dwExtraInfoLength || (parts.dwUrlPathLength && std::wstring(parts.lpszUrlPath, parts.dwUrlPathLength) != L"/"))
            throw writ::Error("Use an HTTPS S3 endpoint without a path or embedded credentials", ERROR_INVALID_PARAMETER);
        host.assign(parts.lpszHostName, parts.dwHostNameLength); port = parts.nPort;
        CharLowerBuffW(host.data(), static_cast<DWORD>(host.size())); authority = utf8(host);
        if (port != INTERNET_DEFAULT_HTTPS_PORT) authority += ":" + std::to_string(port);
        writ::check(WinHttpSetTimeouts(session.value, 5000, 10000, 20000, 20000), "S3 timeouts");
        DWORD protocols = WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2;
        writ::check(WinHttpSetOption(session.value, WINHTTP_OPTION_SECURE_PROTOCOLS, &protocols, sizeof(protocols)), "S3 TLS protocol");
    }
    HttpResult request(const char* method, const std::string& key, const Bytes& body = {},
        HANDLE upload = INVALID_HANDLE_VALUE, DWORD upload_size = 0, const std::string& upload_hash = "",
        const std::string& condition = "", bool create_only = false,
        HANDLE download = INVALID_HANDLE_VALUE, DWORD maximum = 4 * 1024 * 1024) {
        if (key.size() > 1024 || key.empty() || key.front() == '/' || maximum > 1073741824)
            throw writ::Error("S3 request bound", ERROR_INVALID_PARAMETER);
        auto resource = uri("/" + config.bucket + "/" + config.prefix + "/" + key);
        SYSTEMTIME now; GetSystemTime(&now); char timestamp[32];
        sprintf_s(timestamp, "%04u%02u%02uT%02u%02u%02uZ", now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond);
        bool file_body = upload != INVALID_HANDLE_VALUE;
        DWORD size = file_body ? upload_size : static_cast<DWORD>(body.size());
        std::string payload = file_body ? upload_hash : writ::digest(body.data(), body.size());
        if (payload.size() != 64 || !std::all_of(payload.begin(), payload.end(), [](char c) { return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'); }))
            throw writ::Error("S3 payload digest", ERROR_INVALID_PARAMETER);
        std::map<std::string, std::string> headers{{"host", authority}, {"x-amz-content-sha256", payload}, {"x-amz-date", timestamp}};
        if (!credentials.token.empty()) headers["x-amz-security-token"] = credentials.token;
        if (create_only) headers["if-none-match"] = "*";
        if (!condition.empty()) {
            if (condition.size() < 3 || condition.size() > 128 || condition.front() != '"' || condition.back() != '"' ||
                !std::all_of(condition.begin() + 1, condition.end() - 1, [](unsigned char c) { return c >= 33 && c <= 126 && c != '"'; }))
                throw writ::Error("S3 requires one exact strong ETag", ERROR_INVALID_DATA);
            headers[std::string(method) == "GET" ? "if-none-match" : "if-match"] = condition;
        }
        std::string signed_header = authorization(credentials, config.region, method, resource, timestamp, payload, headers);
        HttpHandle connection(WinHttpConnect(session.value, host.c_str(), port, 0));
        auto verb = utf16(method), path = utf16(resource);
        HttpHandle request(WinHttpOpenRequest(connection.value, verb.c_str(), path.c_str(), nullptr,
            WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, WINHTTP_FLAG_SECURE | WINHTTP_FLAG_ESCAPE_DISABLE));
        DWORD redirect = WINHTTP_OPTION_REDIRECT_POLICY_NEVER, disable = WINHTTP_DISABLE_COOKIES, auth = WINHTTP_AUTOLOGON_SECURITY_LEVEL_HIGH;
        writ::check(WinHttpSetOption(request.value, WINHTTP_OPTION_REDIRECT_POLICY, &redirect, sizeof(redirect)), "Disable S3 redirects");
        writ::check(WinHttpSetOption(request.value, WINHTTP_OPTION_DISABLE_FEATURE, &disable, sizeof(disable)), "Disable S3 cookies");
        writ::check(WinHttpSetOption(request.value, WINHTTP_OPTION_AUTOLOGON_POLICY, &auth, sizeof(auth)), "Disable automatic Windows authentication");
        std::string fields = "Authorization: " + signed_header + "\r\n";
        for (const auto& [name, value] : headers) fields += name + ": " + value + "\r\n";
        auto wide_headers = utf16(fields);
        BOOL sent = WinHttpSendRequest(request.value, wide_headers.c_str(), static_cast<DWORD>(wide_headers.size()),
            WINHTTP_NO_REQUEST_DATA, 0, size, 0);
        DWORD send_error = GetLastError();
        SecureZeroMemory(fields.data(), fields.size()); SecureZeroMemory(wide_headers.data(), wide_headers.size() * sizeof(wchar_t));
        if (!sent) throw writ::Error("Send S3 request", send_error);
        std::array<unsigned char, 65536> block{}; DWORD offset = 0;
        if (file_body) { LARGE_INTEGER start{}; writ::check(SetFilePointerEx(upload, start, nullptr, FILE_BEGIN), "Rewind upload snapshot"); }
        while (offset < size) {
            DWORD count = std::min<DWORD>(size - offset, static_cast<DWORD>(block.size())), wrote = 0;
            if (file_body) {
                DWORD read = 0; writ::check(ReadFile(upload, block.data(), count, &read, nullptr) && read == count, "Read upload snapshot");
            } else memcpy(block.data(), body.data() + offset, count);
            writ::check(WinHttpWriteData(request.value, block.data(), count, &wrote) && wrote == count, "Upload S3 bytes");
            offset += count;
        }
        writ::check(WinHttpReceiveResponse(request.value, nullptr), "Receive S3 response");
        HttpResult result; DWORD status_size = sizeof(result.status);
        writ::check(WinHttpQueryHeaders(request.value, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
            WINHTTP_HEADER_NAME_BY_INDEX, &result.status, &status_size, WINHTTP_NO_HEADER_INDEX), "S3 status");
        result.etag = header(request.value, L"ETag");
        bool to_file = download != INVALID_HANDLE_VALUE && result.status == 200;
        DWORD bound = result.status >= 300 ? 65536 : maximum;
        for (;;) {
            DWORD got = 0;
            writ::check(WinHttpReadData(request.value, block.data(), static_cast<DWORD>(block.size()), &got), "Read S3 response");
            if (!got) break;
            if (got > bound - result.bytes) throw writ::Error("S3 response exceeds expected size", ERROR_FILE_TOO_LARGE);
            if (to_file) { DWORD wrote = 0; writ::check(WriteFile(download, block.data(), got, &wrote, nullptr) && wrote == got, "Write download snapshot"); }
            else if (result.status < 300) result.body.insert(result.body.end(), block.begin(), block.begin() + got);
            result.bytes += got;
        }
        return result;
    }
};
} // namespace writ_sync
