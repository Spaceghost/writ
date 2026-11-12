// Windows process launch only; the same Bend/Node application serves both OSes.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <string>

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR arguments, int) {
    std::wstring option = arguments ? arguments : L"";
    if (!option.empty() && option != L"--stop" && option != L"--no-open") return 2;
    wchar_t path[32768]; DWORD length = GetModuleFileNameW(nullptr, path, 32768);
    if (!length || length >= 32768) return 2;
    std::wstring directory(path, length); directory.resize(directory.find_last_of(L"\\/"));
    auto node = directory + L"\\node.exe", app = directory + L"\\drive\\app.mjs";
    std::wstring command = L"\"" + node + L"\" \"" + app + L"\" " + option;
    STARTUPINFOW start{}; start.cb = sizeof(start);
    start.dwFlags = STARTF_USESHOWWINDOW; start.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION process{};
    if (!CreateProcessW(node.c_str(), command.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW,
        nullptr, directory.c_str(), &start, &process)) {
        MessageBoxW(nullptr, L"Writ could not start. Extract the complete portable package or reinstall Writ.", L"Writ", MB_ICONERROR);
        return 1;
    }
    CloseHandle(process.hThread);
    // Stop is used by uninstallers and must wait for graceful completion.
    DWORD result = 0;
    if (option == L"--stop") {
        if (WaitForSingleObject(process.hProcess, 150000) != WAIT_OBJECT_0 || !GetExitCodeProcess(process.hProcess, &result)) result = 1;
    }
    CloseHandle(process.hProcess); return static_cast<int>(result);
}
