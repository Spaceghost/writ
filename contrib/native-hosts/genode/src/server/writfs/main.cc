#include <base/attached_ram_dataspace.h>
#include <base/attached_rom_dataspace.h>
#include <base/heap.h>
#include <base/log.h>
#include <file_system_session/rpc_object.h>
#include <libc/component.h>
#include <root/component.h>
#include <util/arg_string.h>
#include <writfs/control.h>
#include <policy.h>
#include <quickjs_alloc.h>
#include <string.h>

namespace Writfs {

using namespace Genode;
namespace Fs = File_system;

template <size_t MAX>
static bool exact(Rpc_in_buffer<MAX> const &input, char const *expected)
{
    size_t const size = Genode::strlen(expected) + 1;
    return input.valid_string() && input.size() == size &&
           !Genode::memcmp(input.base(), expected, size);
}

static size_t text_size(Attached_rom_dataspace const &rom)
{
    if (!rom.valid() || rom.size() > 2U * 1024U * 1024U) throw Writ::Javascript::Failed();
    char const *text = rom.local_addr<char>();
    size_t n = 0;
    while (n < rom.size() && text[n]) ++n;
    if (!n) throw Writ::Javascript::Failed();
    return n;
}

struct Storage {
    enum { MAX_BYTES = 65536 };
    char bytes[MAX_BYTES] { };
    uint32_t length { 0 };
};

struct Session_memory {
    Attached_ram_dataspace packet_ds;
    Session_memory(Env &env, size_t size) : packet_ds(env.ram(), env.rm(), size) { }
};

class Session : private Session_memory, public Fs::Session_rpc_object
{
    Env &_env;
    Writ::Policy &_policy;
    Storage const &_storage;
    uint32_t const _actor;
    unsigned &_sessions;
    struct Handle { uint32_t id { 0 }; bool directory { false }; bool readable { false }; };
    Handle _handles[32] { };
    Signal_handler<Session> _io { _env.ep(), *this, &Session::packets };

    Writ::Policy::Reply request(char const *operation, uint32_t id = 0,
        uint32_t offset = 0, uint32_t count = 0, char const *argument = "-")
    {
        return Libc::with_libc([&] {
            return _policy.command(operation, _actor, id, offset, count, argument);
        });
    }

    Handle &handle(Fs::Node_handle id)
    {
        if (!id.value || id.value > 0xffffffffUL) throw Fs::Invalid_handle();
        for (auto &h : _handles) if (h.id == id.value) return h;
        throw Fs::Invalid_handle();
    }

    uint32_t open(bool directory, bool readable)
    {
        Handle *slot = nullptr;
        for (auto &h : _handles) if (!h.id) { slot = &h; break; }
        if (!slot) throw Fs::No_space();
        auto const result = request("OPEN", 0, 0, 0, directory ? "root" : "data");
        if (!result.ok() || !result.value) throw Fs::Permission_denied();
        *slot = Handle { result.value, directory, readable };
        return slot->id;
    }

    bool process(Fs::Packet_descriptor &packet)
    {
        size_t const requested = packet.length();
        packet.length(0);
        size_t const dataspace_size = tx_sink()->ds_size();
        /* Do the range check with subtraction before the framework computes
         * offset + size. A hostile native descriptor may contain SIZE_MAX. */
        if (packet.offset() < 0 || packet.size() > dataspace_size ||
            size_t(packet.offset()) > dataspace_size - packet.size()) return false;
        if (requested > packet.size() || requested > Storage::MAX_BYTES ||
            packet.position() > 0xffffffffULL) return false;
        Handle &h = handle(packet.handle());
        if (packet.operation() == Fs::Packet_descriptor::SYNC ||
            packet.operation() == Fs::Packet_descriptor::READ_READY)
            return request("STAT", 0, 0, 0, h.directory ? "root" : "data").ok();
        if (packet.operation() != Fs::Packet_descriptor::READ || !h.readable) return false;

        char *target = tx_sink()->packet_content(packet);
        if (requested && !target) return false;
        if (h.directory) {
            auto const result = request("LIST", 0, 0, 0, "root");
            if (!result.ok() || result.value != 1) return false;
            if (packet.position() >= sizeof(Fs::Directory_entry)) return true;
            if (packet.position() || requested < sizeof(Fs::Directory_entry)) return false;
            Fs::Directory_entry entry { Fs::Node_type::CONTINUOUS_FILE, { true, false, false }, { "data" } };
            ::memset(static_cast<void *>(&entry), 0, sizeof(entry));
            entry.type = Fs::Node_type::CONTINUOUS_FILE;
            entry.rwx = { true, false, false };
            Genode::memcpy(entry.name.buf, "data", 5);
            Genode::memcpy(target, &entry, sizeof(entry));
            packet.length(sizeof(entry));
            return true;
        }
        auto const result = request("READ", h.id, uint32_t(packet.position()), uint32_t(requested));
        if (!result.ok() || result.value > requested || result.value > _storage.length ||
            (result.value && packet.position() > _storage.length - result.value)) return false;
        if (result.value) Genode::memcpy(target, _storage.bytes + packet.position(), result.value);
        packet.length(result.value);
        return true;
    }

