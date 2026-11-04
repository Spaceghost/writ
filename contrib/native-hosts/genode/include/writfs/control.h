#ifndef WRIT_GENODE_CONTROL_H
#define WRIT_GENODE_CONTROL_H

#include <base/connection.h>
#include <base/rpc_client.h>
#include <session/session.h>

namespace Writ {

/* The supervisor routes this administrative endpoint separately from data.
 * It cannot create grants or submit arbitrary interpreter frames.
 */
struct Control : Genode::Session {
    static char const *service_name() { return "Writ_control"; }
    static constexpr unsigned CAP_QUOTA = 2;
    virtual bool revoke() = 0;
    GENODE_RPC(Rpc_revoke, bool, revoke);
    GENODE_RPC_INTERFACE(Rpc_revoke);
};

struct Control_connection : Genode::Connection<Control>, Genode::Rpc_client<Control> {
    explicit Control_connection(Genode::Env &env)
    : Genode::Connection<Control>(env, Label("control"), Ram_quota { 8192 }, Args()),
      Genode::Rpc_client<Control>(cap()) { }
    bool revoke() override { return call<Rpc_revoke>(); }
};

}
#endif
