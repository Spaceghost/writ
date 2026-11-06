# Durable publication traceability — proposed change, partial model

The contract is [add-durable-publication](../changes/add-durable-publication/specs/durable-publication/spec.md).
No DP acceptance scenario is complete: this lane has pure reference transitions
and tests, not a durable store, authenticated witness, qualified sink, native
crash/recovery evidence, or confined worker. An in-memory `Advanced` value is
not evidence of a committed transaction. Constructors do not authenticate
monitor state, a sealed artifact, or an external acknowledgement.

| Requirement | Named model evidence | Remaining gap |
| --- | --- | --- |
| DP-001 durable before visibility | `durable preparation retains the proposed committed state and exact artifact`; `durable journal models one atomic host, session, ledger and intent update` | Preparation emits no publication effect, but no native transaction or durability barrier exists. The model does not prove visibility, atomic storage or pre-commit crash behavior. |
| DP-002 current revisions | `durable journal refuses a stale serialization revision`; `durable journal rejects the second competing transaction at the original revision` | Journal revision models one serialization domain; actual current grants, host identity, time, sealing and storage must be serialized and tested on a host. |
| DP-003 revocation ordering | `durable journal refuses a worker identity revoked before preparation`; `durable journal retains the modeled committed intent after later revocation` | Both tests use synthetic state; no native revocation/transaction race or durable outcome is established. |
| DP-004 exact recovery | `durable journal retains the existing host gate's entire write intent`; `durable journal rejects a recovery backend substitution`; `durable journal rejects a recovery receipt substitution`; `durable journal rejects a recovery quote substitution`; `DurableIntentTests.bend`'s destination, artifact, label, output, origin and payment substitution cases | `inspect` compares against a trusted in-memory record only. No authenticated record, unknown-outcome lookup, restart or native recovery exists. |
| DP-005 sink deduplication | None | No sink protocol, receiver authentication, durable deduplication or after-delivery crash test exists. |
| DP-006 origins and labels | `durable intent detects a removed origin`; `durable intent detects changed origin payment terms`; `durable intent detects a changed confidentiality delegate`; `durable intent detects a changed integrity delegate` | These compare in-memory representations. No policy-bearing native store or reload/copy/rename evidence exists. |
| DP-007 rollback resistance | `durable journal refuses a receipt absent from ledger replay state`; `durable journal rejects a publication absent from ledger committed invocations` | Membership and current revision checks do not authenticate history or detect restoration of a consistently old snapshot. No independent witness or reconciliation protocol exists. |
| DP-008 unsupported idempotency | None | There is no registered or qualified sink, sink admission, or native delivery path. |

The separate `DurableEncodingTests.bend` includes `durable encoding matches
the complete hand-calculated word vector`, `durable encoding distinguishes
origin payment quotes`, and `durable encoding refuses rather than truncating
an oversized Nat`. These exercise an experimental bounded word representation
of a single journal entry. `DurableDecodingTests.bend` adds bounded word-level
roundtrips and malformed-input checks, including `durable decoding rejects
every truncated golden prefix` and `durable decoding roundtrips the complete
maximum-size entry`. `DurableBytesTests.bend` adds the experimental
little-endian byte mapping, including `durable bytes use the hand-calculated
little-endian header` and rejection of an out-of-range byte whose packed word
would be unchanged. These do not establish a complete transaction format,
authenticated storage, or DP-004/006 recovery.
The experimental entry layout and its limits are documented in
[`docs/DURABLE-PUBLICATION.md`](../../docs/DURABLE-PUBLICATION.md).

Additional model checks reject malformed duplicate records and enforce a
64-record bound, including refusing an otherwise valid authorization at
capacity. This bounded reference never prunes history; safe compaction and
migration require separate authenticated checkpoint/replay evidence. The
`Inspection` and `Transition` diagnostics are monitor-private; any external
status requires separate authorization and policy-safe disclosure.

The detailed model limitations and test status are recorded in
[`task-2-report.md`](../../docs/superpowers/records/2026-11-06-durable-publication/task-2-report.md),
and unresolved storage, anchor, and receiver interfaces in
[`recovery-design.md`](../../docs/superpowers/records/2026-11-06-durable-publication/recovery-design.md).
