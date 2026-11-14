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

The synthetic [LinuxClockTests.bend](../../hosts/linux/monitor/LinuxClockTests.bend)
covers LH-012 and LH-015 at the Linux monitor model boundary:

- LH-012: `LH-clock: denied expiry retains sample before later regression`;
  `LH-clock: malformed frame retains sample before later regression`;
  `LH-clock: first malformed frame retains its sample before regression`.
- LH-015: `LH-clock: unavailable ambiguous and overflow poison without policy change`;
  `LH-clock: first unavailable sample poisons a fresh instance`;
  `LH-clock: a later valid sample cannot clear poison`;
  `LH-clock: direct worker broker and barrier helpers reject stale time`;
  `LH-clock: poisoned direct helpers cannot deliver or grant`;
  `LH-clock: revoke and restart preserve poison and exact stop effects`;
  `LH-clock: denied cleanup preserves poison credentials and policy`;
  `LH-clock: healthy dispatch and framed serve retain exact delivery effect`;
  `LH-clock: stale clock avoids evaluating overflow-prone admission`.

The sample is a trusted input and neither a real clock nor an authenticated
supervisor. Equal samples cannot detect a clock that freezes or is replayed.
Issuer and FUSE paths remain separate; retained state and clock continuity are
not durable or rollback-resistant. LH-012/LH-015 host acceptance remains open.

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
| LH-001 "A required interface is absent" (model half) | `profiles`, `linux_worker_profile`, `required_controls`, `report_of`, `dispatch` (`Barrier` to `P.admit_worker`) | `LH-001 linux_host and linux_incarnation are nonzero, differ from adapters A and B, and the profile is named linux-worker-v1 with a nonzero quota`; `LH-001 initial() is a valid empty state on the Linux host and incarnation whose only configured profile is linux-worker-v1: every family, every control but accelerator isolation, Cpu, quota_limit`; `LH-001 a worker session under any profile id but linux-worker-v1 is denied UnknownProfile with the policy state unchanged and no effect`; `LH-001 a barrier report omitting any one of the five families is denied UnsupportedFamily with the policy state unchanged and no effect`; `LH-001 a Launch whose report omits family_session is denied UnsupportedFamily by open_session with the policy state unchanged and no effect`; `LH-001 LH-003 a barrier report with every required control admits once and its only effect, in the step and in Outcome.effects, is one DeliverInputs naming the worker's input`; `LH-001 under a hypothetical accelerator profile the Linux report is denied UnisolatedAccelerator by the shared path with the policy state unchanged and no effect`; `LH-001 report_of rejects a family bit outside all_families UnknownFamily`; `LH-001 report_of rejects an accelerator isolation bit the Linux broker cannot credit UncreditedControl`; `LH-001 report_of rejects an unnamed control bit UncreditedControl` | The profile is a named, versioned, monitor-owned record and an admission short of a required family or control is denied with no `DeliverInputs`. Pinning the runtime, architecture, kernel configuration, and Landlock ABI, and probing them, is native work (Tasks 2 and 3); "Model execution without a launcher" holds for this profile: the partial launcher on a separate branch is not in this tree and is not qualified. |
| LH-005 "Older ABI lacks a required scope" (model half) | `required_controls`, `report_of` (bits copied, never widened), shared `admit_worker` step 9 | `LH-005 a barrier report without control_address_isolation is denied MissingControl with the policy state unchanged and no effect`; `LH-005 a barrier report without control_no_ambient_network is denied MissingControl with the policy state unchanged and no effect`; `LH-005 a barrier report without control_output_mediation is denied MissingControl with the policy state unchanged and no effect`; `LH-005 a barrier report without control_quota is denied MissingControl with the policy state unchanged and no effect`; `LH-005 a barrier report without control_no_inherited_routes is denied MissingControl with the policy state unchanged and no effect` | The profile requires a fixed control set and no report short of it admits under a reduced set. Reviewed-only gap: the ruled control-to-kernel mapping names no Landlock right, so which control a Landlock right is credited under is open until Task 3; the ABI probe and per-right enforcement are native evidence. |
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

## Proposed local supervisor profile (LH-011–LH-017)

Josh selected the local operator/supervisor direction in q22. These requirements
are proposed host contracts, not an implemented authority source, authenticated
principal, monotone clock, joint dispatcher, durable recovery or host acceptance.
The [local profile design](../changes/add-linux-host/local-supervisor-profile.md)
records the trust boundary and the currently missing mechanisms.

