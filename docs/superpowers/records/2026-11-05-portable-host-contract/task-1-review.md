# Task 1 review: HostWire version-1 wire format (tasks.md 1.1)

Reviewer: task reviewer. Reviewed range `e569b58..c277f80` (commit c277f80) on
`lane/portable-host-contract`. Inputs read: task-1-brief.md, task-1-report.md,
the review diff, the plan's Global Constraints, AGENTS.md, and the PH-003,
PH-004, and PH-011 deltas in
`openspec/changes/add-portable-host-contract/specs/portable-host-contract/spec.md`.

Controller rulings applied and not flagged: the `ClaimedSubject{untrusted}`
wrapper, the four extra check-order tests, the byte-step order (byte cap, word
alignment, byte range), `BadLength` shared by header length and body count as a
source-reviewed row, and the 541-line module.

## Verdict 1, spec compliance: APPROVED

- Wire format matches the brief: header words version, tag, body length
  (`frame`, HostWire.bend:323); `wire_version()` 1; tags 1 to 4 with widths 7,
  7, 6, 4 (HostWire.bend:120-143); `max_words()` 10; `max_bytes()` = 4 x 10;
  bytes little-endian (`word_bytes` :347, `pack_word` :487). The test literals
  `use_words` .. `release_words` pin the layout independently of `encode`, and
  `wide_release_bytes` pins the byte order with 0x04030201 -> 1, 2, 3, 4.
- Every case the brief lists has a named check, and I read each one for
  whether it can fail. Versions 0, 2, 0xFFFFFFFF; tags 0, 5, 0xFFFFFFFF; the
  tag-5 Context/Ledger/caller record (rejected `UnknownTag`, and
  `builds_nothing`); empty; header only; header length one short and one long
  for all four tags (body left at the correct width, so each one checks the
  header-length step and not the body count); a truncated body; one trailing
  word; 11 words; 3, 5, and 41 bytes; zero host, incarnation, slot,
  generation, sequence, target_session; operation 0 and 4; rights 0 and 8;
  lifetime 0 and 65536; status 0 and 3; byte 256 (it discriminates: without
  the range check it packs to version 256 and reports `UnknownVersion`). Each
  out-of-range fixture changes exactly one field. All of these can fail.
- Descriptions only. The decoder builds only `Decoded{Use|Delegate|Complete|
  Release}` over `Ref` and `ClaimedSubject`, or `Malformed{WireError}`
  (`parse_body` :407-418, `admit_checked` :394). No Context, Ledger, Binding,
  Registry, plan, grant, or caller type is reachable. The module imports only
  `Base`, and only `HostWireTests.bend` and `Tests.bend` reference it. The
  header statement (:7-16) is accurate.
- `Tests.bend`: one import and one call, both after HostBinding. Nothing else
  changed.
- The traceability rows name exactly the 59 `Test.check` strings. I compared
  them by eye against the test file and the run output, and the coverage
  boundaries are stated honestly. Box 1.1 cites the module, the test file, and
  the traceability file. The tasks.md header line change is permitted by the
  plan.
- No count pin was touched. The diff contains no changes to README, INSTALL,
  nix, workflows, VERIFICATION.md, verification/, LAWS.bend, or PROOF.bend.
- One spec-adjacent weakness (finding 1): the "decode differently" half of the
  two PH-004 distinctness checks passes even when decoding fails. These are
  not brief-listed rejection cases, so I put the finding under verdict 2.

## Verdict 2, code quality and safety: NEEDS_FIXES

Safety is sound. There are no arrays or indexes. Every list match is
structural with a catch-all. `parse_body` requires an exact `Nil` tail. The
header length word is only compared (`width_matches`) and never drives
parsing, so no decode path trusts a length it read. A malformed input cannot
produce a `Decoded` value, because every rejecting branch returns `Malformed`
and nothing partial is returned. There is no `@unsafe`, no hole, and no
mutual recursion, and recursion is structural on lists. The fixes below are
test strength and comment accuracy.

### Findings, by severity

1. Important, HostWireTests.bend:347 and :348. The decode half of "PH-004
   references differing only in incarnation/generation encode and decode
   differently" is vacuous when decoding fails. It asserts
   `Bool.not(Ref.equal(decoded_ref(...), own_ref()))`, and `decoded_ref`
   (:204-209) returns `Ref{0,0,0,0}` on `Malformed`, which also differs from
   `own_ref()`. A decoder that rejected incarnation 6 or generation 3 would
   still pass. Fix: add named fixtures `next_incarnation_ref()` (incarnation
   6) and `next_generation_ref()` (generation 3), and assert
   `decodes_to(release_with(r), W.Release{r}) && Bool.not(W.Ref.equal(r,
   own_ref())) && Bool.not(words_equal(W.encode(W.Release{r}),
   release_words()))`.

