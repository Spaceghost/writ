# Task 1 report: versioned references and bounded canonical encoding (tasks.md 1.1)

Status: DONE. Implementer, lane `lane/portable-host-contract`.

## Delivered

- `HostWire.bend` (new, imports `Base` only). Header states the module is a
  boundary, not policy: decoding yields descriptions, never authority; a `Ref`
  is not a credential and serializing one transfers no native authority.
- `HostWireTests.bend` (new, 59 checks, header marks all fixtures SYNTHETIC
  MONITOR STATE). Summary line `HostWire: 59 checks passed`.
- `Tests.bend`: one import (`import ./HostWireTests.bend as HostWire`, after the
  HostBinding import) and one call (`HostWire.main()`, after
  `HostBinding.main()`). Nothing else.
- `openspec/traceability/portable-host-contract.md` (new): header naming the
  change, the implementation and test modules, and the rule "model rows only;
  native evidence is section 2"; PH-011, PH-003, and PH-004 wire rows with exact
  check names.
- `openspec/changes/add-portable-host-contract/tasks.md`: box 1.1 checked,
  citing the module, test file, and traceability; header line updated.
- No count pin touched (README, INSTALL, nix, CI workflow, VERIFICATION.md).

## Types and helpers

Public types:
- `Ref{host, incarnation, slot, generation}`: names one entry of the receiving
  monitor's identity table; no rights, holder, subject, or expiry.
