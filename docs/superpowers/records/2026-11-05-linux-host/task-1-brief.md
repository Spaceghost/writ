### Task 1: Linux adapter, profile, and conformance replay (tasks.md 1.1, consuming 1.2 to 1.4)

Requirements it implements, by name: LH-001 "A supported profile is explicit"
(the model half: the profile is a named, versioned, monitor-owned record, and
an admission whose `TargetReport` lacks a required family or control is denied
`UnsupportedFamily`/`MissingControl` with no `DeliverInputs`); LH-005 "Required
Landlock rights cannot be dropped" (the model half: a profile requires a fixed
control set and a report short of it cannot admit under a reduced set); and the
model consumption of LH-002 "Worker identity is bound to an authenticated
lifetime", LH-003 "Confinement precedes protected observation", LH-004
"Inherited authority is explicitly bounded", LH-006 "Broker requests preserve
exact resource scope", and LH-007 "Delegation is explicit and attenuating" (the
Linux adapter drives the shared transitions that enforce these; the native
establishment of each is Tasks 2 to 4).

Create `hosts/linux/monitor/LinuxHost.bend`, importing `Base`, `HostWire`,
`HostIdentity`, `HostPrimitives`, `HostPublication`, `Frontend`, and `Transfer`
only. Header: this is adapter glue for the direct Linux target; it supplies
only `Fact`/`TargetReport`/`RouteFact`/`SessionEvidence` values and executes
only the `Effect` values an `Admitted` step returned; it decides nothing, adds
no transition and no law, and no native fact it carries is an authority fact.

- `linux_host()` and `linux_incarnation()`: the Linux monitor's host id and
  starting incarnation (named constants, nonzero).
- The profile table. One configured profile `linux-worker-v1`:
  `required_families = HostPrimitives.all_families()`;
  `required_controls` = `control_address_isolation() .|. control_no_ambient_network() .|. control_output_mediation() .|. control_quota() .|. control_no_inherited_routes()` (every control but accelerator isolation); `backend = Cpu{}`;
  a named `quota_limit()`. Plan ruling: the control-to-kernel mapping the
  broker must satisfy, documented in the header and mirrored in
  `hosts/linux/INVENTORY.md`: `control_address_isolation` = private
  mount/IPC/PID/UTS namespaces, pivoted root, nondumpable; `control_no_ambient_network`
  = private network namespace with seccomp denying socket creation;
  `control_output_mediation` = only the private result channel survives, all
  public streams closed; `control_quota` = the address-space/CPU/NOFILE/NPROC
  and zero core/file-size rlimits; `control_no_inherited_routes` = the
  descriptor allowlist, `SCM_RIGHTS`-only input, and denied descriptor import.
  An `Accelerator{}` profile is not offered in section 1 (GPU is section 2 and
  `add-genode-host`/`validate-physical-gpu-execution` territory); the adapter
  denies an accelerator request through the shared `UnisolatedAccelerator` path
  rather than defining one.
- Fact translation. Pure helpers from a `LinuxFact` record the broker frames
  (its fields named below) to the shared types: `session_evidence_of` builds
  `SessionEvidence{caller, origin, delegable}` from the authenticated subject,
  the observed origin, and `delegable=False` for a worker; `report_of` builds
  `TargetReport{supported_families, established_controls}` from the installed
  control bits; `inventory_of` builds `Inventory{routes}` from the reported
  route set. No helper produces a `Context`, `Binding`, plan, rights grant, or
  caller that a transition treats as authority.
- Monitor dispatch. `initial()` is `HostPrimitives.empty(HostIdentity.empty(linux_host(), linux_incarnation()), profiles())`.
  `dispatch` applies exactly one transition per framed input: a trusted broker
  fact routes to `open_session`/the fact-consuming transition; an untrusted
  worker frame is `HostWire.decode_bytes`d and routed to `use`/`delegate`/
  `admit_worker` on the session the transport identified. The claimed subject
  is never read. The monitor retains the advanced state before the broker
  performs an admitted effect, exactly as `contrib/native-hosts/PROTOCOL.md`
  requires of the canary interpreter.

Create `hosts/linux/monitor/LinuxHostTests.bend` (registered in `Tests.bend` as
`LinuxHost`), importing `HostConformanceVectors` and the shared modules. Header:
every session, subject, report, inventory, and fact is SYNTHETIC MONITOR STATE,
standing in for what a real broker would report; nothing here authenticates a
caller or confines a worker. Checks:
- A Linux adapter fixture (`V.Adapter` with `host = linux_host()`, the Linux
  incarnation, and a report/inventory shaped like the broker's) replays all 37
  `HostConformanceVectors` vectors and reaches the same normalized outcome as
  adapters A and B for every one; assert the rendered line list equals
  `V.expected_lines()`.
- Profile checks: an admission whose report omits each required control bit in
  turn is denied `MissingControl`; a report omitting a required family is
  denied `UnsupportedFamily`; a report with every control admits and emits one
  `DeliverInputs` as the last step (LH-001, LH-003, LH-005).
- Translation checks: each fact-translation helper is a named check against a
  known `LinuxFact` input; a worker frame's `claimed_subject` of B on A's
  session resolves to A (the claim is never read).
- Each denial asserts full primitive-state equality with its input and no
  effect.
  End `main` with one summary line `LinuxHost: N checks passed` and nothing
  starting with `PASS`.

Create `hosts/linux/INVENTORY.md` (shape of `hosts/genode/INVENTORY.md`):
status, the Bend adapter files and that none is Writ policy, the profile and
its control-to-kernel mapping, and the explicit statement that the native
broker's facts are inputs and the Bend monitor holds the authority. Create
`openspec/traceability/linux-host.md` with a header naming the change, the
implementation and test modules, and the rule "model rows only in this task;
native evidence is Tasks 2 to 4". Add the LH-001 and LH-005 model rows with
exact check names. Register the module in `Tests.bend` (one import, one call).
Check box 1.1 citing the module and test file.

Acceptance: every listed check is named and green on both backends with PASS
count = 1428 + this task's checks; the 37-vector replay matches
`V.expected_lines()`; `bend PROOF.bend` is unchanged; OpenSpec strict passes.
One implementer dispatch.