2. Minor, HostWireTests.bend:56-57, :65-66, :237, :339. In `guessed_words`
   the rights word and the claimed subject are both 7, `owner_subject()` = 7 =
   `all_rights()`, and the header length is also 7. "PH-003 the guessed Use's
   subject stays a ClaimedSubject, untrusted" therefore would not detect a
   decoder that swapped rights and claimed_subject. The Use round trips catch
   a swap, but this check does not. The PH-003 Ref check also does not assert
   the full decoded message. Fix: give `owner_subject()` a distinct value
   (for example 1234). Then also assert `decodes_to(guessed(),
   W.Use{guessed_ref(), W.operation_read(), W.rights_mask(),
   W.ClaimedSubject{owner_subject()}})`. "Four identity words only" is
   enforced by the `Ref` type definition, not at runtime, and the traceability
   row's implementation column already says so.

3. Minor, HostWire.bend:430 and :451. The short-input branches
   (`decode_length` on `Nil`, `decode_tag` on `Nil`) are not exercised. The
   brief defines `BadLength` as "empty or short input", but the tests cover
   only `[]` (version step) and `[1, 4, 4]` (body step). Fix: add `PH-011
   version word only denied BadLength` (`[1]`) and `PH-011 version and tag
   only denied BadLength` (`[1, 1]`). Update the summary count and the
   traceability row. This is a pre-Task 6 count change, which the plan allows.

4. Minor, HostWireTests.bend:87, :195 (callers), :270, :314, :319, :320. These
   lines use `W.operation_read()` (an operation code) as a Delegate rights
   value. It works because both are 1, but it conflates an operation with a
   rights bit, which AGENTS.md's named-policy-bit rule exists to prevent.
   Also, `all_rights()` (:65) duplicates `W.rights_mask()`. Fix: add a fixture
   `read_right() -> U32: 1` with a comment that it is the read bit of the
   Frontend fixtures, or a module constant `rights_read()`, use it in place of
   `operation_read()` at those sites, and replace `all_rights()` with
   `W.rights_mask()`.

5. Minor, HostWire.bend:485-486. The `pack_word` comment says "Callers check
   every byte against `byte_mask()` first, so no bits overlap". In fact
   `check_byte_cap` (:535) packs and range-checks the same input side by side,
   and `decode_packed`/`decode_in_range` throw away the packed words when any
   byte is out of range. The behaviour is correct, but the comment
   misdescribes it. Fix: reword it to "Out-of-range bytes may overlap here;
   `decode_in_range` discards the packed words unless every byte is within
   `byte_mask()`."

6. Nit, HostWire.bend:145-147. `max_words()` is the literal 10, and nothing
   names the 3-word header width. Fix: add `header_words() -> Nat: 3n` and
   define `max_words()` as `Nat.add(header_words(), 7n)`, or keep the literal
   and point the comment at `width_use()`/`width_delegate()`.

7. Nit, HostWire.bend:351, :364, :394, :421-541. Several helpers
   (`words_to_bytes`, `choose_kind`, `admit_checked`, `check_*`, `decode_*`,
   `prepend_word`, `bytes_in_bounds`) do not carry an "Implementation helper"
   marker. The header rule (:56-59, "every other def is an implementation
   helper") covers them. Optional: mark them individually, as `frame` and
   `ref_words` are.

8. Nit, HostWireTests.bend:267-268. Byte-level round trips exist only for
   Delegate and Release. Word-level round trips cover all four types in both
   directions, which meets the requirement. Optional: add byte round trips for
   Use and Complete.

No dead code was found that matters. `width_matches`' `TagUnknown` branch
(:391) is unreachable but needed for totality, and its comment says so.

## What I verified and ran

- Read HostWire.bend (541 lines) and HostWireTests.bend (363 lines) in full,
  plus the Tests.bend, tasks.md, and traceability diffs.
- `bend Tests.bend` (Bend 2.0.39, JS backend): exit 0. 841 `^PASS` lines, 0
  FAIL, 59 PH- checks, and the summary `HostWire: 59 checks passed`. Last
  lines: `Property: 324 checks passed; 320 graph cases, each checked against
  CPU and Bend parallel producers` / `ALL LIBRARY TESTS PASSED`. All 782 PASS
  lines in `verification/tests-js.txt` are still present (0 missing), and
  there are no duplicate PASS lines. 841 = 782 + 59.
- `bend PROOF.bend`: exit 0, `ALL PROOFS CHECK` / `Use --verdict for
  mathematical validity.` I did not run `--verdict`; the report records Lean
  as absent. I did not rerun the native backend; the report records 841 on
  CPU, which is not a GPU test.
- `openspec validate --all --strict --no-interactive` (1.16.0):
  `Totals: 44 passed, 0 failed (44 items)`.
