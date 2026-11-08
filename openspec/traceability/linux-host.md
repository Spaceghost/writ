# Native Linux host traceability

Proposed change: [add-linux-host](../changes/add-linux-host/specs/linux-host/spec.md).
This is a proposed change; nothing here marks the Linux host, its broker, or
any host acceptance scenario as implemented.

Rule: model rows only in this task; native evidence is Tasks 2 to 4 of the
[linux-host plan](../../docs/superpowers/plans/2026-11-05-linux-host.md). The
Linux host remains model-only until those tasks record executed evidence.

Implementation and test modules:

| Task | Implementation | Executable cases |
| --- | --- | --- |
| 1.1 (model half) | [LinuxHost.bend](../../hosts/linux/monitor/LinuxHost.bend) (adapter glue with session credential retention; no portable law) | [LinuxHostTests.bend](../../hosts/linux/monitor/LinuxHostTests.bend), run by `Tests.bend` as `LinuxHost`; trust inventory [INVENTORY.md](../../hosts/linux/INVENTORY.md) |

The synthetic in-memory open result is additionally covered by
[LinuxSessionOpenTests.bend](../../hosts/linux/monitor/LinuxSessionOpenTests.bend),
run by `Tests.bend` as `LinuxSessionOpen`: `PH-open-typed-client`,
`PH-open-typed-evidence`, `PH-open-typed-role`, `PH-open-typed-worker`,
`PH-open-typed-stale`, `PH-open-typed-family`, `PH-open-typed-fact`,
`PH-open-typed-profile`, and `PH-open-typed-origin` check role narrowing and
unchanged denials. `LH-open-typed-first`, `LH-open-typed-next`, and
`LH-open-typed-crowded` check the exact returned worker session and binding;
`LH-open-wire-admitted`, `LH-open-wire-denied`, and `LH-open-wire-untranslated`
check the unchanged diagnostic wire bytes with a truncated table, and
`LH-open-other-routes` covers accepted non-Launch operations. These are
model checks, not correlation, native authentication or host qualification.

The synthetic [LinuxCredentialBindingTests.bend](../../hosts/linux/monitor/LinuxCredentialBindingTests.bend)
adds `LH-binding` cases for same-caller replaced credentials, every credential
field including the high start-time word, missing and duplicate records,
swapped sessions, unchanged denied launch/restart, direct `barrier_use`, framed
service, a 4096-record synthetic traversal, combined denial order, restart with
recycled IDs and stop effects, and revoked references. The credential lookup is
tail-recursive, but the existing identity lookups and runtime resources still
limit host capacity; no unlimited capacity is claimed.
`LinuxHost.State` retain framed facts only: the native broker still has to obtain and
bind authenticated process lifetime and these checks are not a live-registry gate.

The trusted in-process `LinuxHost.revoke` routes the existing shared
`HostPublication.revoke` transition while retaining Linux credential records.
The synthetic `LH-revoke` checks cover input and root retirement, descendant
cascade, an unrelated live root, exact `StopEffects`, no-worker effects,
unchanged denial precedence and a later framed Barrier denial. These model
results do not authenticate a revocation caller or connect issuer revocation
to a slot, a native stop operation, the FUSE canary, or live authority.

Test names below are the exact `Test.check` names. Fixtures are SYNTHETIC
broker facts (subject 7, launch credential uid 1000, pid 4242, start 917).

