# Independent review

The existing review agent examined the design and implementation separately
from the implementer. No review-agent edits were made.

- Require one checked commit and keep provisional state/effects private.
  Resolved by effect-free HostPublication.prepare, a shared audit projection,
  and confirmation as the initial durable delivery gate. Legacy publication
  remains only an explicitly scoped pure-model compatibility API.
- High: the first record omitted host replay state needed after a crash.
  Resolved by Recovery's complete publication replay projection and a cold
  restore transition. Restore requires an empty, strictly later incarnation
  and retains the consumed ledger state. Tests restore from durable contents.
- Medium: digest alone did not specify a reopenable sealed artifact.
  Resolved by retaining and comparing the worker/object/version/digest locator.
  Actual immutable reopening and digest verification remain native obligations.
- Low: sequence numbers could repeat across epochs. Resolved by explicit
  composite host/epoch/sequence audit idempotency keys and tests.
- API boundary: Deliver initially carried private ledger/audit/replay data.
  Resolved by a distinct minimal Delivery envelope. Full-record receiver
  reconciliation stays within private monitor storage. The reviewer endorsed
  this narrowing; no external wire-protocol qualification is inferred.

The reviewer found no remaining source-level correctness blocker in the
reviewed model changes. They independently counted 84 syntactic assertions,
with two mutually exclusive failure branches: 82 checks on the success path.
Native compiler layout work and final verification were still in progress at
that review; later results must be recorded separately.

Final review also examined the boxed predecessor state and capacity-one receiver
log. It found no changed gate ordering or authorization rule: resolve accepts
only an immediate Idle predecessor, and the receiver refuses a longer log.
The new guard cases bring the reviewed successful count to 84 (86 syntactic
assertions, with the same two exclusive failure branches).

The law changes during boxing replace a pending Snapshot field with the same
Snapshot inside its retained Idle predecessor. This is a representation change
for the same reachable states, not weaker authority assumptions. Malformed
predecessors are separately refused. A fifth ordinary law prevents restoration
from an unknown storage outcome.
