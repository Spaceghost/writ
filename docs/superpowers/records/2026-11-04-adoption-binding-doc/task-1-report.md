# Report: adoption-binding-doc, Tasks 1 and 2

Branch `lane/adoption-binding-doc`, base c380947. Text-only: no `.bend`,
`hosts/`, `scripts/`, or `verification/` file changed; no manifest regenerated;
no push.

## Task 1: section "Binding records from `Genode.take`"

Added to `openspec/changes/add-genode-bend-component/design.md` directly after
"The channel is served from the event loop". It leads with the run-1 example
and the gap: `Monitor.bend` does not import `HostBinding.bend`, so the mapping
is the construction a port must perform, and no vector is replayed on the host.

Citations, with the line each points at (checked with `sed -n` on this tree):

| Citation | Line content |
| --- | --- |
| `hosts/genode/effects/Genode.bend:49-60` | comment "`channel` and `subject` are NOT from the record body" and `type Request` |
| `hosts/genode/effects/Channel.md:106-108` | "`Genode.take` answers a `Request` whose first two fields are not record words" |
| `hosts/genode/effects/Channel.md:162-185` | "## Route subject (GB-007)" with the `<policy label_prefix=.. subject=..>` example |
| `writ_mem.cc:962-966` | libc's config, "a read-only view of a ROM that is never updated here" |
| `writ_mem.cc:1077` / `:1078` | `uint32_t const subject;` / `Session_label const label;` in `struct Channel` |
| `writ_mem.cc:1120`, `:1222` | `_channel_next_id = 1`; `id = _channel_next_id++` |
| `writ_mem.cc:1147-1148` | ring entry `{ c->id, c->subject, false }` in `_channel_signalled` |
| `writ_mem.cc:1174-1188` | `Channel_root::_subject` (default-policy 0, suffix-only 0, `subject` attribute) |
| `writ_mem.cc:1194-1207` | `ram_quota` check (INSUFFICIENT_RAM) and the cap-quota comment |
| `writ_mem.cc:1209-1214` | `_subject(label)` and the DENIED refusal for subject 0 |
| `writ_mem.cc:1231` | `new (md_alloc()) Channel(_env, _ep, id, subject, label)` |
| `writ_mem.cc:1336-1344` | close entry: record words 0, `*subject = CHANNEL_SUBJECT_CLOSED` |
| `writ_mem.cc:1367-1368` | record word copy loop |
| `writ_mem.cc:1373-1374` | `*channel = e.id; *subject = e.subject;` in `writ_shim_take` |
| `Monitor.bend:1-12` | imports (no HostBinding) |
| `Monitor.bend:21-27` | SYNTHETIC AUTHORITY header (Scenario epochs) |
| `Monitor.bend:29-33` | identity from `Request.subject`; `claimed_subject` untrusted |
| `Monitor.bend:37-42` | fuel comment: restart with a new generation not configured |
| `Monitor.bend:93-124` | route subject words 0/1/2 and synthetic `other_caller` |
| `Monitor.bend:144-145` | `Binding{channel, subject, frontend, descriptor}` |
| `Monitor.bend:152-153` | `max_channels` = 8 |
| `Monitor.bend:227-230` | `close_channel` |
| `Monitor.bend:275-276` | `classify` |
| `Monitor.bend:311-313` | `route_caller` |
| `Monitor.bend:423` | `Transfer.Plan.equal(body_plan(request), ...)` |
| `Monitor.bend:436-439`, `:437` | `open_descriptor`; `+state = Frontend.empty()` |
| `Monitor.bend:443-451`, `:446-447` | `with_opened`; Rejected -> reason 5, state unbound |
| `Monitor.bend:457` | reason 7 (`reason_channel_table_full`) |
| `Monitor.bend:461-466` | `with_bound`, reason 8 (`reason_channel_subject_changed`) |
| `HostBinding.bend:40-41`, `:48-49`, `:55-56`, `:61-62`, `:69-70`, `:72-75` | `Object`, `Alias`, `Route`, `Quota`, `Delegation`, `Binding` |
| `HostBinding.bend:358-367` | `bindings_valid` comment and def |
| `HostBinding.bend:478-492` | `mints_valid` comment and def |
| `HostBinding.bend:768-834` | `acts_for_owner` through `holder_authorized` |
| `HostBinding.bend:821-826` | HOST OBLIGATION: update the route record, withdraw delegated endpoints |
| `HostBindingTests.bend:847, 855, 857, 868, 927, 930, 932, 939, 942, 945, 950, 1000, 1002, 1009` | the `vector(...)` lines for the ids listed below |
| `HostBindingTests.bend:1012`, `:1014` | the two GA-008 `valid` checks named below |
| `verification/host-binding-vectors.txt:3, 4, 5, 7, 19-25, 32-34` | the VECTOR lines |
| `genode-channel-base-linux.txt:418-420` | Run 1 accept, channel 1 route subject 1, Committed, descriptor=2 |
| `genode-channel-base-linux.txt:450-452` | Run 3 routed_s, Denied reason 5, descriptor=0 |
| `genode-channel-base-linux.txt:466-468` | Run 4 claim_ignored, claimed subject 2, Committed |
| `genode-channel-base-linux.txt:482-486` | scratch suffix-only run, "no <policy> with a subject", removed after |
| `genode-channel-base-linux.txt:501`, `:505` | MonitorCheck (Linux) reason 8 reply and PASS |
| `genode-channel-base-linux.txt:612, 630, 638, 662, 860` | Task 3 runs bad_length, liveness, close line, queue, dead_client |

Vectors and checks the section lists (14 vector lines + 2 `valid` checks = 16):

| Item | Genode run today |
| --- | --- |
| GA-002-1 holder authorized through the route | analogue: run 1 |
| GA-003-1 open from the routed Session | analogue: run 1 |
| GA-002-2 suffix cannot name the subject | analogue: scratch suffix run (removed after); run 4 for a body claim |
| GA-002-3 unrecorded route | partial analogue: same refusal line in the scratch run; no dedicated run |
| GA-005-1 possession without record | gap |
| GA-005-2 non-holder UnknownAlias | gap |
| GA-005-3 recorded delegatee accepted | gap |
| GA-005-4 delegatee opens while route stands | gap |
| GA-005-5 delegator's route withdrawn | gap |
| GA-005-6 delegation to another subject's domain | gap |
| GA-005-7 delegatee routed as another subject denied at use | gap (reason 8 nearest, Linux MonitorCheck only) |
| GA-008-1 stale binding revision | gap |
| GA-008-2 Frontend rejects, state unchanged | analogue: run 3 |
| GA-008-3 invalid input state | gap |
| check "two objects bound to one Frontend handle" (unique handle per binding) | gap |
| check "two uncopied aliases for one live object" (single minted alias) | gap |

So 5 of 16 have an analogous Genode run (one through a removed scratch run, one
partial); none is replayed with the vector's inputs or a normalized-outcome
comparison. Constants or gaps stated plainly: service (one, no word),
generation (0, never carried; ids never reused), epochs (not binding fields;
Scenario constants), `Route.child` and alias holder (not visible to Bend),
binding revision (none; per-channel `Frontend.empty()`), delegation (none),
revocation on route change (config ROM never updated), generation turnover
(no restart).

OpenSpec after Task 1: `validate --all --strict --no-interactive`,
44 passed, 0 failed.