| Requirement | Implementation | Named executable evidence | Coverage boundary |
| --- | --- | --- | --- |
| LH-001 "A required interface is absent" (model half) | `profiles`, `linux_worker_profile`, `required_controls`, `report_of`, `dispatch` (`Barrier` to `P.admit_worker`) | `LH-001 linux_host and linux_incarnation are nonzero, differ from adapters A and B, and the profile is named linux-worker-v1 with a nonzero quota`; `LH-001 initial() is a valid empty state on the Linux host and incarnation whose only configured profile is linux-worker-v1: every family, every control but accelerator isolation, Cpu, quota_limit`; `LH-001 a worker session under any profile id but linux-worker-v1 is denied UnknownProfile with the state unchanged and no effect`; `LH-001 a barrier report omitting any one of the five families is denied UnsupportedFamily with the state unchanged and no effect`; `LH-001 a Launch whose report omits family_session is denied UnsupportedFamily by open_session with the state unchanged and no effect`; `LH-001 LH-003 a barrier report with every required control admits once and its only effect, in the step and in Outcome.effects, is one DeliverInputs naming the worker's input`; `LH-001 under a hypothetical accelerator profile the Linux report is denied UnisolatedAccelerator by the shared path with the state unchanged and no effect`; `LH-001 report_of rejects a family bit outside all_families UnknownFamily`; `LH-001 report_of rejects an accelerator isolation bit the Linux broker cannot credit UncreditedControl`; `LH-001 report_of rejects an unnamed control bit UncreditedControl` | The profile is a named, versioned, monitor-owned record and an admission short of a required family or control is denied with no `DeliverInputs`. Pinning the runtime, architecture, kernel configuration, and Landlock ABI, and probing them, is native work (Tasks 2 and 3); "Model execution without a launcher" holds for this profile: the partial launcher on a separate branch is not in this tree and is not qualified. |
| LH-005 "Older ABI lacks a required scope" (model half) | `required_controls`, `report_of` (bits copied, never widened), shared `admit_worker` step 9 | `LH-005 a barrier report without control_address_isolation is denied MissingControl with the state unchanged and no effect`; `LH-005 a barrier report without control_no_ambient_network is denied MissingControl with the state unchanged and no effect`; `LH-005 a barrier report without control_output_mediation is denied MissingControl with the state unchanged and no effect`; `LH-005 a barrier report without control_quota is denied MissingControl with the state unchanged and no effect`; `LH-005 a barrier report without control_no_inherited_routes is denied MissingControl with the state unchanged and no effect` | The profile requires a fixed control set and no report short of it admits under a reduced set. Reviewed-only gap: the ruled control-to-kernel mapping names no Landlock right, so which control a Landlock right is credited under is open until Task 3; the ABI probe and per-right enforcement are native evidence. |
| LH-010 "Decision vectors pass but an inherited socket can transmit" (model half: shared vectors only) | Linux adapter fixture in `LinuxHostTests.bend` (`linux_adapter`: the Linux host and incarnation, `report_of` and `inventory_of` of the broker-shaped fact) | `LH-010 the Linux adapter fixture is the Linux host and incarnation with report_of and inventory_of of the broker fact`; `LH-010 PH-009-1 replays on the Linux adapter with adapter A's and B's outcome and line` (and the 35 other `LH-010 PH-...` replay checks); `LH-010 the Linux adapter's 36 decision lines equal V.expected_lines() and adapters A's and B's`; `LH-010 PH-012-1 the Linux adapter compared with adapters A and B renders the expected compare line` | Shared harness with the Linux fixture's identity, report, and inventory; `LH.dispatch` (launch check, session check, Barrier routing, channel split) is covered by the dispatch checks, not the replay. Native adversarial evidence is Tasks 2 to 4; vector conformance alone does not qualify the host. |

Additional synthetic LH-002 frame checks run through `LinuxHost.serve`:
`synthetic LINUXB launch rejects parent socketpair peer`, `synthetic LINUXB
launch rejects peer start-time high-word mismatch`, `synthetic LINUXB barrier
rejects a foreign launch subject`, and `synthetic LINUXB barrier rejects a
missing session`. The decoder also tests the 512-byte boundary and rejects a
10,000-byte direct input without changing state or returning effects. These are
model cases, not authenticated kernel credentials, native descriptor-transfer
tests, or LH-002/LH-007 host qualification. The trust-boundary and execution
gaps are recorded in [task-2-synthetic-report.md](../../docs/superpowers/records/2026-11-05-linux-host/task-2-synthetic-report.md).

The [model-only integration record](../../docs/superpowers/records/2026-11-05-linux-host/model-only-integration.md)
separates this tree from the unfinished native sources on `lane/linux-host`.

The proposed [single-owner and lifecycle review](../changes/add-linux-host/live-owner-ordering.md)
maps the existing Mount, session and capability calls to NM003/NM005, LH-002,
LH-003, LH-006–LH-008 and PH-002, PH-006, PH-009–PH-010. The joint live
authority gate, authenticated actor/session bridge, effect ordering and their
combined scenario tests are **reviewed-only gaps**, not host implementation or
acceptance evidence.
