#include "policy.h"
#include "quickjs_alloc.h"
#include <libc/component.h>
#include <base/log.h>
#include <string.h>
#include <stdlib.h>

using namespace Genode;

int Writ::Javascript::interrupt(JSRuntime *, void *opaque)
{
    auto &self = *static_cast<Javascript *>(opaque);
    return !self._ticks || !--self._ticks;
}

Writ::Javascript::Javascript()
{
    _runtime = JS_NewRuntime();
    if (!_runtime) { writ_qjs_trim(); throw Failed(); }
    JS_SetMemoryLimit(_runtime, 64U * 1024U * 1024U);
    JS_SetMaxStackSize(_runtime, 512U * 1024U);
    JS_SetInterruptHandler(_runtime, interrupt, this);
    _context = JS_NewContext(_runtime);
    if (!_context) {
        JS_FreeRuntime(_runtime);
        _runtime = nullptr;
        writ_qjs_trim();
        throw Failed();
    }
}

Writ::Javascript::~Javascript()
{
    if (_context) JS_FreeContext(_context);
    if (_runtime) JS_FreeRuntime(_runtime);
    writ_qjs_trim();
}

void Writ::Javascript::budget()
{
    /* QuickJS invokes this handler periodically; this is a finite VM budget,
     * not a claimed wall-clock deadline. The native test runner also times out.
     */
    _ticks = 200000;
    JS_UpdateStackTop(_runtime);
}

JSValue Writ::Javascript::module(char const *source, size_t length, char const *name)
{
    budget();
    if (!length || length > 2U * 1024U * 1024U) throw Failed();
    char *copy = static_cast<char *>(malloc(length + 1));
    if (!copy) throw Failed();
    Genode::memcpy(copy, source, length);
    copy[length] = 0;
    JSValue compiled = JS_Eval(_context, copy, length, name,
                              JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY);
    free(copy);
    if (JS_IsException(compiled)) throw Failed();
    auto *definition = static_cast<JSModuleDef *>(JS_VALUE_GET_PTR(compiled));
    JSValue result = JS_EvalFunction(_context, compiled);
    if (JS_IsException(result)) throw Failed();
    int const promise_state = int(JS_PromiseState(_context, result));
    if (promise_state >= 0 && promise_state != JS_PROMISE_FULFILLED) {
        JS_FreeValue(_context, result);
        throw Failed();
    }
    JS_FreeValue(_context, result);
    JSValue space = JS_GetModuleNamespace(_context, definition);
    if (JS_IsException(space)) throw Failed();
    JSValue exports = JS_GetPropertyStr(_context, space, "default");
    JS_FreeValue(_context, space);
    if (JS_IsException(exports) || !JS_IsObject(exports)) {
        JS_FreeValue(_context, exports);
        throw Failed();
    }
    return exports;
}

JSValue Writ::Javascript::call(JSValue function, int count, JSValue *arguments)
{
    budget();
    if (!JS_IsFunction(_context, function)) throw Failed();
    JSValue result = JS_Call(_context, function, JS_UNDEFINED, count, arguments);
    if (JS_IsException(result)) throw Failed();
    return result;
}

JSValue Writ::Javascript::script(char const *source, size_t length, char const *name)
{
    budget();
    if (!length || length > 2U * 1024U * 1024U) throw Failed();
    char *copy = static_cast<char *>(malloc(length + 1));
    if (!copy) throw Failed();
    Genode::memcpy(copy, source, length);
    copy[length] = 0;
    JSValue result = JS_Eval(_context, copy, length, name, JS_EVAL_TYPE_GLOBAL);
    free(copy);
    if (JS_IsException(result)) throw Failed();
    return result;
}

Writ::Policy::Policy(char const *source, size_t length)
{
    JSContext *ctx = _js.context();
    JSValue init = JS_UNDEFINED;
    try {
        _module = _js.module(source, length, "mount.mjs");
        _dispatch = JS_GetPropertyStr(ctx, _module, "dispatch");
        _next = JS_GetPropertyStr(ctx, _module, "next");
        _reply = JS_GetPropertyStr(ctx, _module, "reply");
        init = JS_GetPropertyStr(ctx, _module, "initial");
        _state = _js.call(init, 0, nullptr);
    } catch (...) {
        JS_FreeValue(ctx, init);
        JS_FreeValue(ctx, _reply);
        JS_FreeValue(ctx, _next);
        JS_FreeValue(ctx, _dispatch);
        JS_FreeValue(ctx, _module);
        throw;
    }
    JS_FreeValue(ctx, init);
}

Writ::Policy::~Policy()
{
    JSContext *ctx = _js.context();
    JS_FreeValue(ctx, _state);
    JS_FreeValue(ctx, _reply);
    JS_FreeValue(ctx, _next);
    JS_FreeValue(ctx, _dispatch);
    JS_FreeValue(ctx, _module);
}

