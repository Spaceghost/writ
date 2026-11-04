#include <base/allocator_avl.h>
#include <base/attached_rom_dataspace.h>
#include <base/component.h>
#include <base/heap.h>
#include <base/log.h>
#include <file_system_session/connection.h>
#include <writfs/control.h>

namespace Test {

using namespace Genode;
namespace Fs = File_system;

char const canary[] = "Writ native Genode public canary\n";
struct Failed { };

void check(bool condition, char const *name)
{
    if (!condition) { error("FAIL ", name); throw Failed(); }
    log("PASS ", name);
}

struct Result {
    bool success { false };
    bool unchanged { true };
    size_t length { 0 };
    char bytes[256] { };
};

struct Acknowledgements {
    Signal_receiver receiver { };
    Signal_context context { };
    Signal_context_capability signal { receiver.manage(context) };
    ~Acknowledgements() { receiver.dissolve(context); }
};

struct Main {
    Env &env;
    Attached_rom_dataspace config { env, "config" };
    Heap heap { env.ram(), env.rm() };
    Allocator_avl allocator { &heap };
    Acknowledgements acknowledgements { };

    bool route_denied(char const *service, char const *arguments)
    {
        /* Genode 26.08's convenience Connection intentionally stops forever
         * on denial. Use the nonfatal native result API for negative probes. */
        Parent::Client client { };
        Id_space<Parent::Client>::Element id(client, env.id_space());
        bool denied = false;
        env.try_session(service, id.id(), Parent::Session_args(arguments), Affinity()).with_result(
            [&] (Session_capability) { env.close(id.id()); },
            [&] (Session_error error) { denied = error == Session_error::DENIED; });
        return denied;
    }

    void no_canary_rom()
    {
        check(route_denied("ROM", "label=\"canary\", ram_quota=8192, cap_quota=4"),
              "supervisor denies direct canary ROM access");
    }

    Result transfer(Fs::Connection &fs, Fs::Node_handle handle,
                    Fs::Packet_descriptor::Opcode op, size_t buffer_size,
                    size_t count, Fs::seek_off_t offset, unsigned malformed = 0)
    {
        auto &tx = *fs.tx();
        fs.sigh(acknowledgements.signal);
        auto buffer = tx.alloc_packet(buffer_size);
        char *data = tx.packet_content(buffer);
        for (size_t i = 0; i < buffer_size; ++i) data[i] = char(0x5a);
        Fs::Packet_descriptor descriptor = buffer;
        if (malformed == 1) descriptor = Fs::Packet_descriptor(-1, buffer_size);
        if (malformed == 2)
            descriptor = Fs::Packet_descriptor(off_t(tx.ds_size() - 1), ~size_t(0));
        Fs::Packet_descriptor request(descriptor, handle, op, count, offset);
        tx.submit_packet(request);
        while (!tx.ack_avail()) acknowledgements.receiver.wait_for_signal();
        auto reply = tx.get_acked_packet();
        Result result;
        result.success = reply.succeeded();
        result.length = reply.length();
        check(reply.offset() == request.offset() && reply.size() == request.size()
              && reply.handle().value == handle.value && reply.operation() == op,
              "packet acknowledgement preserves identity");
        for (size_t i = 0; i < buffer_size; ++i)
            if (data[i] != char(0x5a)) result.unchanged = false;
        size_t n = min(min(result.length, buffer_size), sizeof(result.bytes));
        for (size_t i = 0; i < n; ++i) result.bytes[i] = data[i];
        /* Return only our actual allocation, never a deliberately forged
         * descriptor echoed by the server in a negative probe. */
        tx.release_packet(buffer);
        return result;
    }

    void denied(char const *label)
    {
        no_canary_rom();
        check(route_denied("Writ_control", "ram_quota=8192, cap_quota=4"),
              "unknown component has no administrative route");
        Fs::Connection fs(env, allocator, label, false, 32768);
        bool denied = false;
        try { fs.dir("/", false); } catch (Fs::Permission_denied) { denied = true; }
        check(denied, "unknown native session cannot open root");
        denied = false;
        try { fs.node("/data"); } catch (Fs::Lookup_failed) { denied = true; }
        check(denied, "unknown native session receives no object metadata");
        auto read = transfer(fs, Fs::Node_handle { 1 }, Fs::Packet_descriptor::READ, 64, 64, 0);
        check(!read.success && !read.length && read.unchanged,
              "forged handle returns no bytes and leaves shared memory unchanged");
    }

