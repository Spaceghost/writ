#define _WIN32_WINNT 0x0A00
#include "channels.h"
#include <objbase.h>

static HRESULT native_error(void)
{
    DWORD error = GetLastError();
    return HRESULT_FROM_WIN32(error ? error : ERROR_GEN_FAILURE);
}

WRIT_CHANNEL_RESULT writ_clipboard_attempt(void)
{
    WRIT_CHANNEL_RESULT result = { 1, E_FAIL };
    HMODULE module = LoadLibraryExW(L"user32.dll", NULL, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!module) { result.result = native_error(); return result; }
    typedef BOOL (WINAPI *OPEN_CLIPBOARD)(HWND);
    typedef BOOL (WINAPI *CLOSE_CLIPBOARD)(void);
    OPEN_CLIPBOARD open = (OPEN_CLIPBOARD)GetProcAddress(module, "OpenClipboard");
    CLOSE_CLIPBOARD close = (CLOSE_CLIPBOARD)GetProcAddress(module, "CloseClipboard");
    result.stage = 2;
    if (!open || !close) result.result = HRESULT_FROM_WIN32(ERROR_PROC_NOT_FOUND);
    else {
        result.stage = 3;
        SetLastError(ERROR_SUCCESS);
        if (!open(NULL)) result.result = native_error();
        else {
            result.stage = 4;
            result.result = close() ? S_OK : native_error();
        }
    }
    FreeLibrary(module);
    return result;
}

WRIT_CHANNEL_RESULT writ_com_attempt(void)
{
    WRIT_CHANNEL_RESULT result = { 1, E_FAIL };
    HMODULE module = LoadLibraryExW(L"ole32.dll", NULL, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!module) { result.result = native_error(); return result; }
    typedef HRESULT (WINAPI *INITIALIZE)(LPVOID, DWORD);
    typedef void (WINAPI *UNINITIALIZE)(void);
    typedef HRESULT (WINAPI *CREATE)(REFCLSID, LPUNKNOWN, DWORD, REFIID, LPVOID *);
    INITIALIZE initialize = (INITIALIZE)GetProcAddress(module, "CoInitializeEx");
    UNINITIALIZE uninitialize = (UNINITIALIZE)GetProcAddress(module, "CoUninitialize");
    CREATE create = (CREATE)GetProcAddress(module, "CoCreateInstance");
    result.stage = 2;
    if (!initialize || !uninitialize || !create) result.result = HRESULT_FROM_WIN32(ERROR_PROC_NOT_FOUND);
    else {
        result.stage = 3;
        result.result = initialize(NULL, COINIT_APARTMENTTHREADED);
        if (SUCCEEDED(result.result)) {
            /* ShellWindows is a documented local-server COM entry point. Only
               obtain/release IUnknown; do not enumerate windows or invoke a helper. */
            static const CLSID shell_windows = {0x9ba05972,0xf6a8,0x11cf,{0xa4,0x42,0x00,0xa0,0xc9,0x0a,0x8f,0x39}};
            static const IID unknown = {0x00000000,0x0000,0x0000,{0xc0,0x00,0x00,0x00,0x00,0x00,0x00,0x46}};
            IUnknown *object = NULL;
            result.stage = 4;
            result.result = create(&shell_windows, NULL, CLSCTX_LOCAL_SERVER, &unknown, (void **)&object);
            if (object) object->lpVtbl->Release(object);
            else if (SUCCEEDED(result.result)) result.result = E_UNEXPECTED;
            uninitialize();
        }
    }
    FreeLibrary(module);
    return result;
}

BOOL writ_clipboard_denied(WRIT_CHANNEL_RESULT result)
{
    /* A missing DLL/export, failed close, or unrelated failure earns no credit. */
    return result.stage == 3 && result.result == E_ACCESSDENIED;
}

BOOL writ_com_denied(WRIT_CHANNEL_RESULT result)
{
    return (result.stage == 3 || result.stage == 4) &&
        (result.result == E_ACCESSDENIED || result.result == RPC_E_ACCESS_DENIED);
}
