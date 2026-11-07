# Proposed bounded locality conjunction

For a synthetic raw-input join, one supplied rule allows only domain A and a
second allows only B. Given the candidate list `[A, B]`, neither listed candidate
satisfies both rules. If the first rule instead allows `[A, B]` and the second
still allows B, a listed match exists. This reports a property of those supplied
descriptions, not an eligible executor or permission to run the join.

The proposed [locality requirements](specs/locality-aware-execution/spec.md)
remain unimplemented as an integrated placement service. The bounded Bend
reference model implements only the synthetic conjunction described below for
part of LE-001 and LE-009; its [test and mutation evidence](../../../verification/locality-conjunction/README.md)
does not establish the acceptance contracts.
All [locality tasks](tasks.md) remain open. In particular, a no-match result for
the supplied finite list does not establish that no executor exists elsewhere,
and LE-009's local-subcomputation alternative still needs a distinct complete
plan and all required approvals. There is no automatic fallback.

## Input and result

The proposed model accepts a version word, a list of requirements and a finite
list of candidate domain IDs. Version 1 is the sole supported version. IDs are
opaque U32 values compared by exact equality, including zero and the maximum U32;
there is no inferred geography, hierarchy, or relationship between distinct IDs.
These IDs are not authenticated host identities and are not equated to the
existing `Transfer.ReadDomain`, `Transfer.WriteDomain`, or issuance source-domain
namespaces. No provider, source, or host registry is consulted.

Each requirement is one of:

* `Allowed(domains)`: a mandatory disjunction over exactly the supplied domain
  IDs. An empty list explicitly allows no candidate.
* `Unrestricted`: an explicit description imposing no domain restriction.
  It is not inferred from a missing field or empty allowed list. If later used
  in a real system, its provenance and current applicability must be separately
  authenticated; this synthetic constructor cannot do that.
* `Missing`: the relevant description is unknown or absent, so the result is
  incomplete, not unrestricted.
* `Unsupported`: a description or mandatory field this model cannot represent;
  it is rejected, not ignored or treated as a preference.

Every supplied requirement applies to the same hypothetical execution: allowed
IDs within a rule are ORed; rules are ANDed. Duplicate and conflicting entries
remain separate conjuncts in either order, never last-wins. Candidate and allowed
domain duplicates do not affect the answer. There is no preference input; a
preference cannot replace a mandatory rule. Version 1 is a synthetic profile of
this model, not a registered placement contract or wire protocol.

After complete validation, the result is `ListedMatchExists` if any supplied
candidate satisfies every requirement, otherwise `NoListedMatch`. An empty
candidate list gives `NoListedMatch`; an empty requirements list gives
`MissingRequirements`, not a vacuous match. These results do not identify or rank
a candidate, offer, provider, or execution. They are descriptive results, not
grants, denials of all possible placements, admission, commits, or effects.

The model cannot detect an omitted applicable requirement merely because other
requirements are present. A future trusted composition must determine every
applicable current requirement, including all inherited data origins and
protected query, code, model, configuration and tool inputs; bind their source
versions and applicable rules; and authenticate the observations. `Missing`
only represents a missing item that the caller actually supplied as such.
`Transfer.required_origins` alone is not a complete enumeration of all LE-002
protected inputs. A provider's unverified domain label is not LE-003 host evidence.
The model also cannot determine whether an allegedly unrestricted description is
true or current. Publicly constructible values are not authority facts.

## Bounds, validation and precedence

For this proposed first profile, accept at most eight requirements, eight
candidates, and eight allowed IDs in each `Allowed` requirement. Counts over a
cap are rejected, never truncated. Candidate IDs and allowed IDs are fixed-width
U32, so each comparison has a fixed representation and cost.

Validation precedes matching, including when an earlier rule would exclude every
candidate. Outcomes have this deterministic precedence:

1. Unsupported version: `UnsupportedVersion`.
2. More than eight requirements: `TooManyRequirements`.
3. More than eight candidates: `TooManyCandidates`.
4. No requirements: `MissingRequirements`.
5. Scan requirements in input order; the first `Missing`, `Unsupported`, or
   `Allowed` with more than eight IDs yields respectively `MissingRequirement`,
   `UnsupportedRequirement`, or `TooManyAllowedDomains`. An empty `Allowed`
   is valid and is not confused with any of these errors.
6. Only after all validation succeeds, compute `ListedMatchExists` or
   `NoListedMatch` as above.

Thus a late invalid rule is reported even after an early empty allowed set, and a
matching early candidate cannot hide a later malformed rule. Reordering valid
requirements or candidates cannot widen the match result; reordering invalid
requirements may change which first rule error is reported. These local diagnostic
variants are synthetic; exposing placement errors or candidate metadata later
requires separate authorization under LE-010.

Each cap check must inspect no more than cap plus one list constructors, with
separate matched branches before examining the next list or calling any recursive
membership/matching helper. In particular, do not put an unbounded length,
conversion, recursive traversal, or membership call in the same eager expression
as its guard, rely on Boolean short-circuiting, build a full intermediate list, or
scan the rest of an overlong list. Validate every nested list under its own cap
before matching. Once validated, at most 8 × 8 × 8 fixed-width equality checks are
needed for the straightforward search, plus bounded preflight. This must hold for
the pinned Bend interpreter and generated Node evaluation. It does not bound the
cost of constructing an already supplied list or a future parser/transport;
those require their own allocation and framing limits.

## Synthetic tests

The names below describe scenario groups. The exact named assertions appear in
[`LocalityConjunctionTests.bend`](../../../LocalityConjunctionTests.bend); the
linked evidence records the executions, limits, and temporary mutations.

* `overlap_later_member` and `disjoint_singletons`: exercise the example above,
  including a positive match that is not the first allowed member.
* `unrestricted_is_explicit`, `missing_is_incomplete`, `empty_allowed_denies`,
  and `empty_requirements_incomplete`: distinguish the four cases without
  inferring unrestricted from absence.
* `conflicting_duplicate_rules_both_orders`, `valid_reorder_invariant`, and
  `duplicate_domain_invariant`: preserve conjunction and order-independent
  match semantics rather than overriding earlier entries.
* `candidate_empty_no_listed_match` and `opaque_full_width_ids`: cover the empty
  candidate list, zero and maximum U32, and exact identity without nesting.
* `version_and_error_precedence`, `first_invalid_rule_precedence`, and
  `late_invalid_after_empty_rule`: assert all six validation stages, including
  competing faults and validation after an already excluding rule.
* `requirements_cap_and_cap_plus_one`, `candidates_cap_and_cap_plus_one`, and
  `allowed_cap_and_cap_plus_one`: test each bound and far-over-cap input without
  traversal beyond cap plus one, under Bend and Node with a timeout. Include a
  late over-cap allowed list and a matching early candidate.
* `unsupported_is_not_preference` and `added_rule_cannot_widen`: verify that an
  unsupported description does not become a hint and that adding a valid
  conjunct cannot create a match for the same candidate list.
* `dropped_conjunct_mutant`: a temporary isolated mutation removes one
  conjunction check and the disjoint control fails. A satisfying positive
  control passes on the unmodified model; a constant-false implementation is
  not adequate evidence.

Any later proof must state its exact assumptions and limitations; proving only
that rejected candidates are never admitted can be vacuous for a constant-false
function. The proposed tests and optional proof cannot authenticate facts, prove
all applicable rules were supplied, or establish any native confinement.

## Integration remains open

This is not a placement contract implementation, offer-ranking algorithm,
registry, requester-input authorization, host-evidence verifier, route, admission
gate, policy engine, or effect executor. Future work must also preserve existing
authority, movement, epoch, budget and exact-scope checks at commit. In particular,
existing `Rendezvous` selection and dispatch re-read their trusted current state;
this design neither hooks nor changes those gates. No current task, host
qualification, LE-002/003 acceptance, or native behavior is claimed here.
