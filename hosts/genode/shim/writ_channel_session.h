/*
 * writ_channel_session.h - the Genode session type behind a Writ channel.
 * Host transport, not Writ policy: part of the shim's translation unit
 * (included by writ_mem.cc, which serves it) and the interface the client
 * probe opens. See hosts/genode/INVENTORY.md and hosts/genode/effects/
 * Channel.md.
 *
 * GB-010/GB-011. One session is one channel: a 4 KiB request bucket the
 * client writes, a 4 KiB result bucket the client reads, and a signal each
 * way. The four RPC functions below only hand over those dataspace and
 * signal capabilities ("attach these dataspaces, deliver this signal");
 * none carries Writ semantics, and nothing a client does through them
 * decides anything. Requests and results are records in the buckets,
 * decided by the Bend monitor. The session label, prefixed by the parent,
 * is the only identity the server uses (GB-007).
 *
 * Modelled on Report::Session (repos/os/include/report_session/
 * report_session.h): a dataspace and a signal-handler registration.
 */

#ifndef _WRIT_CHANNEL_SESSION_H_
#define _WRIT_CHANNEL_SESSION_H_

#include <base/connection.h>
#include <base/rpc_client.h>
#include <base/signal.h>
#include <dataspace/capability.h>
#include <session/session.h>

namespace Writ_channel {

	using Genode::Dataspace_capability;
	using Genode::Signal_context_capability;
	using Genode::size_t;

	struct Session;
	struct Session_client;
	struct Connection;
}


struct Writ_channel::Session : Genode::Session
{
	static const char *service_name() { return "Writ_channel"; }

	/*
	 * Caps: the session object, the two bucket dataspaces, the request
	 * signal context, and the server's session-object allocation.
	 */
	static constexpr unsigned CAP_QUOTA = 8;

	/* both buckets, the session object, and the allocator's page */
	static constexpr size_t BUCKET_SIZE = 4096;
	static constexpr size_t RAM_QUOTA   = 32*1024;

	using Client = Session_client;

	virtual ~Session() { }

	/* the dataspace the client writes request records into */
	virtual Dataspace_capability request_bucket() = 0;

	/* the dataspace the client reads result records from */
	virtual Dataspace_capability result_bucket() = 0;

	/* the signal context the client submits to after writing a request */
	virtual Signal_context_capability request_sigh() = 0;

	/* registers the client's signal context for "a result landed" */
	virtual void result_sigh(Signal_context_capability) = 0;

	GENODE_RPC(Rpc_request_bucket, Dataspace_capability, request_bucket);
	GENODE_RPC(Rpc_result_bucket, Dataspace_capability, result_bucket);
	GENODE_RPC(Rpc_request_sigh, Signal_context_capability, request_sigh);
	GENODE_RPC(Rpc_result_sigh, void, result_sigh, Signal_context_capability);
	GENODE_RPC_INTERFACE(Rpc_request_bucket, Rpc_result_bucket,
	                     Rpc_request_sigh, Rpc_result_sigh);
};


struct Writ_channel::Session_client : Genode::Rpc_client<Session>
{
	Session_client(Genode::Capability<Session> cap)
	: Genode::Rpc_client<Session>(cap) { }

	Dataspace_capability request_bucket() override {
		return call<Rpc_request_bucket>(); }

	Dataspace_capability result_bucket() override {
		return call<Rpc_result_bucket>(); }

	Signal_context_capability request_sigh() override {
		return call<Rpc_request_sigh>(); }

	void result_sigh(Signal_context_capability cap) override {
		call<Rpc_result_sigh>(cap); }
};


struct Writ_channel::Connection : Genode::Connection<Session>, Session_client
{
	Connection(Genode::Env &env, Label const &label)
	:
		Genode::Connection<Session>(env, label, Ram_quota { Session::RAM_QUOTA },
		                            Args()),
		Session_client(cap())
	{ }
};

#endif /* _WRIT_CHANNEL_SESSION_H_ */