[LocalSupervisorTests.bend](../../LocalSupervisorTests.bend) executes three
synthetic post-commit traces through the existing DataOS, Issuance and Frontend
entries: `local Copy model source revoke after commit: fresh use denies, cached use
stays stale, retry preserves session and ledger` and `local Copy model destination
revoke after commit: fresh use denies, cached use stays stale, retry preserves
session and ledger`, plus `local Copy commit retains exact nonfirst frontend descriptor and denies rejected inputs`. They construct synthetic separate issuing authorities for
the exact canary Copy plan and pass the exact issuer-projected Frontend change
and context to the existing `MountAuthority.descriptor` and DataOS commit.
The returned historical Frontend and reference are compared with the exact
inputs of the same commit, including a nonfirst descriptor. The same descriptor is checked after revocation; all fresh projections deny,
while both exact projections used at commit still resolve. The original intent's
provenance is inspected. A retry using the returned committed session and
ledger is rejected with those two states unchanged; it returns no new intent.
The fixture's policy is Free and the specific trace does not demonstrate a
nonzero-charge replay. The tests do not invoke `Mount.dispatch` or authenticate a native host. These
are model evidence
for the stale-projection hazard, not an authenticated local supervisor or a
combined Mount/Linux release gate. Time sampling, trusted attribution,
serialization against effects, replay-resistant recovery and native adversarial
scenarios remain reviewed-only gaps for LH-011–LH-017.

The [owned-process channel identity record](../../verification/linux-channel-identity/README.md)
is native kernel-behaviour evidence for the candidate transport only:
`channel-identity-test.c` cases `after-transfer`, `queued-before-transfer`,
`reaped-sender` and the receive rejections. It does not implement or accept any
LH-011–LH-017 requirement.

The [supervisor channel receiver record](../../verification/linux-supervisor-channel/README.md)
maps two LH-011 scenarios to named tests.

"A transferred administrative endpoint does not carry its role": the asserting
test is `supervisor-channel-test.c` case `transferred_endpoint_attributes_receiver_role`
(a record sent by the second process is attributed to role 2). `reaped_role_sender`
is supporting evidence only: it covers a record queued before the sender was
reaped and accepts either FROM_ROLE 1 or SENDER_ERROR. On the Bend side,
[LocalChannelTests.bend](../../hosts/linux/monitor/LocalChannelTests.bend)
`LocalChannel provisioned role attributes to its principal` and `LocalChannel
payload-named principal is ignored; sender role decides` show only role-to-principal
mapping. `attribute` has no payload parameter, so payload independence is
structural, by signature; the second check confirms only that role 2 maps to
102. No Bend test models a transfer or decodes a payload.

"An unprovisioned sender is not attributed": the asserting test is
`unregistered_sender_unknown` (UNKNOWN_SENDER), with the Bend checks `LocalChannel
unknown sender denies` and `LocalChannel unknown role index denies`. That no
`from` is attached is structural: `Denied` carries no principal, and no check
builds an issuance. `missing_sender_without_enable` is supporting evidence, a
receiver-configuration denial (no `SO_PASSPIDFD`), not a sender without a
retained role.

These are receiver-level evidence only. Pidfs `dev` matching, capable-sender and
exec behaviour, namespace and ptrace isolation, supervisor wiring, protected role
provisioning and native host qualification remain reviewed-only gaps.

The [supervisor owner record](../../verification/linux-supervisor-owner/README.md)
feeds attributed channel messages to one serialized model owner of the issuer
and clock, [SupervisorOwner.bend](../../hosts/linux/monitor/SupervisorOwner.bend).
Its checks in [SupervisorOwnerTests.bend](../../hosts/linux/monitor/SupervisorOwnerTests.bend)
map to these scenarios at the model boundary only:

- LH-011 "An unprovisioned sender is not attributed": `SupervisorOwner
  unattributed and malformed senders deny and only advance the clock` (no
  revoke reaches the issuer, whose revision is unchanged).
- LH-012 "A request is denied after a later trusted sample": the same refused
  revoke and `SupervisorOwner malformed control payloads deny and only advance
  the clock`.
- LH-013 "An accepted issuer revoke requires containment": `SupervisorOwner
  issuer role revoke applies, advances clock and requires containment` and
  `SupervisorOwner revoke then frame: the frame sees containment and no effect
  is handed off`.
- LH-015 "A malformed request observes a later time": `SupervisorOwner frame and
  control share one watermark`.
- LH-015 "Clock poison blocks use but allows cleanup": `SupervisorOwner faulted
  sample contains; issuer revoke still applies, refused revoke does not` and
  `SupervisorOwner revoke and drain remain available after containment`.

