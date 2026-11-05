# Task 2 report: versioned canonical encoding with a field allowlist

Status: DONE_WITH_CONCERNS (concerns at the end: a layout ruling for
`ScopeNotRead{}`, which the brief predates; a stricter encoder than the brief
lists; a widened `OutOfOrder`; renamed and renumbered Task 1 tag helpers; the
check count is well above the estimate).

Implements the format half of AU-001 "Minimal scoped event records": a
versioned canonical binary event format with an allowlist of fields. Box 1.1
of `openspec/changes/add-policy-aware-audit/tasks.md` is checked, citing the
`event_projection` and `event_format` sections and the four Task 1 laws. The
first line of tasks.md is left for Task 6.

## Files

- Extended: `AuditEvent.bend` (codec section appended; header gains
  "Canonical encoding" and "Per-field sensitivity"; tag helpers named),
  `AuditTests.bend` (section `event_format`, header note),
  `openspec/changes/add-policy-aware-audit/tasks.md` (box 1.1 only).
- Unchanged: `Tests.bend` (Task 1's two-line registration), `LAWS.bend`,
  `PROOF.bend` (`git diff 776e671 -- Tests.bend LAWS.bend PROOF.bend` is
  empty).
- Records: this report, `activity.log`.
- Outside the tree: mutants under
  `../writ-build/policy-aware-audit/mutants/task-2/<id>/`, the table
  `../writ-build/policy-aware-audit/mutants/task-2.tsv` and `task-2-table.md`,
  captures `check-t2.txt`, `audit-t2.txt`, `tests-t2.txt`, `proof-t2.txt` in
  `../writ-build/policy-aware-audit/`. Mutation script:
  `scratchpad/policy-aware-audit/mutate2.py` (session scratchpad).

## Word layout

Every value is one U32 word, little-endian when carried as bytes (HostWire's
discipline; this module defines no byte step).

- Header, 3 words: `event_format_version()` (1), the kind tag
  (`kind_admission_admitted()` 1, `kind_admission_denied()` 2,
  `kind_commit_accepted()` 3, `kind_commit_rejected()` 4), the body length in
  words.
- Body: every field of `field_allowlist()` in order, each a tag word, a
  length word, and that many value words.

| tag | field | value words |
|---|---|---|
| 1 `field_event_id()` | event id | 1 |
| 2 `field_subject()` | subject | 1 |
| 3 `field_phase()` | phase (`phase_admission()` 0, `phase_commit()` 1) | 1 |
| 4 `field_invocation()` | invocation | 1, or 0 under `ScopeNotRead{}` |
| 5 `field_sources()` | ordered source versions | 2 per entry, at most `max_sources()` = 16 entries; 0 under `ScopeNotRead{}` |
| 6 `field_destination()` | destination version | 2, or 0 |
| 7 `field_stamp()` | graph, policy, authority epochs | 3, or 0 |
| 8 `field_code()` | code | 8, or 0 |
| 9 `field_op()` | operation kind (`T.OpKind.bit`: 1, 2, 4) | 1, or 0 |
| 10 `field_artifact()` | sealed artifact digest | 8, or 0 for None |
| 11 `field_outcome()` | `outcome_tag` (0 Admitted, 1 DeniedFor, 2 Committed, 3 NotCommitted), plus `reason_tag` (0 to 9) for DeniedFor | 1, or 2 for DeniedFor |

Tags 12, 13 and 14 (`field_reserved_payload()`, `field_reserved_token()`,
`field_reserved_text()`) are reserved and never allowed. `max_words()` is
3 + 2 x 11 + 60 = 85 (a bound: no single event reaches it, since only an
accepted commit has an artifact and only a denial a reason word).
`word_limit()` is 2^32 (`Nat.add(4294967295n, 1n)`, because a Nat literal
stops at 4294967295n).

Golden vectors pinned by tests: the distinct-valued committed record encodes
to `[1, 3, 53, 1, 1, 1001, 2, 1, 1002, 3, 1, 1, 4, 1, 1003, 5, 4, 1004, 1005,
1006, 1007, 6, 2, 1008, 1009, 7, 3, 1010, 1011, 1012, 8, 8, 1013 ... 1020, 9,
1, 2, 10, 8, 1021 ... 1028, 11, 1, 2]`, and a Stale denial with
`ScopeNotRead{}` to `[1, 2, 27, 1, 1, 1001, 2, 1, 1002, 3, 1, 0, 4, 0, 5, 0,
6, 0, 7, 0, 8, 0, 9, 0, 10, 0, 11, 2, 1, 1]`.

## The allowlist helper and who reads it

`field_allowlist() -> FieldTags` is the ordered list of tags 1 to 11. It is
the only def that names the set of tags.
- The encoder: `encode` -> `emit(field_allowlist(), e)`, one field per tag,
  values from `field_values(tag, e)`. A tag with no record field gives None
  (encode fails rather than emit an empty field).
- The decoder: `check_body_length` -> `walk_all(field_allowlist(), body)`;
  `read_field` checks each tag with `field_allowed` and against the next
  allowlisted tag.
- `field_allowed(tag)` = `tag_listed(field_allowlist(), tag)`.
- `max_words()` counts its tags (`tag_count(field_allowlist())`).
- The tests: "AU-001 format: field_allowlist() is exactly tags 1 to 11 in
  order" (against a test-side list) and the `field_allowed` checks.
`interpret` reads the walked fields positionally; the allowlist's order is
the record's field order, and any other field count is BadLength (see V19).

## Rejections and their checks

The check order is fixed and documented in the header (steps 1 to 8).
Input ending before a header word is BadLength at that step.

| step | condition | reason | check(s) |
|---|---|---|---|
| 1 | more than `max_words()` words | TooLong | "more than max_words words denied TooLong"; order: "the length cap precedes the version" |
| 2 | version word not 1 | UnknownVersion | "version 0 / version 2 / version 0xFFFFFFFF denied UnknownVersion"; order: "the version precedes the kind" |
| 3 | kind word not 1 to 4 | UnknownKind | "kind 0 / kind 5 denied UnknownKind"; order: "the kind precedes the body length" |
| 2-4 | input ends before a header word | BadLength | "empty input, a version word only, and version and kind only denied BadLength" |
| 4 | body length word not the remaining count | BadLength | "a body length word one short / one long denied BadLength", "a truncated body denied BadLength", "one trailing word denied BadLength" |
| 5 | no word left for the next field | BadLength | "a missing last field (the outcome) denied BadLength" |
| 5 | tag not allowed | NotAllowed | "a field tagged as payload (12) / as a token (13) in place of the code / as text (14) before the event id is denied NotAllowed and builds no event", "field tags 0 and 15 are denied NotAllowed"; order: "the field walk precedes field widths" |
| 5 | allowed tag that is not the next | OutOfOrder | "two fields out of allowlist order", "a duplicate field", "a missing middle field (the subject) denied OutOfOrder" |
| 5 | no length word | BadLength | "a field tag with no length word denied BadLength" |
| 5 | fewer value words than the length names | BadLength | "a field length word naming more words than remain denied BadLength" |
| 6 | words after the last field | BadLength | "a word after the last field, counted by the body length, denied BadLength" |
| 7 | width other than the field's | BadLength | "a field one word short (stamp length 2)", "one word long (stamp length 4)", "event id, subject and phase of other than one word", "invocation, destination, code and operation of the wrong width", "an odd number of source words", "an artifact of seven words", "an empty invocation with another scope field present", "a present invocation with an empty destination", "a DeniedFor outcome without its reason word", "a Committed outcome with a second word", "an outcome of three words or of none" |
| 7 | more than `max_sources()` sources | TooLong | "more than max_sources sources denied TooLong (inside the length cap)" (78 words, so step 1 does not fire); "exactly max_sources sources decode" |
| 7 | word outside its closed set | OutOfRange | "phase word 2 denied OutOfRange", "phase word 2 on an admission event", "operation words 0 and 3", "outcome word 7", "outcome word 7 on an admission event", "reason word 10" |
| 8 | not coherent (`event_coherent`) | OutOfRange | "an Admission phase on a CommitAccepted event", "a Committed outcome under kind AdmissionAdmitted", "an artifact on a CommitRejected or AdmissionAdmitted event", "a scope on a Stale denial, or none on a Read denial", "a CommitAccepted event without a scope", "an outcome contradicting only the kind (...)"; order: "field widths and values precede coherence" |

Encoder refusals (`encode` is None): "an invocation of 2^32", "an event id or
subject of 2^32", "a source object or version of 2^32", "a destination object
or version of 2^32", "any of the three epochs at 2^32", "17 sources (more
than max_sources)", and the incoherent records ("version is not the
format's", "kind contradicts its outcome", "kind alone contradicts its
outcome", "phase contradicts its kind", "an artifact on a rejected commit, or
none on an accepted one", "a scope on an early denial, or none on a
scope-reading outcome"). Boundaries accepted: "an invocation of 2^32 - 1
encodes and round trips", "16 sources encode and round trip".

The tests' `rejected` compares a test-side reason code, so a rejection check
does not depend on `FormatError.equal` (which batch 1 showed it did; see F1).

## Round-trip checks

`round_trips(e)` requires `decode(encode(e))` to be `Decoded{d}` with
`EventRecord.equal(d, e)` and the test-side flattening `event_words(d)` equal
to `event_words(e)` (independent of AuditEvent's equality).
- Projected (from the wrappers): "a projected AdmissionAdmitted event round
  trips"; "projected AdmissionDenied events for all ten denial reasons round
  trip, early ones with ScopeNotRead"; "projected CommitAccepted events round
  trip with their artifact" (two artifacts); "a projected CommitRejected event
  round trips with no artifact"; "ScopeNotRead events round trip and no
  caller-written plan word occurs in their encoding"; "no diagnostic or
  caller-token sentinel occurs in an encoded event".
- Distinct-valued SYNTHETIC records (every field a different number,
  1001 to 1028): AdmissionAdmitted, CommitAccepted, CommitRejected; all ten
  denial reasons (scope present for Read, Origin, Payment, `ScopeNotRead{}`
  otherwise); two `ScopeNotRead{}` records explicitly.
- Reverse direction: "accepted word lists re-encode to exactly themselves"
  (both golden vectors, a Payment denial and a rejected commit).
- Layout: the two golden vectors above.
- E1/E2/E5: "a decoded record and one differing only in version / only in
  kind / only in phase compare unequal". A decoder output is always coherent,
  so two decoded records cannot differ in only one of these; each check
  compares the decoded record with a hand-written one that differs in exactly
  that field.

## New checks (88, section `event_format`)

- AU-001 format: a projected AdmissionAdmitted event round trips
- AU-001 format: projected AdmissionDenied events for all ten denial reasons round trip, early ones with ScopeNotRead
- AU-001 format: projected CommitAccepted events round trip with their artifact
- AU-001 format: a projected CommitRejected event round trips with no artifact
- AU-001 format: ScopeNotRead events round trip and no caller-written plan word occurs in their encoding
- AU-001 format: no diagnostic or caller-token sentinel occurs in an encoded event
- AU-001 format: distinct-valued AdmissionAdmitted, CommitAccepted and CommitRejected records round trip
- AU-001 format: distinct-valued AdmissionDenied records round trip for every denial reason
- AU-001 format: distinct-valued ScopeNotRead records round trip
- AU-001 format: encode emits the documented layout (header, then tag, length and values per field in allowlist order)
- AU-001 format: under ScopeNotRead every scope field and the absent artifact are length 0
- AU-001 format: accepted word lists re-encode to exactly themselves
- AU-001 format: a decoded record and one differing only in version compare unequal
- AU-001 format: a decoded record and one differing only in kind compare unequal
- AU-001 format: a decoded record and one differing only in phase compare unequal
- AU-001 format: field_allowlist() is exactly tags 1 to 11 in order
- AU-001 format: field_allowed accepts every allowlisted tag
- AU-001 format: field_allowed refuses the reserved payload, token and text tags, 0 and 15
- AU-001 format: the length cap is 3 header words, 2 per field and 60 value words
- AU-001 format: encode of an invocation of 2^32 is None
- AU-001 format: an invocation of 2^32 - 1 encodes and round trips
- AU-001 format: encode of an event id or subject of 2^32 is None
- AU-001 format: encode of a source object or version of 2^32 is None
- AU-001 format: encode of a destination object or version of 2^32 is None
- AU-001 format: encode of any of the three epochs at 2^32 is None
- AU-001 format: encode of 17 sources (more than max_sources) is None
- AU-001 format: 16 sources encode and round trip
- AU-001 format: encode of a record whose version is not the format's is None
- AU-001 format: encode of a record whose kind contradicts its outcome is None
- AU-001 format: encode of a record whose phase contradicts its kind is None
- AU-001 format: encode of an artifact on a rejected commit, or none on an accepted one, is None
- AU-001 format: encode of a scope on an early denial, or none on a scope-reading outcome, is None
- AU-001 format: version 0 denied UnknownVersion
- AU-001 format: version 2 denied UnknownVersion
- AU-001 format: version 0xFFFFFFFF denied UnknownVersion
- AU-001 format: kind 0 denied UnknownKind
- AU-001 format: kind 5 denied UnknownKind
- AU-001 format: empty input, a version word only, and version and kind only denied BadLength
- AU-001 format: a body length word one short denied BadLength
- AU-001 format: a body length word one long denied BadLength
- AU-001 format: a truncated body denied BadLength
- AU-001 format: one trailing word denied BadLength
- AU-001 format: a field tagged as payload (12) is denied NotAllowed and builds no event
- AU-001 format: a field tagged as a token (13) in place of the code is denied NotAllowed and builds no event
- AU-001 format: a field tagged as text (14) before the event id is denied NotAllowed and builds no event
- AU-001 format: field tags 0 and 15 are denied NotAllowed
- AU-001 format: two fields out of allowlist order denied OutOfOrder
- AU-001 format: a duplicate field denied OutOfOrder
- AU-001 format: a missing middle field (the subject) denied OutOfOrder
- AU-001 format: a missing last field (the outcome) denied BadLength
- AU-001 format: a word after the last field, counted by the body length, denied BadLength
- AU-001 format: a field length word naming more words than remain denied BadLength
- AU-001 format: a field one word short (stamp length 2) denied BadLength
- AU-001 format: a field one word long (stamp length 4) denied BadLength
- AU-001 format: event id, subject and phase of other than one word denied BadLength
- AU-001 format: invocation, destination, code and operation of the wrong width denied BadLength
- AU-001 format: an odd number of source words denied BadLength
- AU-001 format: more than max_sources sources denied TooLong (inside the length cap)
- AU-001 format: exactly max_sources sources decode
- AU-001 format: more than max_words words denied TooLong
- AU-001 format: an artifact of seven words denied BadLength
- AU-001 format: an empty invocation with another scope field present denied BadLength
- AU-001 format: a present invocation with an empty destination denied BadLength
- AU-001 format: a DeniedFor outcome without its reason word denied BadLength
- AU-001 format: a Committed outcome with a second word denied BadLength
- AU-001 format: phase word 2 denied OutOfRange
- AU-001 format: operation words 0 and 3 denied OutOfRange
- AU-001 format: outcome word 7 denied OutOfRange
- AU-001 format: reason word 10 denied OutOfRange
- AU-001 format: an Admission phase on a CommitAccepted event denied OutOfRange
- AU-001 format: a Committed outcome under kind AdmissionAdmitted denied OutOfRange
- AU-001 format: an artifact on a CommitRejected or AdmissionAdmitted event denied OutOfRange
- AU-001 format: a scope on a Stale denial, or none on a Read denial, denied OutOfRange
- AU-001 format: a CommitAccepted event without a scope denied OutOfRange
- AU-001 format order: the length cap precedes the version
- AU-001 format order: the version precedes the kind
- AU-001 format order: the kind precedes the body length
- AU-001 format order: the field walk precedes field widths
- AU-001 format order: field widths and values precede coherence
- AU-001 format: a field tag with no length word denied BadLength
- AU-001 format: phase word 2 on an admission event denied OutOfRange
- AU-001 format: outcome word 7 on an admission event denied OutOfRange
- AU-001 format: an outcome of three words or of none denied BadLength
- AU-001 format: an outcome contradicting only the kind (a Read denial under AdmissionAdmitted, Committed under CommitRejected) denied OutOfRange
- AU-001 format: encode of a record whose kind alone contradicts its outcome is None
- AU-001 format: the encoder has no value for a reserved tag, so it could not emit one even if the allowlist named it
- AU-001 format: FormatError.equal separates all seven reasons
- AU-001 format: DecodeResult.equal separates events, reasons, and an event from a rejection

## Removal map (mutation pass)

Method: as in Task 1. Each mutant is one textual change to `AuditEvent.bend`
in a scratch copy under `../writ-build/policy-aware-audit/mutants/task-2/<id>/`;
each runs `bend AuditTests.bend` and `bend PROOF.bend`; the first FAIL line
is the killing check.

Batches:
- Batch 1 (94 compiled mutants, plus N24 which did not compile): survivors
  W4, V3, V5, V18, C3, F1, F2, F3, V19, N21.
  - W4 (missing field length word): no input ended right after a tag.
    Added "a field tag with no length word denied BadLength".
  - V3, V5, V18: the existing phase/outcome inputs were commit events, where
    a mutant's fallback (Admission, Admitted) then failed coherence with the
    same reason. Added the same inputs on admission events: "phase word 2 on
    an admission event", "outcome word 7 on an admission event", "an outcome
    of three words or of none".
  - C3 (coherence ignores kind/outcome): every kind contradiction also
    contradicted the phase. Added "an outcome contradicting only the kind"
    (decoder) and "encode of a record whose kind alone contradicts its
    outcome is None".
  - F1 to F3: the tests' `rejected` used `DecodeResult.equal`, so a broken
    `FormatError.equal` made every reason check vacuous. `rejected` now uses
    a test-side reason code; added "FormatError.equal separates all seven
    reasons" and "DecodeResult.equal separates events, reasons, and an event
    from a rejection".
  - N24's mutation needed `+i`; the script was fixed.
- Batch 2: N21 still survived (an unreachable fallback). Because it is the
  encoder's guard against a reserved tag, it is now pinned directly: "the
  encoder has no value for a reserved tag, so it could not emit one even if
  the allowlist named it".
- Final batch (clean rerun on the commit tree): 97 mutants, 96 killed, 1
  equivalent (V19), 0 unexplained survivors. Every mutant leaves the proofs
  checking: there are no codec laws, and the 21 laws do not mention the
  codec or the renamed tags.

Equivalent mutant:
- V19: `interpret`'s fallback arm (any number of walked fields other than 11)
  changed from BadLength to OutOfRange. `walk_all` and `walk` produce exactly
  one field per allowlisted tag, and the allowlist has 11, so the arm is
  unreachable in this tree. It is the arm that rejects under A1 to A11, which
  are killed by the round trips.

| id | mutation | tests | proofs |
|---|---|---|---|
| A1 | allowlist drops field_event_id() | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A2 | allowlist drops field_subject() | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A3 | allowlist drops field_phase() | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A4 | allowlist drops field_invocation() | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A5 | allowlist drops field_sources() | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A6 | allowlist drops field_destination() | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A7 | allowlist drops field_stamp() | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A8 | allowlist drops field_code() | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A9 | allowlist drops field_op() | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A10 | allowlist drops field_artifact() | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A11 | allowlist drops field_outcome() | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A12 | allowlist adds tag 12 at the end | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A13 | allowlist adds tag 12 at the front | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A14 | allowlist swaps event_id and subject | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| A15 | field_allowed always True | killed: AU-001 format: field_allowed refuses the reserved payload, token and text tags, 0 and 15 | proofs check |
| A16 | tag_listed NoTags -> True | killed: AU-001 format: field_allowed refuses the reserved payload, token and text tags, 0 and 15 | proofs check |
| A17 | field_reserved_payload is 11 | killed: AU-001 format: field_allowed refuses the reserved payload, token and text tags, 0 and 15 | proofs check |
| H1 | no length cap | killed: AU-001 format: more than max_words words denied TooLong | proofs check |
| H2 | version check skipped | killed: AU-001 format: version 0 denied UnknownVersion | proofs check |
| H3 | unknown kind decodes as CommitAccepted | killed: AU-001 format: kind 0 denied UnknownKind | proofs check |
| H4 | body length check skipped | killed: AU-001 format: a body length word one short denied BadLength | proofs check |
| H5 | empty input -> OutOfRange | killed: AU-001 format: empty input, a version word only, and version and kind only denied BadLength | proofs check |
| H6 | missing kind word -> OutOfRange | killed: AU-001 format: empty input, a version word only, and version and kind only denied BadLength | proofs check |
| H7 | missing length word -> OutOfRange | killed: AU-001 format: empty input, a version word only, and version and kind only denied BadLength | proofs check |
| H8 | kind tags collide (admitted = denied) | killed: AU-001 EventKind.equal and Phase.equal separate their constructors | proofs check |
| W1 | NotAllowed skipped | killed: AU-001 format: a field tagged as payload (12) is denied NotAllowed and builds no event | proofs check |
| W2 | OutOfOrder skipped | killed: AU-001 format: two fields out of allowlist order denied OutOfOrder | proofs check |
| W3 | missing field word -> OutOfRange | killed: AU-001 format: a missing last field (the outcome) denied BadLength | proofs check |
| W4 | missing field length word -> OutOfRange | killed: AU-001 format: a field tag with no length word denied BadLength | proofs check |
| W5 | short field accepted | killed: AU-001 format: a field length word naming more words than remain denied BadLength | proofs check |
| W6 | trailing words ignored | killed: AU-001 format: a word after the last field, counted by the body length, denied BadLength | proofs check |
| V1 | parse_word any width | killed: AU-001 format: event id, subject and phase of other than one word denied BadLength | proofs check |
| V2 | parse_phase any width | killed: AU-001 format: event id, subject and phase of other than one word denied BadLength | proofs check |
| V3 | unknown phase word -> Admission | killed: AU-001 format: phase word 2 on an admission event denied OutOfRange | proofs check |
| V4 | unknown op word -> Copy | killed: AU-001 format: operation words 0 and 3 denied OutOfRange | proofs check |
| V5 | unknown outcome word -> Admitted | killed: AU-001 format: outcome word 7 on an admission event denied OutOfRange | proofs check |
| V6 | unknown reason word -> Stale | killed: AU-001 format: reason word 10 denied OutOfRange | proofs check |
| V7 | denied_reason None accepted as Stale | killed: AU-001 format: reason word 10 denied OutOfRange | proofs check |
| V8 | parse_object any width | killed: AU-001 format: invocation, destination, code and operation of the wrong width denied BadLength | proofs check |
| V9 | odd source word dropped | killed: AU-001 format: an odd number of source words denied BadLength | proofs check |
| V10 | sources TooLong skipped | killed: AU-001 format: more than max_sources sources denied TooLong (inside the length cap) | proofs check |
| V11 | parse_stamp any width | killed: AU-001 format: a field one word short (stamp length 2) denied BadLength | proofs check |
| V12 | parse_code any width | killed: AU-001 format: invocation, destination, code and operation of the wrong width denied BadLength | proofs check |
| V13 | parse_op any width | killed: AU-001 format: invocation, destination, code and operation of the wrong width denied BadLength | proofs check |
| V14 | mixed empty scope accepted as ScopeNotRead | killed: AU-001 format: an empty invocation with another scope field present denied BadLength | proofs check |
| V15 | multi-word invocation accepted as ScopeNotRead | killed: AU-001 format: invocation, destination, code and operation of the wrong width denied BadLength | proofs check |
| V16 | DeniedFor word alone not BadLength | killed: AU-001 format: a DeniedFor outcome without its reason word denied BadLength | proofs check |
| V17 | second outcome word accepted on non-denied | killed: AU-001 format: a Committed outcome with a second word denied BadLength | proofs check |
| V18 | parse_outcome any width -> Admitted | killed: AU-001 format: an outcome of three words or of none denied BadLength | proofs check |
| V19 | interpret field-count mismatch -> OutOfRange | SURVIVED tests | proofs check |
| V20 | parse_artifact any nonempty width | killed: AU-001 format: projected CommitAccepted events round trip with their artifact | proofs check |
| C1 | incoherent record accepted | killed: AU-001 format: an Admission phase on a CommitAccepted event denied OutOfRange | proofs check |
| C2 | coherence ignores version | killed: AU-001 format: encode of a record whose version is not the format's is None | proofs check |
| C3 | coherence ignores kind/outcome | killed: AU-001 format: an outcome contradicting only the kind (a Read denial under AdmissionAdmitted, Committed under CommitRejected) denied OutOfRange | proofs check |
| C4 | coherence ignores phase | killed: AU-001 format: encode of a record whose phase contradicts its kind is None | proofs check |
| C5 | coherence ignores artifact | killed: AU-001 format: encode of an artifact on a rejected commit, or none on an accepted one, is None | proofs check |
| C6 | coherence ignores scope | killed: AU-001 format: encode of a scope on an early denial, or none on a scope-reading outcome, is None | proofs check |
| C7 | accepted commit may lack an artifact | killed: AU-001 format: encode of an artifact on a rejected commit, or none on an accepted one, is None | proofs check |
| C8 | non-commit may carry an artifact | killed: AU-001 format: encode of an artifact on a rejected commit, or none on an accepted one, is None | proofs check |
| C9 | every denial reads scope | killed: AU-001 format: projected AdmissionDenied events for all ten denial reasons round trip, early ones with ScopeNotRead | proofs check |
| C10 | Committed does not read scope | killed: AU-001 format: projected CommitAccepted events round trip with their artifact | proofs check |
| C11 | NotCommitted does not read scope | killed: AU-001 format: a projected CommitRejected event round trips with no artifact | proofs check |
| C12 | Admitted does not read scope | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| N1 | encode skips coherence | killed: AU-001 format: encode of a record whose version is not the format's is None | proofs check |
| N2 | encode skips Nat bounds | killed: AU-001 format: encode of an invocation of 2^32 is None | proofs check |
| N3 | encode skips source bound | killed: AU-001 format: encode of 17 sources (more than max_sources) is None | proofs check |
| N4 | fits always True | killed: AU-001 format: encode of an invocation of 2^32 is None | proofs check |
| N5 | word_limit one higher | killed: AU-001 format: encode of an invocation of 2^32 is None | proofs check |
| N6 | record_fits ignores event id | killed: AU-001 format: encode of an event id or subject of 2^32 is None | proofs check |
| N7 | record_fits ignores subject | killed: AU-001 format: encode of an event id or subject of 2^32 is None | proofs check |
| N8 | record_fits ignores scope | killed: AU-001 format: encode of an invocation of 2^32 is None | proofs check |
| N9 | scope_fits ignores invocation | killed: AU-001 format: encode of an invocation of 2^32 is None | proofs check |
| N10 | scope_fits ignores sources | killed: AU-001 format: encode of a source object or version of 2^32 is None | proofs check |
| N11 | scope_fits ignores destination | killed: AU-001 format: encode of a destination object or version of 2^32 is None | proofs check |
| N12 | scope_fits ignores stamp | killed: AU-001 format: encode of any of the three epochs at 2^32 is None | proofs check |
| N13 | object_fits ignores object | killed: AU-001 format: encode of a source object or version of 2^32 is None | proofs check |
| N14 | object_fits ignores version | killed: AU-001 format: encode of a source object or version of 2^32 is None | proofs check |
| N15 | objects_fit ignores later entries | killed: AU-001 format: encode of a source object or version of 2^32 is None | proofs check |
| N16 | stamp_fits ignores graph | killed: AU-001 format: encode of any of the three epochs at 2^32 is None | proofs check |
| N17 | stamp_fits ignores policy | killed: AU-001 format: encode of any of the three epochs at 2^32 is None | proofs check |
| N18 | stamp_fits ignores authority | killed: AU-001 format: encode of any of the three epochs at 2^32 is None | proofs check |
| N19 | encoder source bound 17 | killed: AU-001 format: encode of 17 sources (more than max_sources) is None | proofs check |
| N20 | max_sources 17 | killed: AU-001 format: the length cap is 3 header words, 2 per field and 60 value words | proofs check |
| N21 | field_values unknown tag -> empty field | killed: AU-001 format: the encoder has no value for a reserved tag, so it could not emit one even if the allowlist named it | proofs check |
| N22 | absent artifact emitted as one zero word | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| N23 | denied outcome drops its reason word | killed: AU-001 format: projected AdmissionDenied events for all ten denial reasons round trip, early ones with ScopeNotRead | proofs check |
| N24 | subject field emits the event id | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| T1 | reason_tag Read collides with Write | killed: AU-001 denial_equal separates all ten denial reasons | proofs check |
| T2 | outcome_committed collides with not_committed | killed: AU-001 Outcome.equal separates the four outcomes | proofs check |
| T3 | phase_commit collides with admission | killed: AU-001 EventKind.equal and Phase.equal separate their constructors | proofs check |
| T4 | field_subject tag 3 | killed: AU-001 format: a projected AdmissionAdmitted event round trips | proofs check |
| E1 | EventRecord.equal ignores version | killed: AU-001 format: a decoded record and one differing only in version compare unequal | proofs check |
| E2 | EventRecord.equal ignores kind | killed: AU-001 format: a decoded record and one differing only in kind compare unequal | proofs check |
| E5 | EventRecord.equal ignores phase | killed: AU-001 format: a decoded record and one differing only in phase compare unequal | proofs check |
| F1 | FormatError.equal mixed -> True | killed: AU-001 format: FormatError.equal separates all seven reasons | proofs check |
| F2 | DecodeResult.equal Decoded arm -> True | killed: AU-001 format: DecodeResult.equal separates events, reasons, and an event from a rejection | proofs check |
| F3 | DecodeResult.equal mixed -> True | killed: AU-001 format: DecodeResult.equal separates events, reasons, and an event from a rejection | proofs check |

Task 1's equivalent mutants are now killed: E1 ("a decoded record and one
differing only in version compare unequal"), E2 ("... only in kind ..."),
E5 ("... only in phase ...").

## Commands and last lines

Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`.

- `bend AuditEvent.bend --check-only`: `ALL PROOFS CHECK`, then `Use --verdict for mathematical validity.`
- `bend AuditTests.bend`: `Audit: 148 checks passed` (148 PASS lines; 60 before).
- `bend Tests.bend`: last line `ALL LIBRARY TESTS PASSED`; PASS total (both
  `PASS:` and `PASS ` forms) 1576. This tree prints 1428 plus 148 = 1576
  (Task 1 left 1428 plus 60 = 1488; Task 2 adds 88).
- `bend PROOF.bend`: `ALL PROOFS CHECK`, then `Use --verdict for mathematical
  validity.` 21 laws, unchanged. `--verdict` not run (Task 6).
- `openspec validate --all --strict --no-interactive` (1.16.0, after the
  tasks.md edit): `Totals: 44 passed, 0 failed (44 items)`.
- `grep -c "T.admit(" AuditEvent.bend` 1, `grep -c "commit_from_capability("
  AuditEvent.bend` 1, `grep -c 'Diagnostic[.]' AuditEvent.bend` 0.

## Laws

None, as the brief rules. The header says encoding properties are tested,
not proved: the codec works over U32 words, which are not inductive, and a
law would restate the definitions.

## Concerns

1. Layout ruling for `ScopeNotRead{}`. The brief's field list predates Task
   1's fix round, which replaced the six scope fields with `Scope`. Every
   field stays mandatory: under `ScopeNotRead{}` the six scope fields are
   present with length 0, and the invocation field's length (0 or 1) selects
   the scope. A mixture is BadLength. This keeps "every field mandatory" and
   canonicity (an empty source list under `ScopeRead` stays distinct from
   `ScopeNotRead{}`). An alternative would be a scope marker field, which
   would need a twelfth tag.
2. `encode` is stricter than the brief: besides the Nat bound and the source
   bound it also refuses incoherent records (`event_coherent`: version 1,
   kind from outcome, phase from kind, artifact only on an accepted commit,
   scope exactly when the outcome reads it). Without this, `encode` could
   return words that `decode` rejects. The decoder applies the same predicate
   as step 8 (OutOfRange), so a decoded early denial can never carry a
   scope. The predicate reuses `kind_of`, `phase_of` and
   `denial_reads_scope`; it reads tags of the record only and re-runs no
   library check.
3. `OutOfOrder` is wider than the brief's wording ("repeated, or earlier
   than its predecessor"): any allowlisted tag other than the next one is
   OutOfOrder, including a later tag after a skipped mandatory field. A
   missing last field is BadLength (the body ends). Both are in the header
   and pinned by checks.
4. Task 1 tag helpers changed: `denial_tag` is renamed `reason_tag` (the
   brief's name; values 0 to 9 unchanged); `kind_tag` now returns the wire
   kind tags 1 to 4 through named constants (was 0 to 3); `phase_tag` and
   `outcome_tag` go through named constants with unchanged values. Only
   `EventKind.equal` and `denial_equal` read these, and Task 1's checks
   still pass. Task 1's T-series mutant patterns refer to the old text.
5. Count: 88 new checks against an estimate of about 35. The extra checks
   are the per-field encoder bounds, the coherence cases, the order checks
   and the batch-1 kills. No count pin was changed.
6. Not covered: there is no byte-level codec here (HostWire's
   `decode_bytes` is not duplicated); the layout states the little-endian
   convention for a future byte transport only. A decoded event is a
   description, not evidence of a decision (header).