    void reader()
    {
        no_canary_rom();
        Fs::Connection fs(env, allocator, "/", true, 131072);
        auto root = fs.dir("/", false);
        auto file = fs.file(root, "data", Fs::READ_ONLY, false);
        auto st = fs.status(file);
        check(st.size == sizeof(canary) - 1 && st.rwx.readable && !st.rwx.writeable
              && !st.rwx.executable && st.type == Fs::Node_type::CONTINUOUS_FILE,
              "immutable file has exact size and read-only attributes");
        check(fs.num_entries(root) == 1, "directory contains exactly one entry");
        auto listing = transfer(fs, root, Fs::Packet_descriptor::READ,
                                sizeof(Fs::Directory_entry), sizeof(Fs::Directory_entry), 0);
        Fs::Directory_entry entry { Fs::Node_type::CONTINUOUS_FILE, { true, false, false }, { "" } };
        check(listing.success && listing.length == sizeof(entry), "native directory packet succeeds");
        memcpy(&entry, listing.bytes, sizeof(entry));
        check(!strcmp(entry.name.buf, "data") && entry.type == Fs::Node_type::CONTINUOUS_FILE,
              "directory exposes the sole canonical name");
        auto read = transfer(fs, file, Fs::Packet_descriptor::READ, 64, 64, 0);
        check(read.success && read.length == sizeof(canary) - 1
              && !memcmp(read.bytes, canary, sizeof(canary) - 1), "native packet read returns exact canary");
        read = transfer(fs, file, Fs::Packet_descriptor::READ, 8, 8, 5);
        check(read.success && read.length == 8 && !memcmp(read.bytes, canary + 5, 8), "native offset read is exact");
        read = transfer(fs, file, Fs::Packet_descriptor::READ, 64, 64, sizeof(canary) - 1);
        check(read.success && !read.length && read.unchanged, "EOF returns zero without touching payload");
        read = transfer(fs, file, Fs::Packet_descriptor::WRITE, 64, 64, 0);
        check(!read.success && !read.length && read.unchanged, "write packet is rejected");
        read = transfer(fs, file, Fs::Packet_descriptor::READ, 8, 9, 0);
        check(!read.success && !read.length && read.unchanged, "packet count exceeding buffer is rejected");
        read = transfer(fs, file, Fs::Packet_descriptor::READ, 8, 8, 0x100000000ULL);
        check(!read.success && !read.length && read.unchanged, "native offset is checked before U32 narrowing");
        read = transfer(fs, file, Fs::Packet_descriptor::READ, 65537, 65537, 0);
        check(!read.success && !read.length && read.unchanged, "over-limit read is rejected");
        read = transfer(fs, file, Fs::Packet_descriptor::READ, 64, 64, 0, 1);
        check(!read.success && !read.length && read.unchanged, "negative shared-memory descriptor is rejected");
        read = transfer(fs, file, Fs::Packet_descriptor::READ, 64, 8, 0, 2);
        check(!read.success && !read.length && read.unchanged, "overflowing shared-memory descriptor is rejected");

        bool denied = false;
        try { fs.file(root, "data", Fs::WRITE_ONLY, false); }
        catch (Fs::Permission_denied) { denied = true; }
        check(denied, "native write-open is denied even on writeable session request");
        denied = false;
        try { fs.file(root, "../data", Fs::READ_ONLY, false); }
        catch (Fs::Lookup_failed) { denied = true; }
        check(denied, "path traversal alias is rejected");
        char const embedded_name[] { 'd', 'a', 't', 'a', 0, 'x', 0 };
        denied = false;
        try { fs.file(root, Fs::Name(embedded_name, sizeof(embedded_name)), Fs::READ_ONLY, false); }
        catch (Fs::Lookup_failed) { denied = true; }
        check(denied, "embedded-NUL native name is rejected");
        char const truncated_name[] { 'd', 'a', 't', 'a' };
        denied = false;
        try { fs.file(root, Fs::Name(truncated_name, sizeof(truncated_name)), Fs::READ_ONLY, false); }
        catch (Fs::Lookup_failed) { denied = true; }
        check(denied, "unterminated native name is rejected");
        denied = false;
        try { fs.truncate(file, 0); } catch (Fs::Permission_denied) { denied = true; }
        check(denied, "native truncate is rejected");

        auto metadata = fs.node("/data");
        read = transfer(fs, metadata, Fs::Packet_descriptor::READ, 64, 64, 0);
        check(!read.success && !read.length && read.unchanged, "stat-only handle cannot read payload");
        fs.close(metadata);
        read = transfer(fs, metadata, Fs::Packet_descriptor::READ, 64, 64, 0);
        check(!read.success && !read.length && read.unchanged, "closed handle remains invalid");
        auto next = fs.node("/data");
        check(next.value != metadata.value, "native handles do not reuse retired Bend identities");
        fs.close(next);

        {
            Allocator_avl second_allocator(&heap);
            Fs::Connection second(env, second_allocator, "/", false, 32768);
            denied = false;
            try { second.dir("/", false); } catch (Fs::Permission_denied) { denied = true; }
            check(denied, "second session cannot inherit admitted invocation");
            read = transfer(second, file, Fs::Packet_descriptor::READ, 64, 64, 0);
            check(!read.success && !read.length && read.unchanged, "handle ID is local to its native session");
        }

        unsigned long held[30] { };
        for (unsigned i = 0; i < 30; ++i) held[i] = fs.file(root, "data", Fs::READ_ONLY, false).value;
        denied = false;
        try { fs.file(root, "data", Fs::READ_ONLY, false); } catch (Fs::No_space) { denied = true; }
        check(denied, "native handle table is bounded at 32");
        for (auto id : held) fs.close(Fs::Node_handle { id });

        Writ::Control_connection control(env);
        check(control.revoke(), "trusted controller revokes through Bend");
        read = transfer(fs, file, Fs::Packet_descriptor::READ, 64, 64, 0);
        check(!read.success && !read.length && read.unchanged, "retained handle cannot read after revocation");
        denied = false;
        try { fs.status(file); } catch (Fs::Unavailable) { denied = true; }
        check(denied, "revoked session receives no metadata");
        denied = false;
        try { fs.file(root, "data", Fs::READ_ONLY, false); } catch (Fs::Permission_denied) { denied = true; }
        check(denied, "new opens fail after revocation");
        fs.close(file);
        fs.close(root);
        check(true, "revoked handles still close cleanly");
    }

    explicit Main(Env &env) : env(env)
    {
        auto role = config.node().attribute_value("role", String<32>());
        if (role == "reader") reader();
        else if (role == "stranger") denied("/");
        else if (role == "forger") denied("reader -> /");
        else throw Failed();
        log("WRITFS NATIVE PASS role=", role);
        env.parent().exit(0);
    }
};

}

void Component::construct(Genode::Env &env)
{
    try { static Test::Main main(env); }
    catch (...) { Genode::error("WRITFS NATIVE FAIL"); env.parent().exit(1); }
}
