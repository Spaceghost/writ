### Task 2: Versioned canonical encoding with a field allowlist (task 1.1, second half; AU-001)

Implements the format part of "AU-001 Minimal scoped event records": a versioned canonical binary event format with an allowlist of fields.

Add to `AuditEvent.bend`:
- the constants `event_format_version()` = 1, the kind tags 1 to 4, the field tags (`field_event_id()`, `field_subject()`, `field_phase()`, `field_invocation()`, `field_sources()`, `field_destination()`, `field_stamp()`, `field_code()`, `field_op()`, `field_artifact()`, `field_outcome()`), `max_sources()` (ruling: 16) and `word_limit()` (2^32);
- `field_allowlist() -> FieldTags`, the ordered list of the tags above. This is the single allowlist;
- `field_allowed(tag) -> Bool`, a walk over that list.

Encoding layout:
- Header: version, kind tag, body length.
- Fields are emitted in allowlist order. Each is a tag word, a length word, then value words. Object versions are two words, a stamp is three, and a code is eight.
- The outcome is one word, plus one reason word for `DeniedFor`, using a named `reason_tag(T.Denial)` with ten distinct values.
- The artifact field is length 0 for `None`.

Public entry points:
- `encode(event) -> Maybe<List<U32>>` returns `None` if any Nat field is at or above `word_limit()`, or if there are more than `max_sources()` sources. It never truncates.
- `decode(words) -> Decoded{event} | Malformed{reason: FormatError}`, with `FormatError` closed: `UnknownVersion`, `UnknownKind`, `NotAllowed` (a tag outside the allowlist), `OutOfOrder` (a tag repeated, or one earlier than its predecessor in the allowlist), `BadLength`, `TooLong` and `OutOfRange` (for example a reason word out of range, or a phase that contradicts the kind).

The check order is fixed and documented in the header.

Canonicity: the field order and widths are fixed and every field is mandatory, so an accepted word list is the unique encoding of its event.

Tests (`event_format` section):
- Round trips `decode(encode(e)) == Decoded{e}` for each kind, including every denial reason and both artifact cases. The reverse direction holds for accepted word lists.
- Unknown versions 0, 2 and 0xFFFFFFFF; unknown kinds 0 and 5.
- A field tag naming a payload, a token or text (ruling: tags 12, 13 and 14 are reserved and never allowed) is rejected `NotAllowed`, and no event is built from it.
- A field out of order, a duplicate field, a missing field, a length word that is one short and one long, a truncated body, one trailing word, and more than `max_sources()` sources.
- `encode` on an invocation of 2^32 returns `None`.
- Mutating each tag in `field_allowlist()` (removing it, or adding tag 12) fails at least one check.

Estimate about 35 checks. Laws: none. Encoding properties are tested, not proved: the codec works over `U32` words, which are not inductive, and a law about it would be a restatement. Check box 1.1, citing both sections. Write the per-field sensitivity notes into the module header now; Task 6 copies them into `docs/AUDIT.md`.

Acceptance:
- Suite green at about plus 65 in total, proofs unchanged at 21.
- Every case above is a named check.
- The allowlist mutants are killed.

