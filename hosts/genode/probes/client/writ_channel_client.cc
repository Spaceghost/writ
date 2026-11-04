/*
 * writ_channel_client.cc - SCAFFOLDING, NOT A WRIT CLIENT. Genode channel
 * lane, Task 2. A probe component that exercises one Writ channel of the
 * monitor component writ_bend_monitor: it holds no authority, makes no Writ
 * decision, and its records are synthetic. It is C++ because a Genode
 * session client is C++ (Genode::Connection, Rpc_client); it is not part
 * of the monitor component and is not the shim (GB-006 counts authored C++
 * in the monitor only).
 *
 * Steps: open a Writ_channel session labelled "channel" (init prefixes the
 * label with this child's name; the monitor's <writ_channel><policy> maps
 * that prefix to a route subject), attach both buckets (the result bucket
 * read-only), register the result signal, write one 64-byte request record
 * at offset 16 of the request bucket and its header (length 64, sequence
 * 1), submit the request signal, and wait. On the result signal it prints
 * both records as hex, the decision, and exits 0 when the decision and
 * reason are the ones its config expects, 1 otherwise.
 *
 * Config (all words decimal; the record layout is hosts/genode/effects/
 * Channel.md):
 *   <config session=".." expected_session=".." claimed_subject=".."
 *           expect_decision=".." expect_reason=".." delay_ms=".."/>
 * delay_ms (default 0) makes the client sleep on a Timer session before it
 * writes, so the monitor's Genode.take is already parked when the signal
 * arrives; with 0 the request is usually queued before Bend first takes.
 * The plan words (epochs 1/2/3, invocation 99, report 10 v1, summary 20 v1)
 * are examples/Scenario.bend's report-to-summary plan. claimed_subject is a
 * body word the monitor must not use as identity.
 */

#include <base/attached_rom_dataspace.h>
#include <base/component.h>
#include <base/local.h>
#include <base/log.h>
#include <base/signal.h>
#include <timer_session/connection.h>
#include <util/string.h>
#include <writ_channel_session.h>

using namespace Genode;

namespace Writ_channel_client { struct Main; }

struct Writ_channel_client::Main
{
	enum : unsigned { HEADER_WORDS = 4, RECORD_WORDS = 16, RECORD_SIZE = 64 };

	using Local_rm = Genode::Local::Constrained_region_map;

	Env &_env;

	Main(Main const &) = delete;
	Main &operator = (Main const &) = delete;

	Attached_rom_dataspace _config { _env, "config" };

	Writ_channel::Connection _channel { _env, "channel" };

	static Local_rm::Attach_attr _attr(bool writeable)
	{
		return { .size = { }, .offset = { }, .use_at = { }, .at = { },
		         .executable = false, .writeable = writeable };
	}

	Local_rm::Result _request_att { _env.rm().attach(_channel.request_bucket(), _attr(true)) };
	Local_rm::Result _result_att  { _env.rm().attach(_channel.result_bucket(),  _attr(false)) };

	static uint32_t volatile *_ptr(Local_rm::Result &r)
	{
		return r.convert<uint32_t volatile *>(
			[&] (auto &a)         { return (uint32_t volatile *)a.ptr; },
			[&] (Local_rm::Error)         { return (uint32_t volatile *)nullptr; });
	}

	uint32_t volatile *_request = _ptr(_request_att);
	uint32_t volatile *_result  = _ptr(_result_att);

	Signal_handler<Main> _result_handler { _env.ep(), *this, &Main::_handle_result };

	uint32_t _word(char const *attr) {
		return _config.node().attribute_value(attr, uint32_t(0)); }

	uint32_t const _expect_decision = _word("expect_decision");
	uint32_t const _expect_reason   = _word("expect_reason");

	static void _dump(char const *what, uint32_t const volatile *words, unsigned n)
	{
		for (unsigned line = 0; line < n; line += 4) {
			String<128> text { };
			for (unsigned i = line; i < line + 4 && i < n; i++) {
				uint32_t const w = words[i];
				for (unsigned b = 0; b < 4; b++)
					text = String<128>(text, Hex(uint8_t(w >> (8*b)), Hex::OMIT_PREFIX, Hex::PAD), " ");
			}
			log("client: ", what, " +", Hex(line*4, Hex::PREFIX, Hex::PAD), ": ", text);
		}
	}

	[[noreturn]] void _exit(int code)
	{
		_env.parent().exit(code);
		sleep_forever();
	}

	void _handle_result()
	{
		if (_result[0] != RECORD_SIZE) {
			log("client: result signal without a record (length ", _result[0], ")");
			return;
		}
		uint32_t const volatile *r = _result + HEADER_WORDS;
		_dump("result header", _result, HEADER_WORDS);
		_dump("result record", r, RECORD_WORDS);
		char const *name = r[2] == 1 ? "Committed" : r[2] == 2 ? "Denied" : "unknown";
		log("client: decision=", name, " (", r[2], ") reason=", r[3],
		    " route_subject=", r[4], " session=", r[5], " seq=", _result[1]);

		bool const ok = r[0] == 1 && r[1] == 2 && r[2] == _expect_decision
		             && r[3] == _expect_reason;
		if (ok) {
			log("client: PASS decision ", r[2], " reason ", r[3], " as expected");
			_exit(0);
		}
		error("client: FAIL expected decision ", _expect_decision, " reason ",
		      _expect_reason, ", observed decision ", r[2], " reason ", r[3]);
		_exit(1);
	}

	Main(Env &env) : _env(env)
	{
		if (!_request || !_result) {
			error("client: could not attach the channel's buckets");
			_exit(1);
		}
		_channel.result_sigh(_result_handler);

		if (uint32_t const delay = _word("delay_ms")) {
			Timer::Connection timer { _env };
			log("client: waiting ", delay, " ms before writing");
			timer.msleep(delay);
		}

		uint32_t const record[RECORD_WORDS] = {
			1,                          /* version                        */
			1,                          /* kind: commit request           */
			_word("session"),           /* session id                     */
			_word("expected_session"),  /* expected session revision      */
			1, 2, 3,                    /* graph, policy, authority epoch */
			99,                         /* invocation                     */
			10, 1,                      /* source: report object, version */
			20, 1,                      /* destination: summary, version  */
			_word("claimed_subject"),   /* body claim, untrusted          */
			0, 0, 0                     /* reserved                       */
		};
		for (unsigned i = 0; i < RECORD_WORDS; i++)
			_request[HEADER_WORDS + i] = record[i];
		_request[1] = 1;              /* sequence */
		__atomic_thread_fence(__ATOMIC_RELEASE);
		_request[0] = RECORD_SIZE;    /* length, written last */

		_dump("request header", _request, HEADER_WORDS);
		_dump("request record", _request + HEADER_WORDS, RECORD_WORDS);
		log("client: request written, signalling the monitor");
		Signal_transmitter(_channel.request_sigh()).submit();
	}
};


void Component::construct(Genode::Env &env)
{
	static Writ_channel_client::Main main { env };
}
