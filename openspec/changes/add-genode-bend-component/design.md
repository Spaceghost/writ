# Bend runtime as a Genode component: design

## Context

Today `bend Tests.bend -o tests-native` produces a Linux executable. Genode
components are built by Genode's build system against its libc and base
libraries, and they talk to other components through typed session RPC. The
runtime surface the generated C needs is known (BEND-RUNTIME.md); what Genode's
libc provides for each row has not been checked against the pinned 26.08 source.
Older community reports describe signal support as rudimentary, which matters
because the runtime installs `SIGSEGV`/`SIGBUS` handlers on an alternate stack.

## Decisions

### Compile the generated C inside Genode's build, do not load a Linux ELF

The generated C file is the component's source. It is compiled with Genode's
toolchain against Genode's libc, not run through a Linux-ABI compatibility
layer. This keeps the runtime's host calls on Genode's own implementations and
makes every missing primitive a link or startup failure rather than a silent
emulation.
GCC 14.2 lacks statement-level `musttail`, so the generated translation unit
is compiled with a pinned clang while linking, `ld.lib.so`, and libc stay on
the Genode toolchain; this stays open until Genode moves to GCC 15 or later.

### Satisfy the runtime profile row by row, with the profile's substitutes

For each row of the runtime inventory the port records one of: supplied by
Genode's libc; supplied by a profile substitute; or missing. Expected outcomes
to verify, not assumptions: threads through libc pthreads; anonymous memory
through libc `mmap` backed by RAM dataspaces; monotonic time through the Timer
session; the self-pipe through libc `pipe` and `select`. The fault path is the
likely gap: if libc signal delivery cannot reach the runtime's handler, the
component uses the profile's halting substitute, where a page fault reported to
the parent terminates the component and the supervisor records it. Resuming
after a fault is never an option.

### Effects are Bend defs with C twins calling one shim

Three effect families are authored in Bend:

| Effect | C twin calls | Genode session |
| --- | --- | --- |
| `Genode.log(text)` | `writ_shim_log` | LOG |
| `Genode.now()`, `Genode.sleep(ms)` | `writ_shim_now_ms`, `writ_shim_sleep_ms` | Timer |
| `Genode.take()` | `writ_shim_take`, which blocks on an `io_work` helper thread until a request is queued | Writ channel: the client's request bucket |
| `Genode.put(channel_id, record)` | `writ_shim_put` | Writ channel: the client's result bucket |

The shim is one C++ translation unit exporting `extern "C"` functions. It owns
the Genode environment, the channel objects, and a bounded request queue. It
contains no policy: a request record is delivered to Bend as an opaque, bounded
term with the authenticated channel identity the parent route established, and
Bend decides. The shim's source, size, and reviewed obligations are listed in
the trust inventory that AGENTS.md requires for authored binding code.

### Writ is data-centric above the kernel: channels, not procedure calls

Genode's kernel-level mechanism is RPC objects, dataspaces, and signals, and
nothing above it can avoid using them as the transport. What Writ exposes on
top is not a procedure interface. A **Writ channel** is a pair of bounded,
typed buckets the monitor owns for one descriptor: a request bucket the client
writes a record into and a result bucket the client reads. Each bucket is a RAM
dataspace holding one record slot that the next record overwrites; Genode RAM
dataspaces have no read-only capability, so the client can map both writable,
and the shim copies the request once at take and never reads the result
bucket. A Genode signal tells the other party that a record landed. The Genode
object behind the channel exists for identity and lifetime (GB-010); it has no
method surface beyond "attach these dataspaces, deliver this signal."

This matches the rest of Writ: WritFS already frames interaction as names,
views, jobs, and framed control records, and transfer admission is a decision
over records. A client does not call `commit`; it writes a request record that
names an exact plan, and later reads a result record that carries a decision
and a write intent or a denial reason. "Search atop, not RPC below": clients
query buckets and views; the monitor materializes.

### The channel is served from the event loop

Bend's loop runs effects one at a time and parks blocking ones. `Genode.take`
runs `writ_shim_take` on a runtime `io_work` helper thread, which blocks on the
shim's semaphore until a client's request signal has queued an entry; the
runtime's own completion pipe then wakes the loop (the libc wakeup the event
loop already uses). The shim serves the sessions and signals on its own
entrypoint, because libc keeps the main entrypoint for I/O signals while Bend
waits. The monitor's `main` is a
fuel-bounded loop: take, decide through `DataOS`, put. One record is processed
at a time, which is what the backplane's "one authoritative state at commit"
rule requires anyway. A record larger than the bucket's bound is never copied
into Bend; the shim counts it and the client sees a bounded-size denial record.

### Binding records from `Genode.take`

Example: client `writ_client_r` opens a Writ channel; init prefixes its
session label with `writ_client_r ->`, the monitor's config maps that prefix to
route subject 1, and every record taken from that session reaches Bend as
`Request{channel: 1, subject: 1, ...}`, whatever the body claims
(`verification/genode-channel-base-linux.txt:418-420`, run 1). Current gap:
`Monitor.bend` does not import `HostBinding.bend` (`Monitor.bend:1-12`); the
table below is the construction a port must perform, not one the monitor
performs today, and no HostBinding vector has been replayed on the host.
Line numbers refer to commit c380947.

