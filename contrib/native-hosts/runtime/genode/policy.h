#ifndef WRIT_GENODE_POLICY_H
#define WRIT_GENODE_POLICY_H

#include <base/stdint.h>
#include <util/string.h>
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wconversion"
#pragma GCC diagnostic ignored "-Wunused-parameter"
#include <quickjs.h>
#pragma GCC diagnostic pop

namespace Writ {

class Javascript
{
    JSRuntime *_runtime { nullptr };
    JSContext *_context { nullptr };
    unsigned _ticks { 0 };

    static int interrupt(JSRuntime *, void *);

public:
    struct Failed { };
    Javascript();
    ~Javascript();
    Javascript(Javascript const &) = delete;
    Javascript &operator=(Javascript const &) = delete;

    JSContext *context() { return _context; }
    void budget();
    JSValue module(char const *, Genode::size_t, char const *);
    JSValue call(JSValue, int, JSValue *);
    JSValue script(char const *, Genode::size_t, char const *);
};

class Policy
{
public:
    enum class Status { OK, DENY, ERROR };
    struct Reply {
        Status status { Status::ERROR };
        Genode::uint32_t value { 0 };
        Genode::String<80> detail { "runtime" };
        bool ok() const { return status == Status::OK; }
    };

private:
    Javascript _js { };
    JSValue _module { JS_UNDEFINED };
    JSValue _dispatch { JS_UNDEFINED };
    JSValue _next { JS_UNDEFINED };
    JSValue _reply { JS_UNDEFINED };
    JSValue _state { JS_UNDEFINED };
    Genode::uint32_t _sequence { 0 };
    bool _healthy { true };
    bool _busy { false };

    static bool decimal(char const *, Genode::uint32_t &);
    Reply parse(char const *, Genode::size_t);

public:
    Policy(char const *, Genode::size_t);
    ~Policy();
    Policy(Policy const &) = delete;
    Policy &operator=(Policy const &) = delete;

    Reply command(char const *, Genode::size_t);
    Reply command(char const *op, Genode::uint32_t actor = 0,
                  Genode::uint32_t handle = 0, Genode::uint32_t offset = 0,
                  Genode::uint32_t count = 0, char const *argument = "-");
    bool healthy() const { return _healthy; }
};

unsigned run_pure_checks(char const *, Genode::size_t);
unsigned run_core_checks(char const *, Genode::size_t, unsigned expected);

}
#endif
