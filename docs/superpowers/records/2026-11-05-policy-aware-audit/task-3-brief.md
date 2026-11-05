### Task 3: Event policy from authoritative data and control influences (task 1.2; AU-002)

Implements "AU-002 Event policies include observed influences" (scenarios "Denial reveals a protected source fact" and "Multiple owners contribute evidence").

Add to `AuditEvent.bend` the types `Influence`, `Influences`, `Edge`, `EventPolicy`, `ObjectLabel`, `Labels` and `Recorded{event, policy}`, and these named helpers:
- `object_influence(labels, object, edge)`, which returns the maximal-restriction influence on a missing or ambiguous entry;
- `source_influences(labels, objects)`, data edges in manifest order;
- `destination_influence(labels, object)`, a data edge;
- `decision_influences(labels, plan)`: the sources plus the destination as data edges, and the same objects again as control edges. The control copies record that the outcome and reason depend on their policies; see the "Reasons" ruling;
- `binding_influence(binding, owner)`: the `D.join(source_label, destination_label)` of the resolved binding, as a control edge owned by the destination's owner;
- `context_secrecy(context)` and `context_untrusted(context)`, the joins over `T.Context.sources`;
- `admission_policy(plan, context, labels)` and `commit_policy(session, context, labels)`. Neither takes the decision or the result as an argument;
- `influences_flow(snapshot, epoch, influences, sink_label)` (all elements, `&&`) and `releasable(snapshot, epoch, policy, sink)`;
- `event_owners(influences)`.

`audited_admit` and `audited_commit` now also return `recorded: Recorded`, with the policy computed from the authoritative inputs. The Task 1 laws keep their statements, because they speak of the `decision`/`result` and `event` components. Ruling: no helper takes an `Influences` argument from a caller in order to add, remove or replace an element.

Add laws:
- `audit_failed_influence_withholds`: for all `snapshot`, `epoch`, `before`, `after`, influence `i` and `sink_label`, with the hypothesis `{D.flows(snapshot, epoch, Influence.label(i), sink_label) == False{}}`, `influences_flow(snapshot, epoch, Influences.append(before, Influences.cons(i, after)), sink_label) == False{}`. The proof is by induction on `before`, as in `failed_check_denies`. Rationale: one owner's unsatisfied restriction, at any position, withholds the event; approvals from the other owners cannot outweigh it. Mutant to show: `||` in place of `&&`, or a walk that stops at the first satisfied element. It does not prove that `releasable` is the only route to a sink; Tasks 4 and 5 show that by tests.
- `audit_outcome_never_lowers_policy`: `Recorded.policy(AuditedAdmission.recorded(audited_admit(plan, context, labels, caller, diagnostic, event_id))) == admission_policy(plan, context, labels)` for all inputs. Rationale: whatever the decision, the policy is the outcome-independent policy of the plan's facts. A protected denial reason is therefore labelled exactly as the facts it may reveal, never lower. Mutant to show: a denial branch that substitutes `D.public_untrusted()`.

Tests (`event_policy` section). Use `D.fixture(3n)` with Alice `Named{0}` and Bob `Named{1}`; Mallory is the outsider:
- "Denial reveals a protected source fact":
  - Bob's source object 11 and an origin rule that excludes the plan's code give an event that is `DeniedFor{Origin{}}`.
  - Its influences contain Bob's label for object 11, as data and as control.
  - It is not `releasable` to Alice-only sink 1, and it is releasable to sink 3, whose label satisfies both owners.
  - The same holds for a `Payment` denial and a `Schema` denial.
- "Multiple owners contribute evidence":
  - An Alice-and-Bob event's influences contain both owners as separate elements (`event_owners` gives both).
  - A sink satisfying Alice's label but not Bob's is not releasable, and one satisfying both is.
  - A second Alice influence added to the label table does not remove Bob's.
- Unlabelled source and duplicate label entries each give the maximal-restriction influence, and that event is releasable to no fixture sink.
- Secrecy: a sink whose DLM label flows but whose `clearance` lacks the source's secrecy bit is not releasable. The same goes for `tolerated` against untrusted bits.
- The policy is outcome-independent: an admitted event and a denied event for the same plan and label table have equal influences, secrecy and untrusted sets. Tested with a test-side `EventPolicy.equal`.
- A commit event's policy includes the binding influence from `BF.binding()`.
- Mutation pins: dropping the control copies, dropping the binding influence, dropping a source from `source_influences`, and making a missing label public each fail a named check.

Estimate about 28 checks. Check box 1.2.

Acceptance:
- Suite green at about plus 93.
- Proofs green with 23 laws (or the recorded exception).
- Every influence-derivation mutant is killed.

