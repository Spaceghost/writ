#include "policy.h"
#include <base/log.h>
#include <string.h>

namespace {

struct Core_checks {
    unsigned passed { 0 };
    unsigned exits { 0 };
    unsigned exit_code { 1 };
    bool summary { false };
    bool failed { false };
};

JSValue output(JSContext *ctx, JSValueConst, int argc, JSValueConst *argv)
{
    auto &state = *static_cast<Core_checks *>(JS_GetContextOpaque(ctx));
    int32_t descriptor = 0;
    if (argc != 2 || JS_ToInt32(ctx, &descriptor, argv[0]) ||
        descriptor != 1 || !JS_IsString(argv[1])) {
        state.failed = true;
        return JS_ThrowTypeError(ctx, "unsupported test output");
    }
    size_t length = 0;
    char const *text = JS_ToCStringLen(ctx, &length, argv[1]);
    if (!text || !length || length > 1024 || text[length - 1] != '\n') {
        if (text) JS_FreeCString(ctx, text);
        state.failed = true;
        return JS_ThrowTypeError(ctx, "invalid test diagnostic");
    }
    for (size_t i = 0; i + 1 < length; ++i) {
        unsigned char c = static_cast<unsigned char>(text[i]);
        if (c < 32 || c > 126) {
            JS_FreeCString(ctx, text);
            state.failed = true;
            return JS_ThrowTypeError(ctx, "non-ASCII test diagnostic");
        }
    }
    if (!strncmp(text, "PASS:", 5) || !strncmp(text, "PASS ", 5)) ++state.passed;
    if (!strncmp(text, "FAIL", 4)) state.failed = true;
    if (!strcmp(text, "ALL LIBRARY TESTS PASSED\n")) state.summary = true;
    char line[1025];
    memcpy(line, text, length);
    line[length - 1] = 0;
    Genode::log(Genode::Cstring(line));
    JS_FreeCString(ctx, text);
    return JS_UNDEFINED;
}

JSValue exit_test(JSContext *ctx, JSValueConst, int argc, JSValueConst *argv)
{
    auto &state = *static_cast<Core_checks *>(JS_GetContextOpaque(ctx));
    uint32_t code = 1;
    if (argc != 1 || JS_ToUint32(ctx, &code, argv[0]) || code > 255)
        state.failed = true;
    ++state.exits;
    state.exit_code = code;
    return JS_UNDEFINED;
}

char const prelude[] = R"JS(
// Deliberately limited to the inspected corpus's ASCII diagnostic effects.
// No file access, native FFI, process creation, or sockets are installed.
globalThis.process = {argv:["genode", "writ-core"], exit:__writ_exit};
globalThis.require = function(name) {
  if (name !== "fs") throw Error("unsupported native test effect");
  return {writeSync(fd, data) {
    if (data.length > 1024) throw Error("test diagnostic too large");
    const text = typeof data === "string" ? data : String.fromCharCode(...data);
    __writ_output(fd, text);
    return data.length;
  }};
};
globalThis.TextEncoder = class {
  encode(text) {
    const bytes = new Uint8Array(text.length);
    for (let i=0; i<text.length; ++i) {
      const c = text.charCodeAt(i);
      if (c > 127) throw Error("only ASCII test diagnostics are supported");
      bytes[i] = c;
    }
    return bytes;
  }
};
)JS";

}

unsigned Writ::run_core_checks(char const *source, Genode::size_t length, unsigned expected)
{
    if (!expected || expected > 100000) throw Javascript::Failed();
    Javascript js;
    JSContext *ctx = js.context();
    Core_checks state;
    JS_SetContextOpaque(ctx, &state);
    JSValue global = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, global, "__writ_output", JS_NewCFunction(ctx, output, "output", 2));
    JS_SetPropertyStr(ctx, global, "__writ_exit", JS_NewCFunction(ctx, exit_test, "exit", 1));
    JS_FreeValue(ctx, global);
    JSValue result = js.script(prelude, sizeof(prelude) - 1, "diagnostics.js");
    JS_FreeValue(ctx, result);
    result = js.script(source, length, "core-tests.js");
    JS_FreeValue(ctx, result);
    if (state.failed || state.exits != 1 || state.exit_code ||
        !state.summary || state.passed != expected) throw Javascript::Failed();
    return state.passed;
}
