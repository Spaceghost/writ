// Native OS exclusion tests only; no policy or alternate provider path.
#include "directory.hpp"
#include <thread>

using namespace writ_sync;
static void require(bool condition, const char* name) {
    if (!condition) throw writ::Error(name, ERROR_INVALID_DATA);
    std::cout << "PASS: " << name << std::endl;
}
static std::string read(const fs::path& path) {
    auto file = frozen(path); auto bytes = writ::read_bytes(file); return std::string(bytes.begin(), bytes.end());
}
int wmain(int argc, wchar_t** argv) {
    try {
        if (argc != 2) throw writ::Error("Pass a new disposable directory", ERROR_INVALID_PARAMETER);
        auto root = writ::canonical(argv[1]); writ::local_user_path(root);
        require(!fs::exists(root), "probe owns a fresh directory"); writ::private_directory(root);
        Parents parents(root);
        auto target = root / L"original.txt", recovery = root / L"recovery.txt", staged = root / L"verified.txt";
        writ::durable_file(target, "original", 8); writ::durable_file(staged, "verified", 8);
        auto retained = frozen(target, true);
        DWORD write_error = 0, rename_error = 0;
        std::thread contender([&] {
            HANDLE writer = CreateFileW(target.c_str(), GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                nullptr, OPEN_EXISTING, 0, nullptr);
            if (writer == INVALID_HANDLE_VALUE) write_error = GetLastError(); else CloseHandle(writer);
            if (!MoveFileExW(target.c_str(), (root / L"renamed.txt").c_str(), 0)) rename_error = GetLastError();
        }); contender.join();
        require(write_error == ERROR_SHARING_VIOLATION, "retained target excludes a competing writer");
        require(rename_error == ERROR_SHARING_VIOLATION, "retained target excludes a competing rename");
        move_retained(retained, recovery);
        writ::durable_file(target, "new-user", 8);
        BOOL installed = MoveFileExW(staged.c_str(), target.c_str(), MOVEFILE_WRITE_THROUGH);
        require(!installed && (GetLastError() == ERROR_ALREADY_EXISTS || GetLastError() == ERROR_FILE_EXISTS), "newly recreated destination cannot be overwritten");
        require(read(target) == "new-user", "recreated destination bytes survive");
        require(writ::read_bytes(retained) == Bytes({'o','r','i','g','i','n','a','l'}), "exact displaced bytes remain in retained recovery handle");
        require(read(staged) == "verified", "failed installation retains verified download");
        bool denied = false;
        try { relative_path("notes/../escape"); } catch (const writ::Error&) { denied = true; }
        require(denied, "native parent path escape rejected");
        denied = false;
        try { relative_path("notes/CON.txt"); } catch (const writ::Error&) { denied = true; }
        require(denied, "native reserved filename rejected");
        require(namespace_key(relative_path("Notes/File.txt")) == namespace_key(relative_path("notes/file.TXT")), "Windows case variants share a namespace identity");
        std::cout << "PASS: native directory exclusion probes complete\n"; return 0;
    } catch (const std::exception& error) { std::cerr << "FAIL: " << error.what() << '\n'; return 1; }
}