The [supervisor driver record](../../verification/linux-supervisor-driver/README.md)
runs this owner in a private interpreter behind the native driver
[`supervisor_owner.c`](../../contrib/native-hosts/linux/supervisor_owner.c) over
the receiver, on owned processes, against a synthetic provisioning module. Its
native cases add evidence at that boundary for:

- LH-011: `unregistered_sender_denied` (a real unregistered process's revoke is
  `CHANNEL_DENIED` and nothing is stopped), with `frame_verdicts_exact` showing
  that the unknown-sender verdict reaches Bend unchanged and without a role.
- LH-012: `non_issuer_revoke_refused`, `malformed_payload_undecoded`.
- LH-013: `issuer_revoke_applied` (containment, no effect from the control
  message), then `drain_returns_worker_stop` and `drained_worker_killed` (the
  driver kills worker 1 through its pidfd only on the drain's StopEffects).
- LH-015: `regressing_sample_contains`, `expired_grant_contains` and
  `unavailable_clock_issuer_revoke_applies`, with scripted samples;
  `frame_clock_kinds_exact` shows that each faulted kind reaches Bend by
  number.

The clock samples there are scripted because the synthetic issuer's times are
not a host time base; nothing installs a real issuer, aligns
`CLOCK_BOOTTIME` with grant times, restarts with continuity or binds a worker's
role to its session. Host acceptance for these scenarios remains open.

The [supervisor provisioning record](../../verification/linux-supervisor-provision/README.md)
replaces the synthetic role-index-to-principal map with one installed from a
protected configuration record ([SupervisorProvision.bend](../../hosts/linux/monitor/SupervisorProvision.bend)),
and, through the driver's API, registers workers only as it launches them
after provisioning. Which process holds which role index is still the caller's
registration, so the LH-011 binding of each worker lifetime and session to its
principal is not established. For LH-011
("Local supervisor authority is explicitly provisioned") it adds, at the model
and owned-process boundary only:

- Bend checks in [SupervisorProvisionTests.bend](../../hosts/linux/monitor/SupervisorProvisionTests.bend):
  `SupervisorProvision refuses unprotected configuration facts before decoding`,
  `SupervisorProvision refuses invalid, empty or unbacked role maps and ambiguous placements`,
  `SupervisorProvision adopts only a record whose root is the retained issuer's root`
  and `SupervisorWire refuses unprovisioned frames, refused records and reprovisioning`.
- Native cases: `protected_record_provisioned`, `group_writable_record_refused`,
  `linked_record_refused`, `fifo_record_refused`, `foreign_root_record_refused`,
  `symlink_record_not_followed`, `intermediate_symlink_not_followed`,
  `record_outside_directory_refused`, `control_before_provision_fail_stop`,
  `second_provision_fail_stop`, `launch_registers_worker` and
  `launched_worker_clean`. The native refusals observe only
  `PROVISION_REFUSED`; which check refused is shown by the Bend checks.

File ownership, mode and link count are local facts, not an authenticated
operator; the foreign-owner refusal is checked in Bend only, since an
unprivileged test cannot create a file owned by another user. The issuer-root
match is a consistency check, not authority, since the canary root is public.
The record installs the role map; the issuer's
approvals still come from the synthetic canary, not from authenticated
submissions over the channel.

The [supervisor approval record](../../verification/linux-supervisor-approvals/README.md)
carries source-read and destination-write approval submission on the same
channel ([SupervisorApproval.bend](../../hosts/linux/monitor/SupervisorApproval.bend),
`LinuxHost.joint_submit`). Each submission is made as the sender role's
attributed principal, and Issuance's existing `submit_source` / `submit_write`
decide it. These checks show attribution only: the role, not the record, names
the principal, and a write role cannot supply a source approval. They do not
satisfy LH-011, whose administrator actions must be authenticated: here a
caller-registered role process, identified by its pidfd, is the whole basis for
a submission, and no test exercises the LH-011 grant-denial scenario. The checks
are, at the model and owned-process boundary only:

- Bend checks in [SupervisorApprovalTests.bend](../../hosts/linux/monitor/SupervisorApprovalTests.bend):
  `SupervisorOwner each role's own approval is accepted without containment`,
  `SupervisorOwner a role cannot submit another principal's approval`,
  `SupervisorOwner a consumed serial is refused as a replay`,
  `SupervisorOwner an approval's lifetime is judged at the sampled time`,
  `SupervisorOwner nothing is submitted on a faulted, expired or contained owner`,
  `LinuxHost joint submit refuses a stale retained clock and a terminal issuer revision`
  and `SupervisorWire approval submission sequence replies exactly`.
- Native cases: `source_role_submission_accepted`,
  `other_role_submission_refused`, `unregistered_submission_denied` and
  `write_role_submission_accepted`.

For LH-012 it adds `SupervisorOwner a submitted approval is revocable only by
its issuer role` and the native `submitted_approval_revoked`. The issuer is
still the synthetic canary, the submitting role is not told the new id, grant
registration is not carried on the channel, and role processes are still
registered by the caller.

## Synthetic Rendezvous owner (LH-012, LH-013, LH-015 and LH-016)

[LinuxJointOwnerTests.bend](../../hosts/linux/monitor/LinuxJointOwnerTests.bend)
exercises the in-memory selected-provider issue and input-delivery path. These
checks do not qualify a native supervisor, authenticated source, live clock,
continuous expiry, selected-profile exclusivity, FUSE path, committed Copy,
ledger, evidence/sample expiration, budget or original-graph verification. The
provider's selected grant is exact; the reader projection is subject-wide and
can be satisfied by a different current same-scope grant. A line-only LINUXMON1
client cannot execute or correlate typed stop effects.

The exact named checks are:

- `synthetic owner calls actual Rendezvous dispatch`
- `synthetic owner issues actual slot`
- `synthetic owner delivers through retained selection`
- `accepted issuer revoke contains and drains exact stop`
- `expiry contains before malformed request`
- `regressed clock contains before malformed request`
- `unavailable clock contains before malformed request`
- `joint bootstrap rejects imported dispatch`
- `joint issue retains same-transition selection grant and slot`
- `joint issue requires exact dispatched credential session`
- `denied issuer revoke preserves active owner and host`
- `repeat denied revoke remains contained`
- `unrelated accepted revoke also contains and stops`
- `direct helpers surface sticky containment`
- `restart returns stop and cannot reopen joint mode`
- `joint direct revoke contains unchanged; standalone still stops`
- `joint revoke drains two exact roots and retains stop history`
- `joint capacity gates avoid terminal transitions`
- `partial drain preserves earlier exact stop on terminal failure`
- `terminal descendant generation prevents unsafe drain`
- `selection lineage and exact dispatch prevent reauthorization`
- `terminal live descendant leaves subtree and issuer retained`
- `two frontend allocation boundaries refuse or succeed precisely`
- `partial drain retains earlier stop when identity revision is terminal`
- `terminal issuer revoke is unapplied and requires containment`
- `joint mode ignores generic snapshot for acceptance and denial`
- `joint direct helper recomputes broker facts`
- `accepted issuer revocation survives actual root drain`
- `joint ancestry rejects zero and unrelated root at high fuel`
- `framed expiry reports not processed and retains sample`
- `failed owner still retains later clock samples`
- `reader-only grant expiry contains with provider selection current`
- `reader-only approval revoke retains provider selection and stops`
- `running Negotiation deadline requires containment`
- `missing reader projection contains with provider still current`
- `different current reader grant may satisfy subject projection`
- `direct dispatch issue and effect helper recheck reader authority`
- `joint launch recomputes raw broker fact checks`
- `joint replies redact active and failed metadata`
- `direct helpers contain expired reader authority`
- `denied cleanup still contains expired reader state`
- `nested owner remains contained and retained`
- `nested transition attempts cannot be accepted`


## Trusted session-loss trigger (LH-013, LH-015, LH-017)

`LinuxHost.session_lost` is a trusted in-process signal, not a broker or worker
frame and not native death detection. It forwards any joint loss or ambiguous
lifetime to the existing containment outcome. Valid singleton owners retain
policy, credentials, clock, issuer and historical stops in sticky `JointFailed`;
no effect is emitted by the signal. Malformed nested owners remain unnormalized
and fail closed under existing guards. Standalone returns `Unrouted` with its
state unchanged. Checked drain and restart still produce only their actual
StopEffects. The supervisor must observe loss, serialize the signal against
effect handoff, and physically contain workers; already delivered bytes cannot
be recalled. No native authentication, host lifetime monitoring, or reader
transaction binding is established by this model signal.

Named synthetic cases in [LinuxSessionLossTests.bend](../../hosts/linux/monitor/LinuxSessionLossTests.bend):

- `LH-session-loss running worker retains state and requires containment`
- `LH-session-loss valid framed delivery and direct helpers stop after loss`
- `LH-session-loss drain emits exact stop once and preserves history`
- `LH-session-loss restart emits actual stop and stays contained`
- `LH-session-loss retains exact revoked issuer through drain`
- `LH-session-loss preserves poisoned clock and cleanup`
- `LH-session-loss standalone state is unrouted and unchanged`
- `LH-session-loss malformed owner stays unnormalized and contained`
- `LH-session-loss terminal cleanup remains incomplete`