    void packets()
    {
        auto &stream = *tx_sink();
        /* A peer gets at most one bounded queue batch per signal dispatch. */
        for (unsigned i = 0; i < Fs::Session::TX_QUEUE_SIZE; ++i) {
            if (!stream.packet_avail() || !stream.ready_to_ack()) break;
            auto packet = stream.try_get_packet();
            bool success = false;
            try { success = process(packet); }
            catch (...) { packet.length(0); }
            packet.succeeded(success);
            stream.try_ack_packet(packet);
        }
        stream.wakeup();
        if (stream.packet_avail() && stream.ready_to_ack())
            Signal_transmitter(_io).submit();
    }

public:
    Session(Env &env, Writ::Policy &policy, Storage const &storage,
            uint32_t actor, unsigned &sessions, size_t tx_size)
    : Session_memory(env, tx_size),
      Fs::Session_rpc_object(packet_ds.cap(), env.rm(), env.ep().rpc_ep()),
      _env(env), _policy(policy), _storage(storage), _actor(actor), _sessions(sessions)
    {
        ++_sessions;
        _tx.sigh_packet_avail(_io);
        _tx.sigh_ready_to_ack(_io);
    }

    ~Session()
    {
        for (auto &h : _handles) if (h.id) request("CLOSE", h.id);
        if (_actor) Libc::with_libc([&] { _policy.command("REVOKE"); });
        --_sessions;
    }

    Fs::Dir_handle dir(Fs::Path const &path, bool create) override
    {
        if (create) throw Fs::Permission_denied();
        if (!exact(path, "/")) throw Fs::Lookup_failed();
        return Fs::Dir_handle { open(true, true) };
    }

    Fs::File_handle file(Fs::Dir_handle directory, Fs::Name const &name,
                         Fs::Mode mode, bool create) override
    {
        if (create || (mode != Fs::READ_ONLY && mode != Fs::STAT_ONLY))
            throw Fs::Permission_denied();
        if (!handle(directory).directory) throw Fs::Invalid_handle();
        if (!exact(name, "data")) throw Fs::Lookup_failed();
        return Fs::File_handle { open(false, mode == Fs::READ_ONLY) };
    }

    Fs::Node_handle node(Fs::Path const &path) override
    {
        bool const directory = exact(path, "/");
        if (!directory && !exact(path, "/data")) throw Fs::Lookup_failed();
        /* The protocol has no Permission_denied exception on node(). */
        try { return Fs::Node_handle { open(directory, false) }; }
        catch (...) { throw Fs::Lookup_failed(); }
    }

    void close(Fs::Node_handle id) override
    {
        Handle &h = handle(id);
        auto const result = request("CLOSE", h.id);
        h = Handle();
        if (!result.ok()) throw Fs::Invalid_handle();
    }

    Fs::Status status(Fs::Node_handle id) override
    {
        Handle &h = handle(id);
        auto const result = request("STAT", 0, 0, 0, h.directory ? "root" : "data");
        if (!result.ok()) throw Fs::Unavailable();
        return Fs::Status { h.directory ? sizeof(Fs::Directory_entry) : result.value,
            h.directory ? Fs::Node_type::DIRECTORY : Fs::Node_type::CONTINUOUS_FILE,
            { true, false, false }, { 0 } };
    }

    unsigned num_entries(Fs::Dir_handle id) override
    {
        if (!handle(id).directory) throw Fs::Invalid_handle();
        auto const result = request("LIST", 0, 0, 0, "root");
        if (!result.ok() || result.value != 1) throw Fs::Invalid_handle();
        return 1;
    }

    Fs::Symlink_handle symlink(Fs::Dir_handle, Fs::Name const &, bool) override
    { throw Fs::Permission_denied(); }
    Fs::Watch_handle watch(Fs::Path const &) override { return Fs::Watch_handle { ~0UL }; }
    void control(Fs::Node_handle, Fs::Control) override { throw Fs::Unavailable(); }
    void unlink(Fs::Dir_handle, Fs::Name const &) override { throw Fs::Permission_denied(); }
    void truncate(Fs::File_handle, Fs::file_size_t) override { throw Fs::Permission_denied(); }
    void move(Fs::Dir_handle, Fs::Name const &, Fs::Dir_handle, Fs::Name const &) override
    { throw Fs::Permission_denied(); }
};

class Root : public Root_component<Session>
{
    Env &_env;
    Writ::Policy &_policy;
    Storage const &_storage;
    Session_label const _reader;
    bool _claimed { false };
    unsigned _sessions { 0 };

