# Task 2 review: versioned canonical encoding (776e671..bc1c8e5)

Verdicts:
1. Spec compliance: **APPROVED**
2. Boundary safety and code quality: **APPROVED**

No Critical or Important findings. Three Minor observations, none blocking.

## Findings (by severity)

### Minor

M1. AuditEvent.bend:1420-1425 (`check_trailing`, step 6). A reserved tag (12, 13
or 14) that appears as an extra field AFTER the last allowlisted field is
rejected `BadLength`, not `NotAllowed`. It is never skipped and builds no
event (the probe below confirms), so this is a classification nuance only.
Fix, if a uniform reason is wanted: say in the header (step 6) that anything
after the eleventh field is BadLength whatever its first word is. No code
change needed.

M2. AuditTests.bend:1211 (`expected_tags`). The test-side list `[1..11]` is a
second list of the tag numbers. It is an intentional independent oracle used
only by "field_allowlist() is exactly tags 1 to 11 in order"; every other
check reads `field_allowlist()` or `field_allowed`. No production second list
exists (grep: `FieldTag{` is built only in `field_allowlist`, consumed in
`emit`, `walk`, `walk_all`, `tag_listed`, `tag_count`). Fix: none; keep the
comment that it is an oracle (it already says so).

M3. AuditEvent.bend:1404 (`interpret` fallback, mutant V19). Unreachable while
the allowlist has 11 tags, because `walk_all` returns exactly one field per
allowlisted tag. It stays a live arm only if the allowlist and the record
disagree, and every allowlist mutant (A1-A17) is killed before it matters.
The equivalence argument in the report (line 277) is sound. Fix: none.

Also noted, not a finding: `AuditTests.bend:1545` prints the literal
"Audit: 148 checks passed", matching the repository convention
(`IssuanceTests.bend:1511`). It is the module's own count, not a recorded
count pin; no pin file changed.

## Verdict 1: spec compliance

- Single allowlist: `field_allowlist()` (AuditEvent.bend:725) is the only def
  that builds `FieldTag`. Readers: `emit` via `encode_checked` (:1050), the
  decoder `walk_all` via `check_body_length` (:1437), `read_field` through
  `field_allowed` -> `tag_listed` (:740), `max_words` via `tag_count` (:795).
  Tests read it in `tags_are`, `all_allowed` and the `field_allowed` checks.
  The only other list of tags is the deliberate test oracle (M2).
