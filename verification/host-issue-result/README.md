# Same-transition host issue result

A monitor that issues a host root needs the slot actually allocated by that
transition to bind later state. `HostPrimitives.issue_result` now returns the
exact slot and state from one accepted `HostIdentity.mint`; a denial returns
the input state and its reason. Existing `issue` projects that same result to
its previous Step, with no second mint and no effects. The existing host,
identity, Frontend and paired Transfer gates remain in the same order.

The slot is a descriptive in-memory Nat. It is not authenticated caller
identity, a correlated native receipt or proof of representability in
HostWire's U32 fields. The future owner still has to bind actual provenance,
serialize current authority, check later uses and establish native host
qualification; this change adds no release route or live bridge.

## Verification

- [Full Bend suite](tests-bend.txt) and [generated Node](tests-node.txt) each
  passed 2,921 checks with byte-identical output, also matched by the
  [full generated native CPU suite](tests-native.txt) compiled at `-O0` and run
  with one CPU thread and GPU disabled. The [six focused checks](focused-bend.txt)
  matched [Node](focused-node.txt) and [native CPU](focused-native.txt). They
  compare a nonfirst result and state to direct mint, resolve/delegate that
  fixture's bounded returned slot, verify old and live-authority denials against
  the legacy projection, and check stale terminal slot/revision cases.
- With otherwise valid authority at maximum Nat slot, separate [typed](typed-trap.bend.txt)
  and [legacy](legacy-trap.bend.txt) controls both fail with the inherited Nat
  overflow on [Bend](typed-trap-bend.txt), [Node](typed-trap-node.txt) and
  [native CPU](typed-trap-native.txt); the corresponding legacy outputs are
  [Bend](legacy-trap-bend.txt), [Node](legacy-trap-node.txt) and
  [native CPU](legacy-trap-native.txt). This terminal-capacity limitation is
  not represented as a normal modeled denial.
- [Ordinary proof](proof.txt), [pinned Lean verdict](verdict.txt) and
  [OpenSpec 1.16.0 strict](openspec.txt) passed. The [false-kernel control](negative.txt)
  failed as expected. No new proof law is claimed.
- Existing nonprivileged [callback-order](handoff-mock.txt) and
  [retirement](retire-mock.txt) native mocks passed. They do not mount FUSE or
  probe process identity.

The [Bend input manifest](bend-input-sha256.txt) and repository source manifest
identify the tested and delivered source. Commands, limits and recorded
negative controls are in [build commands](build-commands.txt). No GPU, native
identity, FUSE mount, VM, durable recovery or protected-host acceptance is
claimed.