- `ClaimedSubject{untrusted}`: the peer's claimed subject, typed and named as
  untrusted, kept for logging only (plan's authority rule).
- `Message`: `Use{ref, operation, rights, claimed_subject}`,
  `Delegate{ref, rights, lifetime, target_session}`,
  `Complete{ref, sequence, status}`, `Release{ref}`; tags 1 to 4, body widths
  7, 7, 6, 4.
- `WireError` (closed): `UnknownVersion`, `UnknownTag`, `BadLength`, `TooLong`,
  `OutOfRange`.
- `DecodeResult`: `Decoded{message}` or `Malformed{reason}`.

Public entry points: `encode`, `decode`, `encode_bytes`, `decode_bytes`.
Public constants: `wire_version()` 1, `tag_use/delegate/complete/release()`,
`width_*()`, `max_words()` 10, `max_bytes()` (4 x `max_words()`),
`bytes_per_word()`, `byte_mask()` 255, `byte1/2/3_shift()`,
`operation_read/write/execute()` 1/2/3, `rights_mask()` 7, `max_lifetime()`
65535, `status_ok/failed()` 1/2.
Public bound predicates: `host_in_bounds`, `incarnation_in_bounds`,
`slot_in_bounds`, `generation_in_bounds`, `sequence_in_bounds`,
`target_session_in_bounds`, `operation_in_bounds`, `rights_in_bounds`,
`lifetime_in_bounds`, `status_in_bounds`, `byte_in_bounds`, `ref_in_bounds`,
`message_in_bounds`.
Public accessors/equalities: `Message.ref`, `DecodeResult.message`,
`DecodeResult.reason`, `WireError.equal`, `Ref.equal`, `Message.equal`,
`DecodeResult.equal`.
Implementation helpers (marked in the source): `TagKind`, `Packed`, `nonzero`,
`frame`, `ref_words`, `word_bytes`, `words_to_bytes`, `choose_kind`,
`tag_kind`, `width_matches`, `admit_checked`, `admit`, `parse_body`,
`check_header_length`, `decode_length`, `check_tag`, `decode_tag`,
`check_version`, `decode_version`, `check_cap`, `pack_word`, `prepend_word`,
`pack`, `bytes_in_bounds`, `decode_in_range`, `decode_packed`,
`check_byte_cap`.

Check order (documented in the header): length cap, version, tag, header
length, body count, field bounds. `decode_bytes` first does byte cap
(TooLong), alignment to whole words (BadLength), byte range (OutOfRange), then
`decode`. No arrays, no `@unsafe`, no holes; every recursion is structural on
a list.

## Checks (59)

Accepted and canonical (12): `PH-011 Use decode of encode is the same message`;
`PH-011 Use words decode and re-encode to the same words`; the same pair for
Delegate, Complete, Release; `PH-011 a byte-level round trip of a 40-byte
Delegate is the same message`; `PH-011 byte transport carries each word
little-endian`; `PH-011 operation execute with rights equal to the mask is in
bounds`; `PH-011 lifetime equal to max_lifetime is in bounds`.

Unknown versions (3): `PH-011 version 0 denied UnknownVersion`; `PH-011 version
2 denied UnknownVersion`; `PH-011 version 0xFFFFFFFF denied UnknownVersion`.

Unknown tags (5): `PH-011 tag 0 denied UnknownTag`; `PH-011 tag 5 denied
UnknownTag`; `PH-011 tag 0xFFFFFFFF denied UnknownTag`; `PH-011 a tag-5 record
shaped like a Context, Ledger, and caller denied UnknownTag`; `PH-011 no record
is built from a serialized trusted context`.

Malformed lengths (16): `PH-011 empty input denied BadLength`; `PH-011 header
only denied BadLength`; `PH-011 <Tag> header length one short denied
BadLength` and `... one long denied BadLength` for Use, Delegate, Complete,
Release (8); `PH-011 correct header with a truncated body denied BadLength`;
`PH-011 one trailing word denied BadLength`; `PH-011 11 words denied TooLong`;
`PH-011 3 bytes denied BadLength`; `PH-011 5 bytes denied BadLength`; `PH-011
41 bytes denied TooLong`.

Out of range (13 here + 2 under PH-004): `PH-011 zero host denied OutOfRange`;
`PH-011 zero slot denied OutOfRange`; `PH-011 zero sequence denied
OutOfRange`; `PH-011 zero target_session denied OutOfRange`; `PH-011 operation
0 denied OutOfRange`; `PH-011 operation 4 denied OutOfRange`; `PH-011 rights 0
denied OutOfRange`; `PH-011 rights 8 denied OutOfRange`; `PH-011 lifetime 0
denied OutOfRange`; `PH-011 lifetime max_lifetime plus 1 denied OutOfRange`;
`PH-011 status 0 denied OutOfRange`; `PH-011 status 3 denied OutOfRange`;
`PH-011 a byte value of 256 denied OutOfRange` (the 256 replaces the version's
low byte, so without the range check it would pack to version 256 and report
UnknownVersion; the check discriminates).

Check order (4, added beyond the brief to pin the documented order): `PH-011
order: the length cap precedes the version`; `PH-011 order: the version
precedes the tag`; `PH-011 order: the tag precedes the header length`; `PH-011
order: the body count precedes field bounds`.

PH-003 guessed handle (2): `PH-003 a Use naming another session's slot decodes
to a Ref of four identity words only`; `PH-003 the guessed Use's subject stays
a ClaimedSubject, untrusted`.

PH-004 wire part (4): `PH-004 zero incarnation denied OutOfRange`; `PH-004 zero
generation denied OutOfRange`; `PH-004 references differing only in
incarnation encode and decode differently`; `PH-004 references differing only
in generation encode and decode differently`.

## Verification

Counts: before 782 PASS (verification/tests-js.txt); after 782 + 59 = 841.
All 782 pre-existing PASS lines are still present (sorted comparison against
`verification/tests-js.txt`: 0 missing; every added line is a PH- check).

- `bend Tests.bend`: 841 PASS; last lines
  `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers`
  `ALL LIBRARY TESTS PASSED`.
- Native: `bend Tests.bend -o ../writ-build/portable-host-contract/tests-native`
  then `../writ-build/portable-host-contract/tests-native +RTS --threads 4 --gpu off`:
  exit 0, 841 PASS, same last two lines, PASS lines identical to the JS run.
  This is CPU execution, not a GPU test.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
  LAWS.bend and PROOF.bend unchanged.
- `bend PROOF.bend --verdict`: not available: `Error: BendTT infrastructure: the
  kernel did not build (lean: Executable not found in $PATH: "lean"); --verdict
  needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or $BENDTT set to
  a built kernel`.
- `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`:
  `Totals: 44 passed, 0 failed (44 items)`.

## Rulings applied and concerns

- `claimed_subject` is wrapped in `ClaimedSubject{untrusted: U32}` rather than
  a bare U32, to satisfy the plan's "typed and named as untrusted" rule. It is
  still one wire word.
- The brief's "zero incarnation" and "zero generation" checks are named PH-004
  (they are its wire part) rather than PH-011; the traceability lists them
  under PH-004.
- Byte-step order (cap, alignment, byte range) is my choice within the brief's
  fixed order; it is documented in the header and covered by the checks.
- `encode` does not check bounds; an out-of-bounds message encodes to words
  that `decode` rejects OutOfRange. The range checks build their inputs this
  way.
- Header length and body count both report BadLength, so their relative order
  is source-reviewed, not observable (stated in the traceability).
- The module is 541 lines (estimate 200), mostly comments and one-def-per-
  constant naming; the tests are 363 lines.
- `HostWire.bend` and `HostWireTests.bend` are not yet in
  `verification/source-sha256.txt`; that is Task 6 per the plan.

## Fix round 1

Source: task-1-review.md (verdict 1 APPROVED, verdict 2 NEEDS_FIXES). All
eight findings were applied.

1. PH-004 distinctness: new fixtures `next_incarnation_ref()` (incarnation 6)
   and `next_generation_ref()` (generation 3), and a helper
   `distinct_from_own(ref)` that requires `decodes_to(release_with(ref),
   Release{ref})`, `ref` different from `own_ref()`, and different encoded
   words. A Malformed decode now fails both PH-004 "encode and decode
   differently" checks. The check names are unchanged.
2. Guessed handle: `owner_subject()` is now 1234 and `guessed_words()` ends in
   1234, so rights (7), the header length (7), and the subject are distinct.
   The PH-003 Ref check now also asserts the whole decoded message
   (`guessed_msg()` = `Use{guessed_ref(), operation_read, rights_mask,
   ClaimedSubject{1234}}`). The name is unchanged.
3. New checks: `PH-011 version word only denied BadLength` (`[1]`) and
   `PH-011 version and tag only denied BadLength` (`[1, 1]`).
4. New fixture `read_right()` (1, the read bit) replaces `W.operation_read()`
   in every rights position: `delegate_msg` and five `delegate_with` sites.
   `all_rights()` is removed in favour of `W.rights_mask()`.
5. The `pack_word` comment now says out-of-range bytes may overlap and that
   `decode_in_range` discards the packed words unless every byte is in range.
6. New constant `header_words()` (3n); `max_words()` is now
   `header_words() + width_use()` (still 10).
7. Every decode/encode helper now has its own "Implementation helper" comment.
8. New checks: `PH-011 a byte-level round trip of a Use is the same message`
   and `PH-011 a byte-level round trip of a Complete is the same message`.

The traceability rows are updated with the four new check names and notes
for findings 1 and 2. The summary line is now `HostWire: 63 checks passed`.

Verification after the fixes:
- `bend Tests.bend`: exit 0, 845 PASS (782 + 63). Last lines are
  `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers`
  and `ALL LIBRARY TESTS PASSED`. 0 of the 782 pre-existing PASS lines are
  missing.
- Native CPU run (`--threads 4 --gpu off`): exit 0, 845 PASS, PASS lines
  identical to the JS run. This is not a GPU test.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
  `--verdict` is still unavailable because Lean is absent.
- OpenSpec 1.16.0 strict: `Totals: 44 passed, 0 failed (44 items)`.