bool Writ::Policy::decimal(char const *text, uint32_t &value)
{
    if (!*text || (*text == '0' && text[1])) return false;
    value = 0;
    for (; *text; ++text) {
        if (*text < '0' || *text > '9') return false;
        uint32_t digit = uint32_t(*text - '0');
        if (value > (0xffffffffU - digit) / 10U) return false;
        value = value * 10U + digit;
    }
    return true;
}

Writ::Policy::Reply Writ::Policy::parse(char const *text, size_t length)
{
    Reply result;
    if (!length || length > 256 || text[length - 1] != '\n') return result;
    char copy[257];
    Genode::memcpy(copy, text, length);
    copy[length - 1] = 0;
    char *fields[5] { copy, nullptr, nullptr, nullptr, nullptr };
    unsigned field = 0;
    for (size_t i = 0; i + 1 < length; ++i) {
        unsigned char c = static_cast<unsigned char>(copy[i]);
        if (c == '\t') {
            if (++field == 5) return result;
            copy[i] = 0;
            fields[field] = copy + i + 1;
        } else if (c < 32 || c > 126) return result;
    }
    uint32_t sequence = 0;
    if (field != 4 || Genode::strcmp(fields[0], "WRITFS1") ||
        !decimal(fields[1], sequence) || _sequence == 0xffffffffU ||
        sequence != _sequence + 1 || !decimal(fields[3], result.value) ||
        !*fields[4] || Genode::strlen(fields[4]) >= 80) return Reply();
    if (!Genode::strcmp(fields[2], "OK")) result.status = Status::OK;
    else if (!Genode::strcmp(fields[2], "DENY")) result.status = Status::DENY;
    else if (!Genode::strcmp(fields[2], "ERROR")) result.status = Status::ERROR;
    else return Reply();
    _sequence = sequence;
    result.detail = String<80>(Cstring(fields[4]));
    return result;
}

Writ::Policy::Reply Writ::Policy::command(char const *frame, size_t length)
{
    if (!_healthy || _busy || length > 131200) { _healthy = false; return Reply(); }
    _busy = true;
    Reply reply;
    JSContext *ctx = _js.context();
    JSValue input = JS_UNDEFINED, step = JS_UNDEFINED, output = JS_UNDEFINED;
    try {
        input = JS_NewStringLen(ctx, frame, length);
        if (JS_IsException(input)) throw Javascript::Failed();
        JSValue args[2] { _state, input };
        step = _js.call(_dispatch, 2, args);
        JSValue updated = _js.call(_next, 1, &step);
        /* Commit interpreter state before returning an accepted native effect. */
        JS_FreeValue(ctx, _state);
        _state = updated;
        output = _js.call(_reply, 1, &step);
        if (!JS_IsString(output)) throw Javascript::Failed();
        size_t size = 0;
        char const *encoded = JS_ToCStringLen(ctx, &size, output);
        if (!encoded) throw Javascript::Failed();
        reply = parse(encoded, size);
        JS_FreeCString(ctx, encoded);
        if (reply.status == Status::ERROR) _healthy = false;
    } catch (...) { _healthy = false; }
    JS_FreeValue(ctx, output);
    JS_FreeValue(ctx, step);
    JS_FreeValue(ctx, input);
    _busy = false;
    return reply;
}

Writ::Policy::Reply Writ::Policy::command(char const *op, uint32_t actor,
    uint32_t handle, uint32_t offset, uint32_t count, char const *argument)
{
    String<256> frame("WRITFS1\t", op, "\t", actor, "\t", handle, "\t",
                      offset, "\t", count, "\t", argument);
    return command(frame.string(), frame.length() - 1);
}

unsigned Writ::run_pure_checks(char const *source, size_t length)
{
    Javascript js;
    JSContext *ctx = js.context();
    JSValue module = JS_UNDEFINED, run = JS_UNDEFINED, count = JS_UNDEFINED;
    JSValue result = JS_UNDEFINED, expected = JS_UNDEFINED;
    uint32_t actual_count = 0, expected_count = 0;
    bool valid = false;
    try {
        module = js.module(source, length, "mount-tests.mjs");
        run = JS_GetPropertyStr(ctx, module, "run");
        count = JS_GetPropertyStr(ctx, module, "count");
        result = js.call(run, 0, nullptr);
        expected = js.call(count, 0, nullptr);
        valid = JS_IsNumber(result) && JS_IsNumber(expected)
            && !JS_ToUint32(ctx, &actual_count, result)
            && !JS_ToUint32(ctx, &expected_count, expected)
            && actual_count == expected_count && expected_count == 69;
    } catch (...) { }
    JS_FreeValue(ctx, expected);
    JS_FreeValue(ctx, result);
    JS_FreeValue(ctx, count);
    JS_FreeValue(ctx, run);
    JS_FreeValue(ctx, module);
    if (!valid) throw Javascript::Failed();
    return actual_count;
}
