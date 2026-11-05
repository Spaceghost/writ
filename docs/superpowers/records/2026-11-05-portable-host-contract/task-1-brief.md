### Task 1: Versioned references and bounded canonical encoding (tasks.md 1.1)

Requirements: PH-011 "The transport has a bounded canonical schema" (both scenarios: "A peer sends an unknown authority variant", "A peer supplies a complete trusted context"); PH-003 "Native handles remain host-local authority" (the wire part of "A guessed numeric handle": a reference is a name for a monitor table entry, never authority); the wire part of PH-004 "References bind incarnation and generation" (every reference carries both).

Create `HostWire.bend`, importing `Base` only. The header states that decoding produces descriptions, not authority. Public entry points: `encode`, `decode`, `decode_bytes`, `encode_bytes`; the rest are helpers.

- `Ref{host: U32, incarnation: U32, slot: U32, generation: U32}` names one entry of the receiving monitor's identity table (Task 2). The header says it is not a credential and that serialization transfers no native authority.
- `Message`, plan ruling: four tags, with the fixed body widths below. Every field is one U32 word.

| Tag | Message | Body words (after the 3-word header) |
| --- | --- | --- |
| 1 | `Use{ref, operation, rights, claimed_subject}` | 7: ref (4), operation, rights, claimed_subject |
| 2 | `Delegate{ref, rights, lifetime, target_session}` | 7: ref (4), rights, lifetime, target_session |
| 3 | `Complete{ref, sequence, status}` | 6: ref (4), sequence, status |
| 4 | `Release{ref}` | 4: ref |

- Header: word 0 `wire_version()` = 1, word 1 tag, word 2 body length in words. `max_words()` = 10. Byte transports carry each word little-endian. `decode_bytes` takes a `List<U32>` of byte values and is the only byte-to-word step, so a native harness passes raw bytes and interprets nothing. Plan ruling: this is the same byte order and word width as `Channel.md`, so a later migration of the channel changes framing only.
- Bounds, each a named helper: `host`, `incarnation`, `slot`, `generation`, `sequence`, and `target_session` are nonzero. `operation` is one of `operation_read()` 1, `operation_write()` 2, `operation_execute()` 3. `rights` is nonzero and within `rights_mask()` = 7, the read/write/execute bits of the Frontend fixtures. `lifetime` is in 1..`max_lifetime()` (plan ruling: 65535 monitor ticks; it is a relative bound that Task 2 caps by the parent's expiry). `status` is `status_ok()` 1 or `status_failed()` 2. `claimed_subject` may be any value; it is kept so it can be logged as untrusted.
- `WireError` is a closed set: `UnknownVersion`, `UnknownTag`, `BadLength` (empty or short input, header length not equal to the tag's width, actual body count not equal to the header length, byte count not a multiple of 4), `TooLong` (more than `max_words()` words, or more than 4 × `max_words()` bytes), and `OutOfRange` (a field outside its bound, or a byte value above 255). `decode` returns `Decoded{message}` or `Malformed{reason}`. The check order is fixed and documented: length cap, version, tag, header length, body count, field bounds.
- Canonicity: the widths are fixed and there are no optional fields, so every accepted word list is the unique encoding of its message. Tests show `decode(encode(m)) == Decoded{m}` and `encode` of a decoded message equals its input.

`HostWireTests.bend` (registered in `Tests.bend` as `HostWire`) must cover these cases.
- Accepted: each of the four tags, with round trips in both directions; a byte-level round trip.
- Unknown versions: 0, 2, and 0xFFFFFFFF.
- Unknown tags: 0, 5, and 0xFFFFFFFF. Add a tag-5 record shaped like a serialized Context/Ledger/caller (PH-011's second scenario): it is rejected `UnknownTag`, and no record is built from it.
- Malformed lengths: empty input; header only; header length one short and one long for each tag; header correct but body truncated; one trailing word; 11 words; byte input of 3, 5, and 41 bytes.
- Out-of-range values: zero host, incarnation, slot, generation, sequence, and target_session (one check each); operation 0 and 4; rights 0 and 8; lifetime 0 and `max_lifetime()` + 1; status 0 and 3; a byte value of 256.
- Guessed handle: a `Use` naming another session's slot decodes as a description. The check asserts the decoder's output type is `Ref`, with no rights or subject, so authority can come only from Task 2's resolution.

Estimate: about 40 checks; about 200 lines of module and 250 of tests. Create `openspec/traceability/portable-host-contract.md` with a header naming the change, the implementation and test modules, and the rule "model rows only; native evidence is section 2". Add PH-011 and PH-003/PH-004 wire rows with exact check names. Check box 1.1, citing the module and test file.

Acceptance: every listed case is a named check; the suite is green on both backends with PASS count = 782 + this task's checks; `bend PROOF.bend` passes unchanged; OpenSpec strict passes.