**Identity at take time (GB-007).** `Genode.take` hands Bend two words that are
not record words (`hosts/genode/effects/Genode.bend:49-60`,
`hosts/genode/effects/Channel.md:106-108`):

- the route subject: `Channel_root::_subject` returns the `subject` attribute
  of the best-matching `<policy>` under `<writ_channel>`, and 0 for a
  `<default-policy>`, a suffix-only policy, or no match
  (`hosts/genode/shim/writ_mem.cc:1174-1188`); `_create_session` refuses
  subject 0 (`writ_mem.cc:1209-1214`) and fixes the word in the channel object
  (`Channel::subject`, `writ_mem.cc:1077`, constructed at `:1231`). A client
  signal enqueues `{c->id, c->subject, false}` (`writ_mem.cc:1147-1148`), and
  `writ_shim_take` copies that entry's words out (`writ_mem.cc:1373-1374`).
  The config is libc's read-only ROM, never updated (`writ_mem.cc:962-966`);
- the object identity: the channel id, `_channel_next_id++` at session
  creation (`writ_mem.cc:1120`, `:1222`), never reused.

The 16 record words are copied separately (`writ_mem.cc:1367-1368`); no record
word contributes to either identity, and the body's `claimed_subject` is logged
as untrusted and never used (`Monitor.bend:29-33`; run 4,
`genode-channel-base-linux.txt:466-468`). The session label itself
(`Channel::label`, `writ_mem.cc:1078`) is logged but not handed to Bend.

**Mapping onto `HostBinding.bend`.**

| HostBinding field | Source on Genode today |
| --- | --- |
| `Route.subject` (`HostBinding.bend:55-56`) | `Request.subject` via `route_caller` (`Monitor.bend:311-313`): word 1 is the Scenario reader, word 2 the synthetic S (`Monitor.bend:93-124`) |
| `Route.parent` | init, implicit: the `<policy>` table is the parent's record (`Channel.md:162-185`); no word |
| `Route.child` | gap: the client's domain is known only as the label prefix, which Bend does not receive |
| `Route.service`, `Object.service` (`HostBinding.bend:40-41`) | constant: one service, `Writ_channel`; no service word reaches Bend |
| `Object.id` | the channel id (`Request.channel`) |
| `Object.owner` | the route subject fixed at session creation (`writ_mem.cc:1209`, `:1231`) |
| `Object.generation`, `Alias.generation` (`HostBinding.bend:48-49`) | constant 0: ids are never reused and a close removes the binding (`Monitor.bend:227-230`), so no generation is carried or bumped |
| `Object.kind` | one channel stands for both the Session and the Descriptor: `open_descriptor` mounts and opens in one step (`Monitor.bend:436-439`) |
| `Alias` (holder, id) | gap: the session capability held by the client is not visible to Bend; no alias table exists |
| `Binding.object`, `Binding.handle` (`HostBinding.bend:72-75`) | monitor `Binding{channel, subject, frontend, descriptor}` (`Monitor.bend:144-145`), made in `with_opened` from `Request.channel`, `Request.subject`, and the descriptor `Frontend.open` returned (`Monitor.bend:443-451`); at most `max_channels` = 8 (`Monitor.bend:152-153`; reason 7 at `:457`); a bound channel with another subject is refused (reason 8, `Monitor.bend:461-466`) |
| `Quota` (`HostBinding.bend:61-62`) | the session's `ram_quota`/`cap_quota`, refused by the shim before Bend (`writ_mem.cc:1194-1207`); not a Bend record |
| `Delegation` (`HostBinding.bend:69-70`) | none |
| `State.revision` | none; each binding has its own `Frontend.empty()` state (`Monitor.bend:437`), so the descriptor id is 2 on every channel (runs 1, 2, 4) |
| epochs | not binding fields: the body's plan stamp is compared with the session plan (`Monitor.bend:423`); the Scenario's epochs are synthetic constants (`Monitor.bend:21-27`) |

A close event (route subject 0, `writ_mem.cc:1336-1344`) is classified once
(`Monitor.bend:275-276`) and drops the binding; it is the only destruction the
channel delivers.

**Vectors a Genode run must replay for GA-005 and GA-008.** Names are the
`VECTOR` ids in `verification/host-binding-vectors.txt` and their emitting lines
in `HostBindingTests.bend`; two required properties are `valid` checks with no
vector line. "Analogue" means a Genode run exercises the corresponding monitor
path; none feeds the vector's inputs or compares its normalized outcome.
GA-009 (`openspec/changes/add-genode-capability-adoption/specs/genode-capability-adoption/spec.md:174`)
requires a host port to replay all 41 vectors in
`verification/host-binding-vectors.txt`. Inclusion rule for this table: every
GA-005 and GA-008 vector and `valid` check, plus the GA-002 route vectors
(all four) and GA-003-1, the open vector, that they rest on. The other vectors
(GA-001, GA-003-2 to GA-003-4, GA-004, GA-006, GA-007, GA-011) are also owed
and are not mapped here.

