# Durable publication: independent model security review packet

An output's recipient must not see it before its authorization, exact artifact,
inherited policy and consumed ledger state are durably recorded together. If
the acknowledgement is lost, a retry must not spend or publish a second time.
The experimental model explores pieces of that problem; **there is no durable
publication service or accepted recovery protocol yet**.

This packet identifies material for an independent human security review of
the model and proposed boundaries. It does not request a finding of acceptance
or a decision to deploy. The review and the implementation/security review
before each dependent task in the [plan](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/docs/superpowers/plans/2026-11-06-durable-publication.md)
remain open. Every [durable publication task](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/openspec/changes/add-durable-publication/tasks.md)
is unchecked; a review of this packet does not itself complete one.

## Source and reading order

The off-master review tree is [preview `00f8c7cdc63183400a55038defd4be63cdeb42f4`](https://github.com/Spaceghost/writ/tree/00f8c7cdc63183400a55038defd4be63cdeb42f4).
Its later Genode tooling was not part of the tests described below. Please
review the exact tree, its trust assumptions and the linked records together:

1. The [proposed DP-001–008 contract](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/openspec/changes/add-durable-publication/specs/durable-publication/spec.md),
   [task order](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/docs/superpowers/plans/2026-11-06-durable-publication.md), and
   [scenario-to-evidence matrix](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/openspec/traceability/durable-publication.md).
2. The [partial model report](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/docs/superpowers/records/2026-11-06-durable-publication/task-2-report.md),
   [model review and resource finding](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/docs/superpowers/records/2026-11-06-durable-publication/model-review.md),
   [entry format and limitations](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/docs/DURABLE-PUBLICATION.md), and the adjacent `Durable*.bend` sources and tests in the review tree.
3. The proposed [recovery](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/docs/superpowers/records/2026-11-06-durable-publication/recovery-design.md),
   [lookup and fencing](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/docs/superpowers/records/2026-11-06-durable-publication/lookup-fencing-design.md),
   [rollback witness](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/docs/superpowers/records/2026-11-06-durable-publication/witness-design.md), and
   [audit integration](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/docs/superpowers/records/2026-11-06-durable-publication/audit-integration-design.md) notes. These are design proposals, not implemented interfaces.

## Questions for the reviewer

- Does the model preserve the existing `HostPublication.publish` decision and
  avoid a second release path? `DurablePublication.prepare` calls that gate,
  retains its proposed result and discards its effect; preparation is not a
  durable authorization. Review journal revision, uniqueness, coherence,
  exact-intent comparison, refusal and failure behavior in that context.
- Are monitor-owned, current and authenticated state and native facts stated as
  assumptions rather than inferred from public constructors or field equality?
  Can failure, inspection or capacity information escape without independent
  authorization? Do the model and proposed interfaces cover authority, epochs,
  inherited restrictions, budget, payment, time, sealing and exact scope at the
  actual serialization point?
- What is needed to preserve a submission's identity across crashes and to
  fence a delayed commit after a negative lookup? Review stale snapshot and
  witness reconciliation, all writers and revocation order, exact stored
  scope, authenticated receiver deduplication, and policy-bound atomic audit.
  These are unresolved protocols; ordinary absence or a matching old snapshot
  does not settle an unknown outcome.
- Are the resource and lifecycle preconditions adequate for a future host?
  The in-memory journal stops accepting entries at 64 and has no safe
  compaction design. Direct comparison inputs and other nested authority state
  need independent bounds. The retained synthetic 10,000-origin direct
  `DurableIntent.intent_equal` probe failed on generated Node with a stack
  overflow; this is an observed resource limit, not a host exploit or a
  completed mitigation. See [model review](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/docs/superpowers/records/2026-11-06-durable-publication/model-review.md).

## Evidence and limits

The reviewed preview retains 220 synthetic durable checks. Its Bend, workflow
and Nix inputs match the earlier tested source
[`c3a6092f5553f3e83fa1dd1107acefda62616349`](https://github.com/Spaceghost/writ/commit/c3a6092f5553f3e83fa1dd1107acefda62616349): see the
[exact-source platform evidence](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/verification/durable-proof-ci-c3a6092/README.md)
and [native CPU evidence](https://github.com/Spaceghost/writ/blob/00f8c7cdc63183400a55038defd4be63cdeb42f4/verification/durable-proof-native-c3a6092/README.md).
The tested combined suite passed 2,481 checks; the recorded Lean verdict covers
37 existing laws, none a durable-publication law. Platform results have their
own scopes: the Linux protected setup refusal and Genode clock warning are
retained; no protected-host qualification follows. The preview's later Genode
tooling changes were not covered by those runs. Check each record for exact
commands, source and limitations; OpenSpec validation is structural only.

The sampled mutation checks and separate-agent review are useful review aids,
not exhaustive verification or independent human security review. The
authentication and pending-rollback probes demonstrate missing preconditions,
not actual authenticated recovery or duplicate native commits. The model does
not supply an atomic durable store, trusted rollback witness, qualified sink,
native crash/recovery, confined worker, or a complete authenticated transaction
format. No GPU test, durable law, native durability or production acceptance
is implied by a model test or this packet.
