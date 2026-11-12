// Native Windows UI Automation client for the real packaged desktop controls.
// This test executable is built beside the application, not shipped to users.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <ole2.h>
#include <UIAutomation.h>
#include <wrl/client.h>
#include <iostream>
#include <string>
#include <stdexcept>

using Microsoft::WRL::ComPtr;
static void check(HRESULT result, const char* operation) {
    if (FAILED(result)) throw std::runtime_error(std::string(operation) + " HRESULT=" + std::to_string(static_cast<unsigned long>(result)));
}
static std::string json(BSTR value) {
    if (!value) return "\"\"";
    int size = WideCharToMultiByte(CP_UTF8, 0, value, static_cast<int>(SysStringLen(value)), nullptr, 0, nullptr, nullptr);
    std::string utf8(static_cast<size_t>(size), ' '), result = "\"";
    WideCharToMultiByte(CP_UTF8, 0, value, static_cast<int>(SysStringLen(value)), utf8.data(), size, nullptr, nullptr);
    for (unsigned char c : utf8) {
        if (c == '"' || c == '\\') { result += '\\'; result += static_cast<char>(c); }
        else if (c == '\n') result += "\\n";
        else if (c == '\r') result += "\\r";
        else if (c == '\t') result += "\\t";
        else if (c >= 32) result += static_cast<char>(c);
    }
    return result + "\"";
}
static void dump(IUIAutomation* automation, IUIAutomationElement* root) {
    ComPtr<IUIAutomationCondition> condition;
    check(automation->CreateTrueCondition(&condition), "true condition");
    ComPtr<IUIAutomationElementArray> children;
    check(root->FindAll(TreeScope_Subtree, condition.Get(), &children), "enumerate UI");
    int length = 0; check(children->get_Length(&length), "UI length");
    if (length > 1000) throw std::runtime_error("UI inspection bound exceeded");
    std::cout << "[";
    for (int i = 0; i < length; ++i) {
        ComPtr<IUIAutomationElement> item; check(children->GetElement(i, &item), "UI element");
        BSTR name = nullptr, id = nullptr; CONTROLTYPEID type = 0; BOOL enabled = FALSE, offscreen = TRUE;
        item->get_CurrentName(&name); item->get_CurrentAutomationId(&id); item->get_CurrentControlType(&type);
        item->get_CurrentIsEnabled(&enabled); item->get_CurrentIsOffscreen(&offscreen);
        if (i) std::cout << ",";
        std::cout << "{\"name\":" << json(name) << ",\"id\":" << json(id) << ",\"type\":" << type
            << ",\"enabled\":" << (enabled ? "true" : "false") << ",\"offscreen\":" << (offscreen ? "true" : "false") << "}";
        SysFreeString(name); SysFreeString(id);
    }
    std::cout << "]\n";
}
int wmain(int argc, wchar_t** argv) {
    HRESULT initialized = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    int result = 1;
    try {
        check(initialized, "COM");
        if (argc != 3) throw std::runtime_error("Usage: desktop-probe invoke|toggle|settings|dump HWND_DECIMAL");
        size_t used = 0; auto value = std::stoull(argv[2], &used);
        if (used != wcslen(argv[2])) throw std::runtime_error("Invalid HWND");
        HWND window = reinterpret_cast<HWND>(static_cast<UINT_PTR>(value));
        wchar_t name[128];
        if (!IsWindow(window) || !GetClassNameW(GetAncestor(window, GA_ROOT), name, 128) ||
            (wcscmp(name, L"WritDesktop.7DDDA5C1") && wcscmp(name, L"WritFlyout.7DDDA5C1") && wcscmp(name, L"WritConnection.7DDDA5C1")))
            throw std::runtime_error("Only Writ desktop windows may be probed");
        ComPtr<IUIAutomation> automation;
        check(CoCreateInstance(__uuidof(CUIAutomation), nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&automation)), "UI Automation");
        ComPtr<IUIAutomationElement> element;
        check(automation->ElementFromHandle(window, &element), "element from HWND");
        std::wstring operation(argv[1]);
        if (operation == L"invoke") {
            ComPtr<IUIAutomationInvokePattern> invoke;
            check(element->GetCurrentPatternAs(UIA_InvokePatternId, IID_PPV_ARGS(&invoke)), "invoke pattern");
            check(invoke->Invoke(), "invoke control");
        } else if (operation == L"toggle") {
            ComPtr<IUIAutomationTogglePattern> toggle;
            check(element->GetCurrentPatternAs(UIA_TogglePatternId, IID_PPV_ARGS(&toggle)), "toggle pattern");
            check(toggle->Toggle(), "toggle setting");
        } else if (operation == L"settings") {
            VARIANT match{}; match.vt = VT_BSTR; match.bstrVal = SysAllocString(L"Settings");
            ComPtr<IUIAutomationCondition> condition;
            HRESULT created = automation->CreatePropertyCondition(UIA_NamePropertyId, match, &condition);
            VariantClear(&match); check(created, "settings condition");
            ComPtr<IUIAutomationElement> tab;
            check(element->FindFirst(TreeScope_Children, condition.Get(), &tab), "settings tab");
            if (!tab) throw std::runtime_error("Missing accessible Settings tab");
            ComPtr<IUIAutomationSelectionItemPattern> selection;
            check(tab->GetCurrentPatternAs(UIA_SelectionItemPatternId, IID_PPV_ARGS(&selection)), "selection pattern");
            check(selection->Select(), "select settings");
        } else if (operation == L"dump") dump(automation.Get(), element.Get());
        else throw std::runtime_error("Unknown probe operation");
        result = 0;
    } catch (const std::exception& error) { std::cerr << error.what() << '\n'; }
    if (SUCCEEDED(initialized)) CoUninitialize();
    return result;
}