- Rejections, each with a named check that fails with the branch removed
  (reran eight of the 97 mutants against the stored mutant trees, after
  diffing each against the delivered AuditEvent.bend: each is a one-line
  change):

  | mutant | change | result |
  |---|---|---|
  | W1 | NotAllowed skipped | FAIL "a field tagged as payload (12) is denied NotAllowed and builds no event" |
  | W2 | OutOfOrder skipped | FAIL "two fields out of allowlist order denied OutOfOrder" |
  | W6 | trailing words ignored | FAIL "a word after the last field, counted by the body length, denied BadLength" |
  | A5 | allowlist drops `field_sources()` | FAIL "a projected AdmissionAdmitted event round trips" |
  | V10 | sources TooLong skipped | FAIL "more than max_sources sources denied TooLong (inside the length cap)" |
  | V14 | mixed empty scope accepted | FAIL "an empty invocation with another scope field present denied BadLength" |
  | E1 | `EventRecord.equal` ignores version | FAIL "a decoded record and one differing only in version compare unequal" |
  | V19 | `interpret` field-count arm -> OutOfRange | SURVIVED (148 passed); equivalent, see M3 |

  Also reran E2 (FAIL "... only in kind ...") and E5 (FAIL "... only in
  phase ..."). So E1, E2 and E5 are now killed.
- Unknown versions 0, 2, 0xFFFFFFFF; kinds 0, 5; reserved 12, 13, 14 (three
  positions: after the header, in place of the code, before the event id);
  out-of-order; duplicate; missing middle and last field; bad lengths one
  short and one long; values too large (encoder returns None at 2^32 for every
  Nat field; 17 sources) all have named checks (listed in the report and
  present in AuditTests.bend; all 148 PASS lines).
- Round trips exist for all four kinds, all ten denial reasons, both artifact
  cases, and `ScopeNotRead{}` (projected and synthetic distinct-valued).
- `Tests.bend`: `git diff master...HEAD -- Tests.bend` is only the two Task 1
  lines; `git diff 776e671 bc1c8e5 --stat` touches only AuditEvent.bend,
  AuditTests.bend, tasks.md (box 1.1, in the touch list) and the records
  directory. LAWS.bend and PROOF.bend unchanged since 776e671.
- Ran: `bend AuditTests.bend` -> "Audit: 148 checks passed" (148 PASS, 0
  FAIL). `bend Tests.bend` -> "ALL LIBRARY TESTS PASSED", 1576 PASS lines, 0
  FAIL. `bend PROOF.bend` -> "ALL PROOFS CHECK" (21 laws in LAWS.bend; I did
  not run `--verdict`; this is the checker, not the Lean kernel verdict).
- Every test name quoted in tasks.md box 1.1 occurs exactly once in
  AuditTests.bend.
- No count pin touched (the only count change is the module's own literal).
- Limits: CPU toolchain only, no GPU claim; no byte-level step in this codec
  (HostWire's `decode_bytes` is not duplicated; the header states the
  little-endian convention).

## Verdict 2: boundary safety and code quality

- Lengths. Every length word is checked before it is trusted: the body length
  must equal the words remaining (:1441-1445); `take_values` consumes at most
  the words present and fails `BadLength` if the list ends first, so a length
  of 4294967295 costs only the list length (also covered by the probe); the
  input is capped at `max_words()` (85) before anything else; sources are
  bounded by `max_sources()` before parity; fixed-width fields match their
  exact shape. No decode path acts on an unchecked length.
- Reserved tags are rejected, never skipped. `read_field` calls
  `field_allowed` first and a refusal returns `StepFail{NotAllowed}`; there is
  no skip or default arm. A tag in the allowlist but not the next one is
  `OutOfOrder`. Trailing or duplicated fields fail at step 6 or step 5. A
  length that overlaps the next field shifts every later tag position, so the
  next tag word fails the allowlist/order check, or a width check.
- Smuggling. The only free-form words are event id, subject, source/destination
  versions, stamp, code and artifact digest, all typed numbers or fixed-width
  digests. There is no field that can hold a payload, token or text, and the
  decoder cannot create one, because it can only build `EventRecord` from the
  eleven allowlisted fields and then requires `event_coherent`.
- Independent probe (scratch, outside the tree: `Probe.bend` under the session
  scratchpad `policy-aware-audit-review-t2/probe`, using AuditTests' synthetic
  records). For four base encodings (accepted commit, rejected commit, early
  Stale denial, late Origin denial) it applied, at every word position, a
  replacement, an insertion (with and without fixing the body length) with
  each of 18 values (0-5, 8-17, 33, 0xFFFFFFFF, including 12, 13, 14), and a
  deletion (length fixed). Result: of those words lists, every one `decode`
  accepted (549 for the commit case) re-encoded to exactly its input, with
  zero exceptions. So no malformed body produced a record the encoder would
  not have produced from the allowlist. This is a bounded probe, not a proof.
- `rejected` cannot pass vacuously: `Decoded` returns False; `Malformed`
  compares `reason_code` (a test-side function with seven distinct values,
  not `FormatError.equal`). `format_separates` checks that `FormatError.equal`
  agrees with the code comparison across all 49 pairs, so a collision in
  `reason_code` would itself fail. Mutants W1, W2, W6, V10, V14 fail
  specific `rejected` checks, which shows it discriminates.
- Partial matches: none found. `walk` covers (NoTags, FieldTag) x (StepOk,
  StepFail); `interpret`, `parse_*`, `check_*` have catch-all arms that fail
  closed; no arm accepts by default.
- Naming and comments: helpers are named and small; each states edge
  direction, check order and failure behavior. The header states the codec
  is "a BOUNDARY, NOT POLICY", that a decoded event is a description and not
  evidence of a decision, and lists public entry points against helpers. The
  per-field sensitivity notes are present for Task 6.
- Match with HostWire's discipline: versioned header, fixed check order,
  closed error set, one U32 word per field, canonical re-encode property,
  bounded length cap first.
