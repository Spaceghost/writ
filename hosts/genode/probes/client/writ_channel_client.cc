/*
 * writ_channel_client.cc - SCAFFOLDING, NOT A WRIT CLIENT. Genode channel
 * lane, Tasks 2 and 3. A probe component that exercises one Writ channel of the
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
 *           expect_decision=".." expect_reason=".." delay_ms=".."
 *           mode=".." count=".." period_ms=".."/>
 * mode (Task 3) selects the exercise:
 *   "single" (default) the steps above, one request.
 *   "bad_length" requests whose header lengths are 65, 0, and 0xFFFFFFFF
 *     (above the 4 KiB bucket) in turn (GB-006: the shim must answer each with its fixed
 *     refusal record, kind 3, decision 2, reason 256, every other word 0,
 *     and the request's sequence), then the valid request, whose decision
 *     must be the expected one. Any other answer exits 1.
 *   "flood" (GB-008, the unresponsive client) sends the valid request
 *     `count` times, `period_ms` apart (sequence 1, 2, ...), from the
 *     constructor, so its entrypoint never dispatches the result signal: it
 *     never reads a reply. With period_ms 0 the signals are submitted back
 *     to back (the burst run). Then it exits 0. It checks nothing. On
 *     base-linux a signal submitted after the monitor has exited fails in
 *     lx_sendmsg (connection refused) and the client stays blocked there
 *     instead of exiting (observed in writ_bend_monitor_liveness).
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

	enum class Mode { SINGLE, BAD_LENGTH, FLOOD };

	Mode _mode_from_config()
	{
		using Name = String<16>;
		Name const m = _config.node().attribute_value("mode", Name("single"));
		if (m == "bad_length") return Mode::BAD_LENGTH;
		if (m == "flood")      return Mode::FLOOD;
		return Mode::SINGLE;
	}

	Mode const _mode = _mode_from_config();

	/* bad_length: the header lengths sent before the valid request */
	static constexpr uint32_t BAD_LENGTHS[] = { 65, 0, 0xffffffffu };
	enum : unsigned { NUM_BAD = 3 };
	unsigned _step = 0;   /* index of the request in flight */

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

	/*
	 * The shim's transport refusal (Channel.md, "Transport refusal"): exactly
	 * version 1, kind 3, decision 2, reason 256, the rest 0, for sequence seq.
	 */
	bool _is_refusal(uint32_t seq) const
	{
		uint32_t const volatile *r = _result + HEADER_WORDS;
		if (_result[1] != seq) return false;
		if (r[0] != 1 || r[1] != 3 || r[2] != 2 || r[3] != 256) return false;
		for (unsigned i = 4; i < RECORD_WORDS; i++)
			if (r[i] != 0) return false;
		return true;
	}

	void _handle_result()
	{
		if (_mode == Mode::BAD_LENGTH && _step < NUM_BAD) {
			uint32_t const length = BAD_LENGTHS[_step];
			uint32_t const seq    = _step + 1;
			if (_result[0] != RECORD_SIZE) {
				log("client: result signal without a record (length ", _result[0], ")");
				return;
			}
			_dump("result header", _result, HEADER_WORDS);
			_dump("result record", _result + HEADER_WORDS, RECORD_WORDS);
			if (!_is_refusal(seq)) {
				error("client: FAIL request length ", length, " (seq ", seq,
				      ") was not answered by the shim's refusal record");
				_exit(1);
			}
			log("client: refusal for request length ", length, " seq ", seq,
			    ": kind=3 (transport refusal) decision=Denied (2) reason=256 (bad length)");
			_step++;
			if (_step < NUM_BAD) _send(BAD_LENGTHS[_step], _step + 1);
			else                 _send(RECORD_SIZE, _step + 1);
			return;
		}

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
		             && r[3] == _expect_reason && _result[1] == _step + 1;
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

		if (_mode == Mode::FLOOD) {
			uint32_t const count  = _word("count");
			uint32_t const period = _word("period_ms");
			Timer::Connection timer { _env };
			for (uint32_t i = 1; i <= count; i++) {
				_write(RECORD_SIZE, i);
				log("client: flood request ", i, " of ", count,
				    " signalled, reply not read");
				Signal_transmitter(_channel.request_sigh()).submit();
				if (period) timer.msleep(period);
			}
			log("client: flood done, ", count, " requests sent, no reply read");
			_exit(0);
		}

		if (_mode == Mode::BAD_LENGTH) _send(BAD_LENGTHS[0], 1);
		else                           _send(RECORD_SIZE, 1);
	}

	/*
	 * Writes the request record and a header announcing `length` bytes
	 * with sequence `seq`; the length word is written last.
	 */
	void _write(uint32_t length, uint32_t seq)
	{
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
		_request[1] = seq;            /* sequence */
		__atomic_thread_fence(__ATOMIC_RELEASE);
		_request[0] = length;         /* length, written last */
	}

	void _send(uint32_t length, uint32_t seq)
	{
		_write(length, seq);
		_dump("request header", _request, HEADER_WORDS);
		_dump("request record", _request + HEADER_WORDS, RECORD_WORDS);
		log("client: request written (length ", length, " seq ", seq,
		    "), signalling the monitor");
		Signal_transmitter(_channel.request_sigh()).submit();
	}
};


void Component::construct(Genode::Env &env)
{
	static Writ_channel_client::Main main { env };
}
