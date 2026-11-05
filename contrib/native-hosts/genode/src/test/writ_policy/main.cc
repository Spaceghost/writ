#include <base/attached_rom_dataspace.h>
#include <base/log.h>
#include <libc/component.h>
#include <policy.h>
#include <quickjs_alloc.h>
#include <allocator_checks.h>
#include <timer_session/connection.h>

namespace {

Genode::size_t source_length(Genode::Attached_rom_dataspace const &rom)
{
    if (!rom.valid() || rom.size() > 8U * 1024U * 1024U) throw Writ::Javascript::Failed();
    auto const *source = rom.local_addr<char>();
    Genode::size_t n = 0;
    while (n < rom.size() && source[n]) ++n;
    if (!n) throw Writ::Javascript::Failed();
    return n;
}

}

Genode::size_t Libc::Component::stack_size() { return 768U * 1024U; }

void Libc::Component::construct(Libc::Env &env)
{
    try {
        Libc::with_libc([&] {
            Timer::Connection clock(env);
            Genode::Attached_rom_dataspace config(env, "config");
            unsigned const expected_core = config.node().attribute_value("expected_core", 0U);
            if (!expected_core || expected_core > 100000) throw Writ::Javascript::Failed();
            int const allocation_checks = writ_qjs_allocator_checks();
            if (allocation_checks != WRIT_QJS_ALLOCATOR_CHECKS) {
                Genode::error("allocator check failed: ", allocation_checks);
                throw Writ::Javascript::Failed();
            }
            Genode::log("PASS native allocator checks: ", allocation_checks);
            Genode::Attached_rom_dataspace core(env, "core-tests.js");
            auto const core_start = clock.elapsed_ms();
            unsigned const core_count = Writ::run_core_checks(core.local_addr<char>(), source_length(core), expected_core);
            if (writ_qjs_live_bytes() || writ_qjs_reserved_bytes()) throw Writ::Javascript::Failed();
            Genode::log("PASS native Genode core corpus: ", core_count);
            Genode::log("TIMING core_ms=", clock.elapsed_ms() - core_start);
            Genode::Attached_rom_dataspace mount(env, "mount-tests.mjs");
            auto const mount_start = clock.elapsed_ms();
            unsigned const mount_count = Writ::run_pure_checks(mount.local_addr<char>(), source_length(mount));
            if (writ_qjs_live_bytes() || writ_qjs_reserved_bytes()) throw Writ::Javascript::Failed();
            Genode::log("PASS native Genode mount corpus: ", mount_count);
            Genode::log("TIMING mount_ms=", clock.elapsed_ms() - mount_start);
            Genode::log("QUICKJS heap_peak=", writ_qjs_peak_bytes(),
                        " reserved_peak=", writ_qjs_peak_reserved_bytes(),
                        " heap_live=0 reserved=0 tracked_limit=134217728");
        });
        Genode::log("WRIT POLICY NATIVE PASS");
        env.parent().exit(0);
    } catch (...) {
        Genode::error("WRIT POLICY NATIVE FAIL heap_peak=", writ_qjs_peak_bytes(),
                      " heap_live=", writ_qjs_live_bytes(), " reserved=", writ_qjs_reserved_bytes());
        env.parent().exit(1);
    }
}