    Create_result _create_session(char const *args) override
    {
        size_t const tx_size = Arg_string::find_arg(args, "tx_buf_size").aligned_size();
        if (_sessions >= 4 || tx_size < 4096 || tx_size > 131072)
            return Create_error::DENIED;
        if (ram_quota_from_args(args).value < tx_size + sizeof(Session))
            return Create_error::INSUFFICIENT_RAM;
        if (cap_quota_from_args(args).value < Fs::Session::CAP_QUOTA)
            return Create_error::INSUFFICIENT_CAPS;

        /* Only the complete label supplied by the trusted parent is matched.
         * A suffix chosen by a client cannot supply the parent-owned prefix.
         * A closed/restarted session never inherits the old invocation.
         */
        bool const matches = !_claimed && label_from_args(args) == _reader;
        uint32_t actor = matches ? 1U : 0U;
        Session *session = new (md_alloc()) Session(_env, _policy, _storage,
                                                  actor, _sessions, tx_size);
        if (matches) {
            _claimed = true;
            auto result = Libc::with_libc([&] {
                return _policy.command("ADMIT", 1, 0, 0, 0, "public-canary");
            });
            if (!result.ok() || result.value != 1) {
                Genode::destroy(*md_alloc(), session);
                return Create_error::DENIED;
            }
        }
        log("SESSION actor=", actor, " active=", _sessions);
        return *session;
    }

public:
    Root(Env &env, Allocator &heap, Writ::Policy &policy, Storage const &storage,
         Session_label reader)
    : Root_component<Session>(env.ep(), heap), _env(env), _policy(policy),
      _storage(storage), _reader(reader) { }
};

struct Control_session : Rpc_object<Writ::Control> {
    Writ::Policy &policy;
    explicit Control_session(Writ::Policy &policy) : policy(policy) { }
    bool revoke() override
    {
        return Libc::with_libc([&] { return policy.command("REVOKE").ok(); });
    }
};

class Control_root : public Root_component<Control_session, Single_client>
{
    Writ::Policy &_policy;
    Session_label const _controller;
    Create_result _create_session(char const *args) override
    {
        if (label_from_args(args) != _controller) return Create_error::DENIED;
        return *new (md_alloc()) Control_session(_policy);
    }
public:
    Control_root(Env &env, Allocator &heap, Writ::Policy &policy, Session_label controller)
    : Root_component<Control_session, Genode::Single_client>(env.ep(), heap),
      _policy(policy), _controller(controller) { }
};

struct Main {
    Libc::Env &env;
    Heap heap { env.ram(), env.rm() };
    Attached_rom_dataspace config { env, "config" };
    Attached_rom_dataspace module { env, "mount.mjs" };
    Attached_rom_dataspace canary { env, "canary" };
    Storage storage { };
    Writ::Policy policy { module.local_addr<char>(), text_size(module) };
    Constructible<Root> root { };
    Constructible<Control_root> control { };

    explicit Main(Libc::Env &env) : env(env)
    {
        storage.length = config.node().attribute_value("size", 0U);
        if (!storage.length || storage.length > Storage::MAX_BYTES ||
            !canary.valid() || storage.length > canary.size()) throw Writ::Javascript::Failed();
        Genode::memcpy(storage.bytes, canary.local_addr<char>(), storage.length);

        char frame[131201];
        char const prefix[] = "WRITFS1\tINIT\t0\t0\t0\t0\t";
        size_t at = sizeof(prefix) - 1;
        Genode::memcpy(frame, prefix, at);
        char const digits[] = "0123456789abcdef";
        for (uint32_t i = 0; i < storage.length; ++i) {
            unsigned char c = static_cast<unsigned char>(storage.bytes[i]);
            frame[at++] = digits[c >> 4];
            frame[at++] = digits[c & 15];
        }
        auto initialized = policy.command(frame, at);
        if (!initialized.ok() || initialized.value != storage.length) throw Writ::Javascript::Failed();
        Session_label const reader = config.node().attribute_value("reader", String<160>());
        Session_label const controller = config.node().attribute_value("controller", String<160>());
        if (reader.length() <= 1 || controller.length() <= 1) throw Writ::Javascript::Failed();
        root.construct(env, heap, policy, storage, reader);
        control.construct(env, heap, policy, controller);
        env.parent().announce(env.ep().manage(*root));
        env.parent().announce(env.ep().manage(*control));
        log("WRITFS READY public-canary bytes=", storage.length,
            " sha256=", initialized.detail,
            " native=genode heap_peak=", writ_qjs_peak_bytes());
    }
};

}

/* A Genode stack slot is 1 MiB including metadata and its unmapped guard.
 * Leave those intact; QuickJS's separate 512 KiB limit fits this usable stack. */
Genode::size_t Libc::Component::stack_size() { return 768U * 1024U; }

void Libc::Component::construct(Libc::Env &env)
{
    try { Libc::with_libc([&] { static Writfs::Main main(env); }); }
    catch (...) { Genode::error("WRITFS STARTUP FAILED"); env.parent().exit(1); }
}