| Vector or check | What it asserts | Monitor path | Genode run today |
| --- | --- | --- | --- |
| GA-002-1 (vectors:3, tests:847) | holder authorized through the recorded route | `route_caller`, `with_opened` | analogue: run 1, `accept` (`genode-channel-base-linux.txt:418-420`) |
| GA-003-1 (vectors:7, tests:868) | open from the routed Session | `open_descriptor` | analogue: run 1 (descriptor=2) |
| GA-002-2 (vectors:4, tests:855) | label suffix cannot name the subject | `_subject` suffix-only rule | analogue: scratch suffix run, removed after (`genode-channel-base-linux.txt:482-486`; script deleted; not reproducible); run 4 for a body claim |
| GA-002-3 (vectors:5, tests:857) | unrecorded route denied | `_create_session` subject 0 | gap: shares the subject-0 refusal with the scratch suffix run (`writ_mem.cc:1209-1214`); no run without a matching policy |
| GA-002-4 (vectors:6, tests:862) | a route on another service, withdrawn, does not authorize the holder | none (one service; config never updated) | gap |
| GA-005-1 (vectors:19, tests:927) | possession without a delegation record denied | none (no alias holder) | gap |
| GA-005-2 (vectors:20, tests:930) | non-holder denied UnknownAlias | none | gap |
| GA-005-3, GA-005-4 (vectors:21-22, tests:932, 939) | recorded delegatee accepted within scope | none (no delegation) | gap |
| GA-005-5 (vectors:23, tests:942) | delegator's route withdrawn | none (config never updated) | gap |
| GA-005-6 (vectors:24, tests:945) | delegation to a domain routed as another subject denied | none | gap |
| GA-005-7 (vectors:25, tests:950) | delegatee routed as another subject denied at use (`holder_authorized`, `acts_for_owner`, `HostBinding.bend:768-834`) | reason 8 is the nearest, MonitorCheck on Linux only (`genode-channel-base-linux.txt:501`, `:505`) | gap |
| GA-008-1 (vectors:32, tests:1000) | stale binding revision denied | none (no binding revision) | gap |
| GA-008-2 (vectors:33, tests:1002) | Frontend rejects, state unchanged | `with_opened` reason 5 returns the state unbound; the binding is made only in the `Changed` arm (`Monitor.bend:443-451`) | analogue: run 3, `routed_s` (`genode-channel-base-linux.txt:450-452`, descriptor=0) |
| GA-008-3 (vectors:34, tests:1009) | invalid input state denied | none (no `valid` over monitor state) | gap |
| check "GA-008 two objects bound to one Frontend handle are rejected by valid" (tests:1012) | unique handle per binding (`bindings_valid`, `HostBinding.bend:358-367`) | none: per-channel Frontend states | gap |
| check "GA-008 two uncopied aliases for one live object are rejected by valid" (tests:1014) | single minted alias (`mints_valid`, `HostBinding.bend:478-492`) | none (no alias table) | gap |

The Task 3 runs (`bad_length`, `liveness`, `queue`, `dead_client`;
`genode-channel-base-linux.txt:612`, `:630`, `:662`, `:860`) exercise transport
bounds, liveness, and the close event (`:638`), not these vectors.

**Not yet reachable through the channel.** Delegation: there is no delegation
record and a session capability passed to another domain is not observed
(GA-010). Revocation at route change: the `<policy>` table is read at
session creation from a ROM that is never updated, so a reroute cannot reach
Bend; `holder_authorized` names that update and the withdrawal of delegated endpoints as a host obligation
(`HostBinding.bend:821-826`). Generation turnover: channel ids are never
reused and no generation is carried, and the monitor is not restarted with a
new generation (`Monitor.bend:37-42`; GB-008 gap).

### base-linux first, base-hw second, and evidence stays separate

`base-linux` gives fast iteration with Genode's socket-based capabilities and
seccomp. `base-hw` under QEMU is the native reference. The corpus must pass on
both, recorded separately, before the Writ session is served on either. No
GPU: `!` calls run on the CPU pool and are recorded as such.

### What this change does not do

It does not create the worker topology, seal artifacts, confine effects, or
prove revocation. Those are the Genode host change's own tasks 1.4 through 2.4.
It makes the monitor exist and speak.

## Failure and denial behavior

A missing libc primitive fails the build or startup. A corpus mismatch fails
qualification for that base. A fault terminates the component and is recorded
by the supervisor; the monitor is restarted with a new generation per the host
contract. A request that exceeds the shim's bound is dropped before parsing,
counted, and answered with the shim's fixed transport refusal record. An alien effect halts, as on Linux.

## Evidence before claiming implementation

- Genode commit, toolchain, run script, and component build hashes pinned.
- Per-row runtime profile outcome table for `base-linux` and `base-hw`.
- Corpus and example output captured from each base's log.
- The shim's trust inventory: file list, exported functions, line count,
  reviewer, and the sessions it may open.
- A served request round trip on each base, with a forged-identity request
  shown denied by Bend, not by the shim.
