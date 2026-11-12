#pragma once
#include "connection.hpp"
#include <commctrl.h>

namespace writ_sync {
class ConnectionDialog {
    HWND owner, window = nullptr, message = nullptr;
    std::array<HWND, 7> inputs{};
    HFONT font = nullptr;
    bool changed = false;
    UINT dpi = 96;
    int px(int value) const { return MulDiv(value, static_cast<int>(dpi), 96); }
    HWND control(const wchar_t* kind, const wchar_t* text, DWORD style, int id, int x, int y, int width, int height) {
        HWND result = CreateWindowExW(wcscmp(kind, L"EDIT") == 0 ? WS_EX_CLIENTEDGE : 0, kind, text,
            WS_CHILD | WS_VISIBLE | style, px(x), px(y), px(width), px(height), window,
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)), GetModuleHandleW(nullptr), nullptr);
        writ::check(result != nullptr, "Connection control");
        SendMessageW(result, WM_SETFONT, reinterpret_cast<WPARAM>(font), TRUE); return result;
    }
    void create() {
        font = CreateFontW(-px(14), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
            OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
        control(L"STATIC", L"Connect your storage", SS_LEFT, 400, 24, 20, 520, 28);
        control(L"STATIC", L"S3-compatible storage, including Cloudflare R2.\nFiles in your Writ Cloud folder stay available offline.", SS_LEFT, 401, 24, 56, 520, 44);
        const wchar_t* labels[] = {L"HTTPS endpoint", L"Bucket", L"Folder prefix", L"Region (R2: auto)", L"Access key ID", L"Secret access key", L"Session token (optional)"};
        auto connection = Connection::load();
        std::array<std::wstring, 7> values{};
        if (connection) values = {utf16(connection->endpoint), utf16(connection->bucket), utf16(connection->prefix), utf16(connection->region), L"", L"", L""};
        else { values[2] = L"writ"; values[3] = L"auto"; }
        for (size_t i = 0; i < inputs.size(); ++i) {
            int y = 112 + static_cast<int>(i) * 52;
            control(L"STATIC", labels[i], SS_LEFT, 410 + static_cast<int>(i), 24, y, 520, 21);
            inputs[i] = control(L"EDIT", values[i].c_str(), WS_TABSTOP | ES_AUTOHSCROLL | (i >= 5 ? ES_PASSWORD : 0),
                420 + static_cast<int>(i), 24, y + 22, 520, 26);
            SendMessageW(inputs[i], EM_SETLIMITTEXT, i == 1 ? 63 : i == 3 ? 32 : 2048, 0);
        }
        message = control(L"STATIC", L"Keys are saved in Windows Credential Manager. Use a bucket/prefix dedicated to Writ; other objects are left alone.", SS_LEFT, 402, 24, 486, 520, 54);
        control(L"BUTTON", L"&Connect", WS_TABSTOP | BS_DEFPUSHBUTTON, IDOK, 24, 552, 140, 36);
        control(L"BUTTON", L"&Cancel", WS_TABSTOP, IDCANCEL, 180, 552, 140, 36);
        HWND disconnect = control(L"BUTTON", L"&Disconnect", WS_TABSTOP, 430, 336, 552, 140, 36);
        EnableWindow(disconnect, connection.has_value());
        SetFocus(inputs[0]);
    }
    void connect() {
        SecretFields<7> scratch; auto& values = scratch.values;
        for (size_t i = 0; i < inputs.size(); ++i) {
            std::array<wchar_t, 2050> text{}; GetWindowTextW(inputs[i], text.data(), static_cast<int>(text.size()));
            values[i] = utf8(text.data()); SecureZeroMemory(text.data(), sizeof(text));
        }
        Connection connection{values[0], values[1], values[2], values[3]}; connection.validate();
        Credentials credentials(values[4], values[5], values[6]);
        credentials.save(connection); connection.save(); changed = true;
        DestroyWindow(window);
    }
    void disconnect() {
        auto connection = Connection::load();
        if (connection) {
            // Disconnect removes only this application's active credential and
            // connection setting; local/remote files and recovery stay intact.
            if (!CredDeleteW(connection->credential_target().c_str(), CRED_TYPE_GENERIC, 0) && GetLastError() != ERROR_NOT_FOUND)
                writ::check(false, "Remove stored S3 credentials");
            HKEY key = nullptr; LSTATUS result = RegOpenKeyExW(HKEY_CURRENT_USER, connection_key, 0, KEY_SET_VALUE, &key);
            if (result == ERROR_SUCCESS) { result = RegDeleteValueW(key, L"Connection"); RegCloseKey(key); }
            if (result != ERROR_SUCCESS && result != ERROR_FILE_NOT_FOUND) throw writ::Error("Disconnect S3 settings", result);
        }
        changed = true; DestroyWindow(window);
    }
    static LRESULT CALLBACK procedure(HWND window, UINT event, WPARAM wp, LPARAM lp) {
        auto self = reinterpret_cast<ConnectionDialog*>(GetWindowLongPtrW(window, GWLP_USERDATA));
        if (event == WM_NCCREATE) {
            self = static_cast<ConnectionDialog*>(reinterpret_cast<CREATESTRUCTW*>(lp)->lpCreateParams);
            self->window = window; SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        }
        if (!self) return DefWindowProcW(window, event, wp, lp);
        try {
            if (event == WM_COMMAND) {
                if (LOWORD(wp) == IDOK) self->connect();
                else if (LOWORD(wp) == IDCANCEL) DestroyWindow(window);
                else if (LOWORD(wp) == 430) self->disconnect();
                return 0;
            }
            if (event == WM_CLOSE) { DestroyWindow(window); return 0; }
            if (event == WM_CTLCOLORSTATIC) {
                SetBkMode(reinterpret_cast<HDC>(wp), TRANSPARENT); return reinterpret_cast<LRESULT>(GetSysColorBrush(COLOR_WINDOW));
            }
        } catch (const std::exception& error) { SetWindowTextW(self->message, utf16(error.what()).c_str()); }
        return DefWindowProcW(window, event, wp, lp);
    }
public:
    explicit ConnectionDialog(HWND parent) : owner(parent), dpi(GetDpiForWindow(parent)) {}
    ~ConnectionDialog() { if (font) DeleteObject(font); }
    bool run() {
        WNDCLASSEXW type{}; type.cbSize = sizeof(type); type.lpfnWndProc = procedure;
        type.hInstance = GetModuleHandleW(nullptr); type.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        type.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1); type.lpszClassName = L"WritConnection.7DDDA5C1";
        if (!RegisterClassExW(&type) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) writ::check(false, "Register storage window");
        window = CreateWindowExW(WS_EX_CONTROLPARENT, type.lpszClassName, L"Writ — Connect storage", WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU,
            CW_USEDEFAULT, CW_USEDEFAULT, px(580), px(648), owner, nullptr, type.hInstance, this);
        writ::check(window != nullptr, "Storage connection window"); create();
        EnableWindow(owner, FALSE); ShowWindow(window, SW_SHOW); SetForegroundWindow(window);
        MSG event{};
        while (IsWindow(window) && GetMessageW(&event, nullptr, 0, 0) > 0) {
            if (!IsDialogMessageW(window, &event)) { TranslateMessage(&event); DispatchMessageW(&event); }
        }
        EnableWindow(owner, TRUE); SetForegroundWindow(owner); return changed;
    }
};
} // namespace writ_sync
