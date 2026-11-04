#include <base/attached_rom_dataspace.h>
#include <base/log.h>
#include <libc/component.h>
#include <policy.h>
#include <quickjs_alloc.h>

namespace {

Genode::size_t source_length(Genode::Attached_rom_dataspace const &rom)
{
    if (!rom.valid() || rom.size() > 2U * 1024U * 1024U) throw Writ::Javascript::Failed();
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
            Genode::Attached_rom_dataspace config(env, "config");
            unsigned const expected_core = config.node().attribute_value("expected_core", 0U);
            if (!expected_core || expected_core > 100000) throw Writ::Javascript::Failed();
            Genode::Attached_rom_dataspace core(env, "core-tests.js");
            unsigned const core_count = Writ::run_core_checks(core.local_addr<char>(), source_length(core), expected_core);
            if (writ_qjs_live_bytes()) throw Writ::Javascript::Failed();
            Genode::log("PASS native Genode core corpus: ", core_count);
            Genode::Attached_rom_dataspace mount(env, "mount-tests.mjs");
            unsigned const mount_count = Writ::run_pure_checks(mount.local_addr<char>(), source_length(mount));
            if (writ_qjs_live_bytes()) throw Writ::Javascript::Failed();
            Genode::log("PASS native Genode mount corpus: ", mount_count);
            Genode::log("QUICKJS heap_peak=", writ_qjs_peak_bytes(), " heap_live=0 tracked_limit=67108864");
        });
        Genode::log("WRIT POLICY NATIVE PASS");
        env.parent().exit(0);
    } catch (...) {
        Genode::error("WRIT POLICY NATIVE FAIL heap_peak=", writ_qjs_peak_bytes(),
                      " heap_live=", writ_qjs_live_bytes());
        env.parent().exit(1);
    }
}
