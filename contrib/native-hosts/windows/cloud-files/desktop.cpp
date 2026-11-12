// Windows presentation and owned process lifetime only. Save/version/conflict
// decisions stay in the existing provider's Bend monitor.
#include "native.hpp"
#include <commctrl.h>
#include <windowsx.h>
#include <shellapi.h>
#include <fstream>
#include <deque>

#ifndef WRIT_VERSION
#define WRIT_VERSION "development"
#define WRIT_SOURCE_COMMIT "unknown"
#endif

namespace desktop {
namespace fs = std::filesystem;
constexpr wchar_t window_class[] = L"WritDesktop.7DDDA5C1";
constexpr wchar_t flyout_class[] = L"WritFlyout.7DDDA5C1";
constexpr wchar_t mutex_name[] = L"Local\\WritDesktop.7DDDA5C1";
constexpr wchar_t quit_name[] = L"Local\\WritDesktopQuit.7DDDA5C1";
constexpr wchar_t run_key[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr UINT tray_message = WM_APP + 1, activate_message = WM_APP + 2;
constexpr UINT open_app = 101, open_folder = 102, pause_resume = 103,
    settings = 104, quit = 105, startup = 106, recovery = 107,
    diagnostics = 108, releases = 109, tabs_id = 110;
constexpr GUID tray_guid{0x7ddda5c1, 0x3eb0, 0x4f92, {0xac,0xa4,0x91,0x6b,0x35,0x91,0x20,0x04}};

struct Handle {
    HANDLE value = nullptr;
    Handle() = default;
    explicit Handle(HANDLE h) : value(h) {}
    Handle(const Handle&) = delete;
    Handle& operator=(const Handle&) = delete;
    ~Handle() { reset(); }
    void reset(HANDLE h = nullptr) {
        if (value && value != INVALID_HANDLE_VALUE) CloseHandle(value);
        value = h;
    }
    bool valid() const { return value && value != INVALID_HANDLE_VALUE; }
};

static std::wstring wide(const std::string& text) {
    if (text.empty()) return {};
    int size = MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0);
    std::wstring result(static_cast<size_t>(size), L' ');
    MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), result.data(), size);
    return result;
}
static fs::path executable() {
    wchar_t path[32768];
    DWORD n = GetModuleFileNameW(nullptr, path, 32768);
    writ::check(n && n < 32768, "application path");
    return fs::path(path);
}
static fs::path user_path(int folder, const wchar_t* suffix) {
    wchar_t path[MAX_PATH];
    writ::hr(SHGetFolderPathW(nullptr, folder, nullptr, SHGFP_TYPE_CURRENT, path), "user folder");
    return fs::path(path) / suffix;
}
static std::wstring startup_command() { return L"\"" + executable().wstring() + L"\" --background"; }
static bool starts_with_windows() {
    wchar_t data[32768]; DWORD bytes = sizeof(data);
    return RegGetValueW(HKEY_CURRENT_USER, run_key, L"Writ", RRF_RT_REG_SZ, nullptr, data, &bytes) == ERROR_SUCCESS &&
        std::wstring(data) == startup_command();
}
static void set_startup(bool enabled) {
    HKEY key = nullptr;
    LSTATUS result = RegCreateKeyExW(HKEY_CURRENT_USER, run_key, 0, nullptr, 0, KEY_QUERY_VALUE | KEY_SET_VALUE, nullptr, &key, nullptr);
    if (result != ERROR_SUCCESS) throw writ::Error("open sign-in preference", result);
    auto command = startup_command();
    // An old installation's uninstaller must not remove a newer app's entry.
    if (enabled) result = RegSetValueExW(key, L"Writ", 0, REG_SZ,
        reinterpret_cast<const BYTE*>(command.c_str()), static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
    else if (starts_with_windows()) result = RegDeleteValueW(key, L"Writ");
    RegCloseKey(key);
    if (result != ERROR_SUCCESS && result != ERROR_FILE_NOT_FOUND) throw writ::Error("save sign-in preference", result);
}

// Only the fixed packaged provider commands can be invoked. All inheritable
// handles are explicitly allowlisted, including a harmless NUL stdin.
static void launch(const fs::path& file, const wchar_t* arguments, Handle& process,
                   Handle* read_pipe = nullptr, HANDLE job = nullptr) {
    SECURITY_ATTRIBUTES attributes{sizeof(attributes), nullptr, TRUE};
    Handle output, input(CreateFileW(L"NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
        &attributes, OPEN_EXISTING, 0, nullptr));
    writ::check(input.valid(), "child stdin");
    if (read_pipe) {
        HANDLE read = nullptr, write = nullptr;
        writ::check(CreatePipe(&read, &write, &attributes, 0), "provider output pipe");
        read_pipe->reset(read); output.reset(write);
        writ::check(SetHandleInformation(read, HANDLE_FLAG_INHERIT, 0), "private output reader");
    } else output.reset(CreateFileW(L"NUL", GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
        &attributes, OPEN_EXISTING, 0, nullptr));
    writ::check(output.valid(), "child stdout");
    SIZE_T size = 0;
    InitializeProcThreadAttributeList(nullptr, 1, 0, &size);
    std::vector<unsigned char> storage(size);
    auto list = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(storage.data());
    writ::check(InitializeProcThreadAttributeList(list, 1, 0, &size), "child attributes");
    HANDLE inherited[] = {input.value, output.value};
    if (!UpdateProcThreadAttribute(list, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, inherited, sizeof(inherited), nullptr, nullptr)) {
        DWORD error = GetLastError(); DeleteProcThreadAttributeList(list);
        throw writ::Error("child handle list", error);
    }
    STARTUPINFOEXW start{}; start.StartupInfo.cb = sizeof(start);
    start.StartupInfo.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
    start.StartupInfo.wShowWindow = SW_HIDE;
    start.StartupInfo.hStdInput = input.value;
    start.StartupInfo.hStdOutput = start.StartupInfo.hStdError = output.value;
    start.lpAttributeList = list;
    PROCESS_INFORMATION child{};
    std::wstring command = L"\"" + file.wstring() + L"\" " + arguments;
    BOOL ok = CreateProcessW(file.c_str(), command.data(), nullptr, nullptr, TRUE,
        CREATE_NO_WINDOW | CREATE_SUSPENDED | EXTENDED_STARTUPINFO_PRESENT, nullptr,
        file.parent_path().c_str(), &start.StartupInfo, &child);
    DWORD error = GetLastError(); DeleteProcThreadAttributeList(list);
    if (!ok) throw writ::Error("start packaged provider", error);
    process.reset(child.hProcess); Handle thread(child.hThread);
    if ((job && !AssignProcessToJobObject(job, process.value)) || ResumeThread(thread.value) == static_cast<DWORD>(-1)) {
        error = GetLastError(); TerminateProcess(process.value, error);
        WaitForSingleObject(process.value, 5000); process.reset();
        throw writ::Error("own provider process", error);
    }
}

struct Activity { std::wstring time, text; };
class App {
    HINSTANCE instance;
    HWND main = nullptr, flyout = nullptr, tab = nullptr, list = nullptr,
        status_label = nullptr, detail_label = nullptr, pause_button = nullptr,
        fly_status = nullptr, fly_detail = nullptr, fly_pause = nullptr;
    std::vector<HWND> setting_controls;
    HFONT normal = nullptr, heading = nullptr, brand = nullptr;
    HICON icon = nullptr;
    UINT dpi = 96, taskbar_created = 0;
    bool tray_added = false, ready = false, stopping = false, quitting = false,
        attention = false, paused = false, settings_open = false, discard_line = false;
    ULONGLONG stop_started = 0, last_stop = 0;
    Handle provider, output, stop_process, job, quit_event;
    std::string pending;
    std::deque<Activity> activity;
    std::wstring status = L"Starting Writ", detail = L"Connecting to your local Writ folder.";
    fs::path root, data, log_path, recovery_path;

    int px(int n) const { return MulDiv(n, static_cast<int>(dpi), 96); }
    HWND control(const wchar_t* type, const wchar_t* text, DWORD style, int id, HWND parent = nullptr) {
        HWND h = CreateWindowExW(0, type, text, WS_CHILD | WS_VISIBLE | style, 0, 0, 1, 1,
            parent ? parent : main, reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)), instance, nullptr);
        writ::check(h != nullptr, "create desktop control");
        SendMessageW(h, WM_SETFONT, reinterpret_cast<WPARAM>(normal), TRUE);
        return h;
    }
    void move(HWND h, int x, int y, int w, int height) { MoveWindow(h, px(x), px(y), px(w), px(height), TRUE); }
    void fonts() {
        HFONT old_normal = normal, old_heading = heading, old_brand = brand;
        normal = CreateFontW(-px(14), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
            OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
        heading = CreateFontW(-px(23), 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
            OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
        brand = CreateFontW(-px(30), 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
            OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
        if (main) {
            EnumChildWindows(main, [](HWND h, LPARAM font) -> BOOL { SendMessageW(h, WM_SETFONT, font, TRUE); return TRUE; }, reinterpret_cast<LPARAM>(normal));
            SendMessageW(GetDlgItem(main, 201), WM_SETFONT, reinterpret_cast<WPARAM>(brand), TRUE);
            SendMessageW(status_label, WM_SETFONT, reinterpret_cast<WPARAM>(heading), TRUE);
        }
        if (flyout) EnumChildWindows(flyout, [](HWND h, LPARAM font) -> BOOL { SendMessageW(h, WM_SETFONT, font, TRUE); return TRUE; }, reinterpret_cast<LPARAM>(normal));
        if (old_normal) DeleteObject(old_normal);
        if (old_heading) DeleteObject(old_heading);
        if (old_brand) DeleteObject(old_brand);
    }
    void make_icon() {
        // Authored W monogram, rendered directly into an alpha DIB. No font or
        // downloaded bitmap is needed, and the states also have text labels.
        constexpr int size = 32;
        BITMAPV5HEADER bitmap{}; bitmap.bV5Size = sizeof(bitmap);
        bitmap.bV5Width = size; bitmap.bV5Height = -size; bitmap.bV5Planes = 1;
        bitmap.bV5BitCount = 32; bitmap.bV5Compression = BI_BITFIELDS;
        bitmap.bV5RedMask = 0x00ff0000; bitmap.bV5GreenMask = 0x0000ff00;
        bitmap.bV5BlueMask = 0x000000ff; bitmap.bV5AlphaMask = 0xff000000;
        void* bits = nullptr;
        HBITMAP color = CreateDIBSection(nullptr, reinterpret_cast<BITMAPINFO*>(&bitmap), DIB_RGB_COLORS, &bits, nullptr, 0);
        writ::check(color && bits, "tray icon bitmap");
        auto pixels = static_cast<DWORD*>(bits);
        DWORD fill = attention ? 0xffb43b32 : stopping || paused ? 0xff976500 : ready ? 0xff315c43 : 0xff426b8c;
        const int points[][2] = {{7,9},{11,23},{16,14},{21,23},{25,9}};
        for (int y = 0; y < size; ++y) for (int x = 0; x < size; ++x) {
            bool inside = (x - 16)*(x - 16) + (y - 16)*(y - 16) <= 225;
            DWORD pixel = inside ? fill : 0;
            for (int segment = 0; segment < 4 && inside; ++segment) {
                double dx = points[segment+1][0] - points[segment][0], dy = points[segment+1][1] - points[segment][1];
                double t = std::clamp(((x - points[segment][0])*dx + (y - points[segment][1])*dy)/(dx*dx+dy*dy), 0.0, 1.0);
                double a = x - points[segment][0] - t*dx, b = y - points[segment][1] - t*dy;
                if (a*a+b*b < 2.3) pixel = 0xfffcfcf8;
            }
            pixels[y*size+x] = pixel;
        }
        unsigned char mask_bits[128]{};
        HBITMAP mask = CreateBitmap(size, size, 1, 1, mask_bits);
        ICONINFO info{}; info.fIcon = TRUE; info.hbmColor = color; info.hbmMask = mask;
        HICON next = CreateIconIndirect(&info); DeleteObject(color); DeleteObject(mask);
        writ::check(next != nullptr, "tray icon");
        HICON previous = icon; icon = next;
        SendMessageW(main, WM_SETICON, ICON_SMALL, reinterpret_cast<LPARAM>(icon));
        SendMessageW(main, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(icon));
        notify(false);
        if (previous) DestroyIcon(previous);
    }
    void notify(bool add) {
        NOTIFYICONDATAW item{}; item.cbSize = sizeof(item); item.hWnd = main;
        item.uID = 1; item.guidItem = tray_guid;
        item.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_GUID | NIF_SHOWTIP;
        item.hIcon = icon; item.uCallbackMessage = tray_message;
        std::wstring tip = L"Writ — " + status;
        wcsncpy_s(item.szTip, tip.c_str(), _TRUNCATE);
        if (add || !tray_added) {
            tray_added = Shell_NotifyIconW(NIM_ADD, &item) != FALSE;
            if (tray_added) { item.uVersion = NOTIFYICON_VERSION_4; Shell_NotifyIconW(NIM_SETVERSION, &item); log("DESKTOP_TRAY_ADDED"); }
        } else if (!Shell_NotifyIconW(NIM_MODIFY, &item)) tray_added = false;
    }
    void update() {
        SetWindowTextW(status_label, status.c_str()); SetWindowTextW(detail_label, detail.c_str());
        SetWindowTextW(pause_button, provider.valid() ? L"&Pause syncing" : L"&Resume syncing");
        EnableWindow(pause_button, !stopping && (!provider.valid() || ready));
        if (flyout) {
            SetWindowTextW(fly_status, status.c_str()); SetWindowTextW(fly_detail, detail.c_str());
            SetWindowTextW(fly_pause, provider.valid() ? L"&Pause syncing" : L"&Resume syncing");
            EnableWindow(fly_pause, !stopping && (!provider.valid() || ready));
        }
        make_icon();
    }
    void record(const std::wstring& text) {
        SYSTEMTIME now; GetLocalTime(&now);
        wchar_t time[20]; swprintf_s(time, L"%02u:%02u:%02u", now.wHour, now.wMinute, now.wSecond);
        activity.push_front({time, text.substr(0, 1024)});
        if (activity.size() > 100) activity.pop_back();
        LVITEMW item{}; item.mask = LVIF_TEXT; item.iItem = 0;
        item.pszText = const_cast<wchar_t*>(activity.front().time.c_str());
        ListView_InsertItem(list, &item);
        ListView_SetItemText(list, 0, 1, const_cast<wchar_t*>(activity.front().text.c_str()));
        if (ListView_GetItemCount(list) > 100) ListView_DeleteItem(list, 100);
    }
    void log(const std::string& line) {
        // Diagnostics are bounded to two 512 KiB files. Failure to write a log
        // never changes or masks a provider save decision.
        std::error_code error;
        if (fs::exists(log_path, error) && fs::file_size(log_path, error) > 512 * 1024) {
            auto previous = log_path; previous += L".previous";
            fs::remove(previous, error);
            fs::rename(log_path, previous, error);
        }
        std::ofstream stream(log_path, std::ios::app | std::ios::binary);
        stream << line << '\n';
    }
    void event(const std::string& line) {
        if (line.empty()) return;
        log(line);
        if (line.rfind("READY ", 0) == 0) {
            ready = true; attention = false;
            if (!stopping) { status = L"Watching hello.txt"; detail = L"Writ is running. Open your folder to try the public preview."; }
            record(L"Connected to the local backing store");
        } else if (line.rfind("COMMIT ", 0) == 0) {
            attention = false;
            if (!stopping) { status = L"Watching hello.txt"; detail = L"Last save confirmed in the local backing store."; }
            record(L"hello.txt — save confirmed · " + wide(line.substr(7, line.find(" sha256=") - 7)));
        } else if (line.rfind("FETCH bytes=", 0) == 0) record(L"hello.txt — opened from local storage");
        else if (line.rfind("RECOVERY ", 0) == 0) record(L"Recovery copy retained before save");
        else if (line.rfind("WRITEBACK_FAILED ", 0) == 0 || line.rfind("FETCH_FAILED ", 0) == 0 || line.rfind("DEFERRED ", 0) == 0) {
            attention = true;
            if (!stopping) { status = L"Needs attention"; detail = L"An operation could not finish. Review activity; your local edits are retained."; }
            record(wide(line));
        } else if (line == "STOPPED") record(L"Provider disconnected; local edits stay on this device");
        else if (line.rfind("SEEDED ", 0) != 0 && line != "FETCH_REQUEST" && line.rfind("Writ public preview:", 0) != 0 && line.rfind("Keep this window", 0) != 0)
            record(wide(line));
        update();
    }
    void read_events() {
        if (!output.valid()) return;
        for (DWORD total = 0; total < 65536;) {
            DWORD available = 0;
            if (!PeekNamedPipe(output.value, nullptr, 0, nullptr, &available, nullptr) || !available) break;
            char buffer[4096]; DWORD got = 0;
            if (!ReadFile(output.value, buffer, std::min<DWORD>(available, sizeof(buffer)), &got, nullptr) || !got) break;
            total += got;
            for (DWORD i = 0; i < got; ++i) {
                char c = buffer[i];
                if (c == '\n') {
                    if (!discard_line) event(pending);
                    else { record(L"Oversized diagnostic line omitted"); log("Oversized diagnostic line omitted"); }
                    pending.clear(); discard_line = false;
                } else if (c != '\r' && !discard_line) {
                    if (pending.size() < 4096) pending += c;
                    else { pending.clear(); discard_line = true; }
                }
            }
        }
    }
    void start() {
        if (provider.valid()) return;
        pending.clear(); discard_line = false; ready = stopping = attention = paused = false;
        status = L"Starting Writ"; detail = L"Connecting to your local Writ folder."; update();
        launch(executable().parent_path() / L"writ-cloud.exe", L"start", provider, &output, job.value);
        record(L"Starting the public Files On-Demand provider");
    }
    void request_stop(bool exit) {
        quitting = quitting || exit;
        if (!provider.valid()) { if (quitting) DestroyWindow(main); return; }
        if (!stopping) { stopping = true; stop_started = GetTickCount64(); last_stop = 0; }
        status = quitting ? L"Closing Writ" : L"Pausing sync";
        detail = L"Waiting for the provider to disconnect. This does not flush pending edits.";
        update();
    }
    void tick() {
        if (WaitForSingleObject(quit_event.value, 0) == WAIT_OBJECT_0) {
            ResetEvent(quit_event.value); request_stop(true);
            if (!IsWindow(main)) return;
        }
        read_events();
        if (stop_process.valid() && WaitForSingleObject(stop_process.value, 0) == WAIT_OBJECT_0) stop_process.reset();
        if (provider.valid() && WaitForSingleObject(provider.value, 0) == WAIT_OBJECT_0) {
            read_events();
            if (!pending.empty() && !discard_line) event(pending);
            pending.clear();
            DWORD code = 1; GetExitCodeProcess(provider.value, &code);
            provider.reset(); output.reset(); ready = false;
            bool requested = stopping; stopping = false; paused = requested && code == 0;
            if (quitting && code == 0) { DestroyWindow(main); return; }
            quitting = false;
            if (code != 0) {
                attention = true; status = L"Provider stopped with an error";
                detail = L"Review activity and diagnostics, then retry Resume syncing. Another provider may already be running.";
                record(L"Provider exited with code " + std::to_wstring(code));
                show(false);
            } else {
                status = paused ? L"Syncing paused" : L"Provider stopped";
                detail = L"Edits stay on this device until resumed. Unopened files need Writ running.";
            }
            update();
        }
        if (stopping && provider.valid()) {
            auto now = GetTickCount64();
            if (now - stop_started >= 25000) {
                stopping = quitting = false; attention = true;
                status = L"Writ is still stopping";
                detail = L"The provider has not exited. Close editors and try again; files have not been removed.";
                record(L"Graceful stop timed out; provider retained"); show(false); update();
            } else if (!stop_process.valid() && now - last_stop >= 1000) {
                last_stop = now;
                launch(executable().parent_path() / L"writ-cloud.exe", L"stop", stop_process, nullptr, job.value);
            }
        }
    }
    void open_path(const fs::path& path) {
        if (!fs::exists(path)) { record(L"This folder is not available yet: " + path.wstring()); return; }
        auto result = reinterpret_cast<INT_PTR>(ShellExecuteW(main, L"open", path.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
        if (result <= 32) throw writ::Error("open local folder", static_cast<DWORD>(result));
    }
    void command(UINT id) {
        switch (id) {
        case open_app: show(false); break;
        case open_folder: open_path(root); break;
        case pause_resume: if (!stopping) { if (provider.valid()) request_stop(false); else start(); } break;
        case settings: show(true); break;
        case quit: request_stop(true); break;
        case startup:
            set_startup(SendMessageW(GetDlgItem(main, startup), BM_GETCHECK, 0, 0) == BST_CHECKED);
            record(starts_with_windows() ? L"Start at sign-in enabled" : L"Start at sign-in disabled"); break;
        case recovery: open_path(recovery_path); break;
        case diagnostics: open_path(log_path.parent_path()); break;
        case releases: ShellExecuteW(main, L"open", L"https://github.com/Spaceghost/writ/releases", nullptr, nullptr, SW_SHOWNORMAL); break;
        default: break;
        }
    }
    void layout() {
        RECT area; GetClientRect(main, &area);
        int width = MulDiv(area.right, 96, static_cast<int>(dpi)), height = MulDiv(area.bottom, 96, static_cast<int>(dpi));
        move(GetDlgItem(main, 201), 28, 16, 150, 48);
        move(GetDlgItem(main, 202), 180, 30, width - 208, 26);
        move(status_label, 28, 86, width - 56, 38);
        move(detail_label, 28, 132, width - 56, 48);
        move(GetDlgItem(main, open_folder), 28, 188, 150, 38);
        move(pause_button, 190, 188, 172, 38);
        move(GetDlgItem(main, quit), width - 144, 188, 116, 38);
        move(tab, 28, 250, width - 56, height - 346);
        move(list, 42, 292, width - 84, height - 404);
        ListView_SetColumnWidth(list, 0, px(95)); ListView_SetColumnWidth(list, 1, px(width - 205));
        move(GetDlgItem(main, startup), 48, 298, width - 96, 34);
        move(GetDlgItem(main, 210), 48, 340, width - 96, 38);
        move(GetDlgItem(main, recovery), 48, 392, 200, 36);
        move(GetDlgItem(main, diagnostics), 264, 392, 170, 36);
        move(GetDlgItem(main, releases), 48, 444, 200, 36);
        move(GetDlgItem(main, 211), 48, 494, width - 96, 62);
        move(GetDlgItem(main, 203), 28, height - 76, width - 56, 56);
        ShowWindow(list, settings_open ? SW_HIDE : SW_SHOW);
        for (HWND h : setting_controls) ShowWindow(h, settings_open ? SW_SHOW : SW_HIDE);
    }
    void show(bool preferences) {
        settings_open = preferences; TabCtrl_SetCurSel(tab, preferences ? 1 : 0); layout();
        ShowWindow(main, SW_RESTORE); SetForegroundWindow(main);
        SetFocus(preferences ? GetDlgItem(main, startup) : GetDlgItem(main, open_folder));
        if (flyout) ShowWindow(flyout, SW_HIDE);
    }
    void popup() {
        HMENU menu = CreatePopupMenu();
        AppendMenuW(menu, MF_STRING, open_app, L"Open &Writ");
        AppendMenuW(menu, MF_STRING, open_folder, L"Open &folder");
        AppendMenuW(menu, MF_STRING | (stopping || (provider.valid() && !ready) ? MF_GRAYED : 0), pause_resume,
            provider.valid() ? L"&Pause syncing" : L"&Resume syncing");
        AppendMenuW(menu, MF_STRING, settings, L"&Settings");
        AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(menu, MF_STRING, quit, L"&Quit Writ");
        POINT point; GetCursorPos(&point); SetForegroundWindow(main);
        UINT selected = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON, point.x, point.y, 0, main, nullptr);
        DestroyMenu(menu); PostMessageW(main, WM_NULL, 0, 0);
        if (selected) command(selected);
    }
    void show_flyout() {
        if (!flyout) {
            flyout = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_CONTROLPARENT, flyout_class, L"Writ activity", WS_POPUP | WS_BORDER | WS_CLIPCHILDREN,
                0, 0, px(390), px(310), main, nullptr, instance, this);
            writ::check(flyout != nullptr, "activity flyout");
            HWND title = control(L"STATIC", L"writ.  /  Public preview", SS_LEFT, 301, flyout);
            fly_status = control(L"STATIC", status.c_str(), SS_LEFT, 302, flyout);
            fly_detail = control(L"STATIC", detail.c_str(), SS_LEFT, 303, flyout);
            HWND folder = control(L"BUTTON", L"Open &folder", WS_TABSTOP, open_folder, flyout);
            fly_pause = control(L"BUTTON", L"&Pause syncing", WS_TABSTOP, pause_resume, flyout);
            HWND app = control(L"BUTTON", L"Open &Writ", WS_TABSTOP, open_app, flyout);
            HWND prefs = control(L"BUTTON", L"&Settings", WS_TABSTOP, settings, flyout);
            move(title, 20, 16, 350, 28); move(fly_status, 20, 58, 350, 30);
            move(fly_detail, 20, 96, 350, 76); move(folder, 20, 184, 164, 36);
            move(fly_pause, 202, 184, 164, 36); move(app, 20, 238, 164, 36); move(prefs, 202, 238, 164, 36);
        }
        NOTIFYICONIDENTIFIER identity{sizeof(identity), main, 1, tray_guid};
        RECT anchor{};
        if (FAILED(Shell_NotifyIconGetRect(&identity, &anchor))) { POINT p; GetCursorPos(&p); anchor = {p.x,p.y,p.x,p.y}; }
        MONITORINFO monitor{sizeof(monitor)};
        GetMonitorInfoW(MonitorFromRect(&anchor, MONITOR_DEFAULTTONEAREST), &monitor);
        int width = px(390), height = px(310);
        int x = static_cast<int>(std::clamp<LONG>(anchor.right - width, monitor.rcWork.left, std::max<LONG>(monitor.rcWork.left, monitor.rcWork.right - width)));
        int y = static_cast<int>(std::clamp<LONG>(anchor.top - height - px(8), monitor.rcWork.top, std::max<LONG>(monitor.rcWork.top, monitor.rcWork.bottom - height)));
        update(); SetWindowPos(flyout, HWND_TOPMOST, x, y, width, height, SWP_SHOWWINDOW);
        SetForegroundWindow(flyout); SetFocus(GetDlgItem(flyout, open_folder));
    }
    void create_controls() {
        control(L"STATIC", L"writ.", SS_LEFT, 201);
        control(L"STATIC", L"FILES ON DEMAND  /  PUBLIC PREVIEW", SS_RIGHT, 202);
        status_label = control(L"STATIC", status.c_str(), SS_LEFT, 204);
        detail_label = control(L"STATIC", detail.c_str(), SS_LEFT, 205);
        control(L"BUTTON", L"Open &folder", WS_TABSTOP, open_folder);
        pause_button = control(L"BUTTON", L"&Pause syncing", WS_TABSTOP, pause_resume);
        control(L"BUTTON", L"&Quit Writ", WS_TABSTOP, quit);
        tab = control(WC_TABCONTROLW, L"Activity and settings", WS_TABSTOP | WS_CLIPSIBLINGS, tabs_id);
        TCITEMW item{}; item.mask = TCIF_TEXT; item.pszText = const_cast<wchar_t*>(L"Activity"); TabCtrl_InsertItem(tab, 0, &item);
        item.pszText = const_cast<wchar_t*>(L"Settings"); TabCtrl_InsertItem(tab, 1, &item);
        list = control(WC_LISTVIEWW, L"Recent Writ activity", WS_TABSTOP | LVS_REPORT | LVS_SINGLESEL | LVS_NOSORTHEADER, 206);
        ListView_SetExtendedListViewStyle(list, LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER);
        LVCOLUMNW column{}; column.mask = LVCF_TEXT | LVCF_WIDTH;
        column.cx = px(95); column.pszText = const_cast<wchar_t*>(L"Time"); ListView_InsertColumn(list, 0, &column);
        column.cx = px(600); column.pszText = const_cast<wchar_t*>(L"Activity · this session"); ListView_InsertColumn(list, 1, &column);
        setting_controls.push_back(control(L"BUTTON", L"Start Writ when I sign in to Windows", WS_TABSTOP | BS_AUTOCHECKBOX, startup));
        SendMessageW(GetDlgItem(main, startup), BM_SETCHECK, starts_with_windows() ? BST_CHECKED : BST_UNCHECKED, 0);
        setting_controls.push_back(control(L"STATIC", L"Starts in the notification area. Closing the window keeps Writ running; Quit stops it.", SS_LEFT, 210));
        setting_controls.push_back(control(L"BUTTON", L"Open &recovery copies", WS_TABSTOP, recovery));
        setting_controls.push_back(control(L"BUTTON", L"Open &diagnostics", WS_TABSTOP, diagnostics));
        setting_controls.push_back(control(L"BUTTON", L"Releases and &updates", WS_TABSTOP, releases));
        auto version = L"Writ " + wide(WRIT_VERSION) + L"\nSource " + wide(WRIT_SOURCE_COMMIT);
        setting_controls.push_back(control(L"STATIC", version.c_str(), SS_LEFT, 211));
        control(L"STATIC", L"Public preview: only hello.txt (up to 64 KiB) syncs to a local backing store.\nCloud accounts, folder sync and protected-data use are not available in this preview.", SS_LEFT, 203);
        fonts(); layout();
    }
    LRESULT message(HWND window, UINT message, WPARAM wp, LPARAM lp) {
        if (message == WM_CTLCOLORSTATIC) {
            auto dc = reinterpret_cast<HDC>(wp);
            SetBkMode(dc, TRANSPARENT); SetTextColor(dc, GetSysColor(COLOR_WINDOWTEXT));
            return reinterpret_cast<LRESULT>(GetSysColorBrush(COLOR_WINDOW));
        }
        if (window == flyout || (window != main && message != WM_NCCREATE)) {
            if (message == WM_COMMAND) { command(LOWORD(wp)); return 0; }
            if (message == WM_ACTIVATE && LOWORD(wp) == WA_INACTIVE) { ShowWindow(window, SW_HIDE); return 0; }
            if (message == WM_CLOSE) { ShowWindow(window, SW_HIDE); return 0; }
            return DefWindowProcW(window, message, wp, lp);
        }
        if (message == taskbar_created) { tray_added = false; notify(true); return 0; }
        switch (message) {
        case WM_COMMAND: command(LOWORD(wp)); return 0;
        case WM_NOTIFY:
            if (reinterpret_cast<NMHDR*>(lp)->idFrom == tabs_id && reinterpret_cast<NMHDR*>(lp)->code == TCN_SELCHANGE) {
                settings_open = TabCtrl_GetCurSel(tab) == 1; layout();
            } return 0;
        case WM_TIMER: tick(); return 0;
        case WM_SIZE: if (status_label) layout(); return 0;
        case WM_GETMINMAXINFO:
            reinterpret_cast<MINMAXINFO*>(lp)->ptMinTrackSize = {px(690), px(700)}; return 0;
        case WM_DPICHANGED: {
            dpi = HIWORD(wp); fonts();
            auto rect = reinterpret_cast<RECT*>(lp);
            SetWindowPos(main, nullptr, rect->left, rect->top, rect->right - rect->left, rect->bottom - rect->top, SWP_NOZORDER | SWP_NOACTIVATE);
            if (flyout) { DestroyWindow(flyout); flyout = nullptr; }
            layout(); return 0;
        }
        case tray_message:
            if (LOWORD(lp) == NIN_SELECT || LOWORD(lp) == NIN_KEYSELECT) show_flyout();
            else if (LOWORD(lp) == WM_CONTEXTMENU) popup();
            return 0;
        case activate_message: show(false); return 0;
        case WM_CLOSE:
            if (tray_added) ShowWindow(main, SW_HIDE); else request_stop(true);
            return 0;
        case WM_QUERYENDSESSION: request_stop(true); return TRUE;
        case WM_ENDSESSION: if (wp) DestroyWindow(main); return 0;
        case WM_DESTROY: {
            KillTimer(main, 1);
            NOTIFYICONDATAW item{}; item.cbSize = sizeof(item); item.hWnd = main; item.uID = 1;
            item.uFlags = NIF_GUID; item.guidItem = tray_guid; Shell_NotifyIconW(NIM_DELETE, &item);
            PostQuitMessage(0); return 0;
        }
        default: return DefWindowProcW(window, message, wp, lp);
        }
    }
public:
    explicit App(HINSTANCE value) : instance(value), root(user_path(CSIDL_PROFILE, L"Writ")),
        data(user_path(CSIDL_LOCAL_APPDATA, L"WritDemo")) {
        auto logs = data / L"desktop";
        writ::local_user_path(logs); writ::private_directory(data); writ::private_directory(logs);
        log_path = logs / L"activity.log";
        auto key = writ::folded(writ::canonical(root));
        recovery_path = data / L"store" / L"roots" / writ::digest(key.data(), key.size() * sizeof(wchar_t)) / L"recovery";
        quit_event.reset(CreateEventW(nullptr, TRUE, FALSE, quit_name));
        writ::check(quit_event.valid(), "desktop quit event");
        job.reset(CreateJobObjectW(nullptr, nullptr));
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION limit{}; limit.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        writ::check(job.valid() && SetInformationJobObject(job.value, JobObjectExtendedLimitInformation, &limit, sizeof(limit)), "owned provider job");
    }
    ~App() {
        // Crash/logoff cleanup is conservative: pending edits remain in place.
        job.reset();
        if (icon) DestroyIcon(icon);
        if (normal) DeleteObject(normal);
        if (heading) DeleteObject(heading);
        if (brand) DeleteObject(brand);
    }
    static LRESULT CALLBACK procedure(HWND window, UINT message, WPARAM wp, LPARAM lp) {
        auto self = reinterpret_cast<App*>(GetWindowLongPtrW(window, GWLP_USERDATA));
        if (message == WM_NCCREATE) {
            self = static_cast<App*>(reinterpret_cast<CREATESTRUCTW*>(lp)->lpCreateParams);
            SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        }
        if (!self) return DefWindowProcW(window, message, wp, lp);
        try { return self->message(window, message, wp, lp); }
        catch (const std::exception& error) {
            self->attention = true; self->status = L"Needs attention"; self->detail = wide(error.what());
            if (self->status_label) { SetWindowTextW(self->status_label, self->status.c_str()); SetWindowTextW(self->detail_label, self->detail.c_str()); }
            self->log(std::string("DESKTOP_ERROR ") + error.what());
            return 0;
        }
    }
    int run(bool background) {
        INITCOMMONCONTROLSEX controls{sizeof(controls), ICC_LISTVIEW_CLASSES | ICC_TAB_CLASSES};
        writ::check(InitCommonControlsEx(&controls), "common controls");
        fonts();
        WNDCLASSEXW type{}; type.cbSize = sizeof(type); type.lpfnWndProc = procedure;
        type.hInstance = instance; type.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        type.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1); type.lpszClassName = window_class;
        writ::check(RegisterClassExW(&type) != 0, "register desktop window");
        type.lpszClassName = flyout_class; writ::check(RegisterClassExW(&type) != 0, "register flyout");
        main = CreateWindowExW(WS_EX_CONTROLPARENT, window_class, L"Writ", WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN,
            CW_USEDEFAULT, CW_USEDEFAULT, 880, 740, nullptr, nullptr, instance, this);
        writ::check(main != nullptr, "desktop window");
        dpi = GetDpiForWindow(main); create_controls();
        taskbar_created = RegisterWindowMessageW(L"TaskbarCreated");
        make_icon();
        SetTimer(main, 1, 200, nullptr);
        if (!background || !tray_added) show(false);
        try { start(); }
        catch (const std::exception& error) {
            attention = true; status = L"Could not start Writ"; detail = wide(error.what());
            record(detail); update(); show(false);
        }
        MSG message{}; BOOL result;
        while ((result = GetMessageW(&message, nullptr, 0, 0)) > 0) {
            HWND dialog = flyout && IsWindowVisible(flyout) ? flyout : main;
            if (message.message == WM_KEYDOWN && message.wParam == VK_ESCAPE && dialog == flyout) { ShowWindow(flyout, SW_HIDE); continue; }
            if (!IsDialogMessageW(dialog, &message)) { TranslateMessage(&message); DispatchMessageW(&message); }
        }
        return result == -1 ? 1 : static_cast<int>(message.wParam);
    }
};
} // namespace desktop

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
    using namespace desktop;
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    HRESULT com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    int result = 1;
    try {
        int count = 0; wchar_t** args = CommandLineToArgvW(GetCommandLineW(), &count);
        writ::check(args != nullptr, "command line");
        std::wstring option = count == 2 ? args[1] : L"";
        bool valid = count == 1 || (count == 2 && (option == L"--background" || option == L"--quit" || option == L"--unregister-startup"));
        LocalFree(args);
        if (!valid) throw writ::Error("Use Writ.exe [--background | --quit | --unregister-startup]", ERROR_INVALID_PARAMETER);
        if (option == L"--unregister-startup") { set_startup(false); result = 0; }
        else if (option == L"--quit") {
            Handle signal(OpenEventW(EVENT_MODIFY_STATE, FALSE, quit_name));
            if (!signal.valid()) {
                if (GetLastError() != ERROR_FILE_NOT_FOUND) throw writ::Error("open app shutdown event", GetLastError());
                result = 0;
            } else {
                Handle owner(OpenMutexW(SYNCHRONIZE, FALSE, mutex_name));
                writ::check(owner.valid() && SetEvent(signal.value), "request desktop shutdown");
                DWORD stopped = WaitForSingleObject(owner.value, 30000);
                result = stopped == WAIT_OBJECT_0 || stopped == WAIT_ABANDONED ? 0 : 1;
            }
        } else {
            Handle owner(CreateMutexW(nullptr, TRUE, mutex_name));
            writ::check(owner.valid(), "desktop instance");
            if (GetLastError() == ERROR_ALREADY_EXISTS) {
                HWND existing = nullptr;
                for (int retry = 0; retry < 50 && !existing; ++retry) { existing = FindWindowW(window_class, nullptr); if (!existing) Sleep(100); }
                if (existing) { PostMessageW(existing, activate_message, 0, 0); result = 0; }
            } else {
                App app(instance); result = app.run(option == L"--background"); ReleaseMutex(owner.value);
            }
        }
    } catch (const std::exception& error) { MessageBoxW(nullptr, wide(error.what()).c_str(), L"Writ could not complete the operation", MB_OK | MB_ICONERROR); }
    if (SUCCEEDED(com)) CoUninitialize();
    return result;
}
