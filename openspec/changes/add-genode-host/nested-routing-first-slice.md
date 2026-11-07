# First nested Genode channel fixture: patch plan

A synthetic reader R requests the existing fixed-label `Writ_channel` under a
nested `init`. The upper sibling monitor should log the route-derived label and
subject and return the existing synthetic Scenario's expected decision. The
first patch can exercise this one public round trip with the existing monitor,
client and Genode run machinery; it does not need a new native client or a
change to Writ policy. The predicted nested label is not yet observed.

This document records the original **patch plan**. The experimental
[fixture and preparation instructions](../../../contrib/native-hosts/genode/README.md#experimental-nested-channel-fixture)
are now present; no nested host run or protected profile is established by
their presence. The plan is based on repository commit
`68392ecea45a4c771783903da1f9eb18083c201b` and the previously reviewed
[pinned-source routing analysis](nested-routing-source-review.md). The
[fixture design](nested-routing-fixture-plan.md) records q18 provenance,
source hashes, same-init evidence and the wider adversarial matrix.

## Existing pieces and source boundary

- [Monitor.bend](../../../hosts/genode/monitor/Monitor.bend) is the existing
  Bend monitor. It uses synthetic Scenario state and the existing Bend
  capability-to-commit path; its write intent is descriptive, not a native
  publication. It is not an authenticated grant issuer.
- [writ_channel_client.cc](../../../hosts/genode/probes/client/writ_channel_client.cc)
  is the **existing C++ native probe**, not a Bend channel client. It fixes the
  channel label to `channel` and takes session, body-claim, expected-decision,
  reason and delay values from its test configuration. Reuse it unchanged;
  [Probe.bend](../../../hosts/genode/monitor/Probe.bend) is a separate LOG/Timer
  probe and is not a `Writ_channel` client.
- [writ_bend_monitor.tcl](../../../scripts/genode/writ_bend_monitor/writ_bend_monitor.tcl)
  supplies the current monitor scenario functions and sources the generic
  [writ_bend.tcl](../../../scripts/genode/writ_bend.tcl) boot helper. The
  existing scenario function's assertions hardcode the same-init label and
  log path; invoking it unchanged would not validate the nested layout.
  Its generic boot helper can build the monitor plus `app/writ_channel_client`
  and accept an added child configuration, but it also installs a broad default
  route. That default and public diagnostic LOG prevent a confinement claim.
- The user-approved [native boundary](../../../contrib/native-hosts/AGENTS.md)
  allows native packaging and probes under `contrib/native-hosts/`. Existing
  legacy files under `hosts/genode/` and `scripts/genode/` are inputs, not a
  precedent for adding native source elsewhere. Any new run configuration,
  orchestration or native probe belongs under `contrib/native-hosts/genode/`;
  authorization, state machines, security laws and core tests remain in Bend.
  Generated Bend C, compiled binaries, downloaded tools and build products
  remain outside the source checkout.

## Smallest proposed patch

1. Add one public native-fixture run configuration at
   `contrib/native-hosts/genode/nested-channel/writ_bend_monitor_nested_accept.run`.
   It sources the existing `run/writ_bend_monitor.tcl` and reuses the generic
   boot helper, existing monitor component, client binary and synthetic R
   request. It supplies a nested child-init config, a parent route from that
   init to the existing monitor and the two-level policy described below. New
   script assertions are native-harness observations, not a second policy
   engine; do not change `Monitor.bend`, the client C++, the shim, existing
   same-init scripts, or any security law. A separate test-only client or
   generalized label configuration is not part of this first slice.
2. Add an inventory and manual isolated-build instructions to
   [contrib/native-hosts/genode/README.md](../../../contrib/native-hosts/genode/README.md):
   list the fixture, exact pre-existing inputs, trust boundary, external
   overlay/build/output locations, public-only logs, cleanup and unsupported
   cases. Update matching Genode design/traceability with the precise fixture
   name and distinguish the implemented fixture from an actual run. Do not check any
   acceptance task or label a host qualified. Update the source manifest.
3. Stage the new `.run` file as `run/writ_bend_monitor_nested_accept.run` in a
   **fresh external Genode repository overlay** together with verbatim copies
   of the existing `run/writ_bend.tcl`, `run/writ_bend_monitor.tcl`, monitor
   and client build descriptions, shim and existing client sources. Generate
   the monitor's C from the pinned Bend compiler into a separate external
   `bend-c/monitor` directory. Hash each staged input against the tracked source;
   do not modify the tracked legacy files or the shared `writ-genode` overlay.
   A new general-purpose shell endpoint or automatic fallback is out of scope.

The exact include layout and fresh build configuration must be reviewed against
`target.mk` and `writ_bend.inc` when the patch is written; the run file must not
assume that the WritFS QuickJS three-boot build script exercises this channel.
No `@unsafe`, new policy decision, duplicate authorization engine, native
caller-supplied authority fact or alternate release route is introduced.

## Proposed first run and negative control

Use a fresh **base-linux** build and only public fixture data. The parent init
starts `writ_bend_monitor` and a sibling `clients` init; the nested init starts
`writ_client_r`. Explicitly enumerate the required `PD`, `CPU`, `ROM`, `RM`,
`LOG`, `Timer` and `Writ_channel` routes at both levels rather than granting a
new wildcard to the nested client. A parent-provides declaration makes
`Writ_channel` visible to the nested init; its child routes that service to its
parent, and the parent routes `clients` to the monitor. The monitor's trusted
configuration uses `label_prefix="clients -> writ_client_r ->"` for synthetic
subject 1, with no target label-rewrite attributes. LOG is for public test
values only. Pin the reviewed configuration; no child controls the nested init
or monitor policy ROM.

For the exact fixed names, source inspection predicts the monitor label
`clients -> writ_client_r -> channel`; runtime output must decide whether the
configuration actually produces it. Require a real session-open log with that
label and subject, the monitor's `SYNTHETIC authority` line, an R request using
session 1/revision 6, claimed subject 1, and the existing `Committed` decision
and reason 0, the probe's own PASS/exit 0, and the expected record bytes. A
missing line, changed label, failed setup, timeout or resource shortage is a
failed/incomplete **fixture**, not a reason to relax the expected result or
claim an authorization success.

As a distinct negative control, change only the synthetic expected decision or
remove the trusted matching R policy in an isolated variant and require the
harness to fail. The latter may fail during session creation before any Bend
request; retain the actual output and do not call it a Bend denial. Negative
controls must not modify the shared overlay or a running service. A separate
existing-client run can later send R's body claiming S and session 2, where the
same-init control expects Bend denial reason 6; that is useful follow-up but is
not evidence until a nested run captures the actual outcome.

## Isolation, quotas and evidence

Use the pinned Genode 26.08 source and 25.05 toolchain identified in the
[Genode pins](../../../verification/genode-pins.txt), after verifying their
actual identity. Provision a fresh outside-checkout source/build/overlay/output
area and an explicit low, bounded build parallelism. The existing sibling
`writ-genode` cache and build configurations use shared absolute paths and
`-j16`; do not overwrite them or trust their outputs as a clean nested build.
The fresh build config must omit or explicitly override the inherited
`MAKE += -j16` setting rather than relying on an unrelated environment setting
to limit jobs.
Inspect the host for concurrent builds and unrelated VMs; do not stop or alter
another process. Run the specific child process with a timeout, retain its
exit status and logs, and tear down only processes and directories created by
that invocation. Plan a separate base-hw/QEMU TCG run only after base-linux
results and review; a base-linux success does not establish that result.

Keep the current monitor/client starting quotas as **reference inputs**, not
validated nested quotas: monitor 256 MiB/1000 caps, R 2 MiB/200 caps, and the
client's channel donation 32 KiB/eight caps. Assign and record an explicit
budget for the nested init and forwarded sessions; each parent layer can deduct
session metadata and capabilities before the monitor sees the donation. The
current shim needs at least 16 KiB RAM and its cap minimum. If existing
unchanged-client donations are insufficient, retain the failure; changing the
client or inventing a quota increase requires a separate reviewed patch.

Record exact source and clean-tree identities, toolchain hashes, staged overlay
hashes, generated C and binary/boot-image hashes, complete route/policy and
quota configuration, timestamps, command/exit statuses, logs, negative control,
and all refusals. Update only the scoped evidence record after the actual run;
keep generated artifacts outside the source package. A full host qualification
requires separate identity/delegation, effect confinement, route-generation
revalidation, restart, revocation, output sealing and durable publication
work; none is established by this fixture.

## Explicitly out of the first slice

The fixed `channel` requester cannot vary its chosen suffix, so hostile suffix
injection requires a separately reviewed test-only probe. This first R run also
does not establish S isolation, duplicate-policy rejection, stale-session or
restart behavior, resource-exhaustion denial, complete route mediation, or
whether a delegated channel holder is its original actor. The current shim
selects the first equally scored conflicting policy; it does not reject a
conflict. Trusted configuration must avoid conflicting policies; a test that
expects the shim itself to reject them would currently fail by source analysis.
No observed nested label, test pass or protected-host claim may be inferred
from this design. q18 items 7–10 remain as recorded; this work neither answers
them nor changes existing authority rules.
