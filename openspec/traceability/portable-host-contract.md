# Portable host contract traceability

Proposed change: [add-portable-host-contract](../changes/add-portable-host-contract/specs/portable-host-contract/spec.md).
This is a proposed change; nothing here marks a host adapter, a native
binding, or a host acceptance scenario as implemented.

Rule: model rows only; native evidence is section 2. Every row below names
evidence from the shared Bend layer (tasks 1.1 to 1.4). Native confinement,
quiescence, alias elimination, and per-target replay remain host obligations
until section 2 of [tasks.md](../changes/add-portable-host-contract/tasks.md)
supplies evidence for a qualified profile.

Implementation and test modules:

| Task | Implementation | Executable cases |
| --- | --- | --- |
| 1.1 | [HostWire.bend](../../HostWire.bend) | [HostWireTests.bend](../../HostWireTests.bend), run by `Tests.bend` as `HostWire` |

Test names below are the exact `Test.check` names. "Reviewed-only" means the
named part has no executable check in this model and rests on source review or
on evidence a later task or a qualified host must supply.

## Wire format (task 1.1)

Fixtures are the named zero-argument functions in `HostWireTests.bend`, all
synthetic monitor state: host 3, incarnation 5, own slot 11, guessed slot 12,
generation 2, target session 4, sequence 9, claimed subject 77 (1234 in the guessed-handle fixture), read right 1. Decode checks,
in order: length cap (`TooLong`), version (`UnknownVersion`), tag
(`UnknownTag`), header length and body count (`BadLength`), field bounds
(`OutOfRange`); `decode_bytes` first applies the byte cap, word alignment, and
byte range.

| Requirement | Implementation | Named executable evidence | Coverage boundary |
| --- | --- | --- | --- |
| PH-011 (accepted, canonical) | `encode`, `decode`, `encode_bytes`, `decode_bytes`, `parse_body`, `admit`, `message_in_bounds`, `pack`, `words_to_bytes` | `PH-011 Use decode of encode is the same message`; `PH-011 Use words decode and re-encode to the same words`; `PH-011 Delegate decode of encode is the same message`; `PH-011 Delegate words decode and re-encode to the same words`; `PH-011 Complete decode of encode is the same message`; `PH-011 Complete words decode and re-encode to the same words`; `PH-011 Release decode of encode is the same message`; `PH-011 Release words decode and re-encode to the same words`; `PH-011 a byte-level round trip of a 40-byte Delegate is the same message`; `PH-011 a byte-level round trip of a Use is the same message`; `PH-011 a byte-level round trip of a Complete is the same message`; `PH-011 byte transport carries each word little-endian`; `PH-011 operation execute with rights equal to the mask is in bounds`; `PH-011 lifetime equal to max_lifetime is in bounds` | Finite cases, not a proof over all messages. Canonicity (one encoding per message) follows from fixed widths and no optional fields; it is source-reviewed and shown on the four tags, not stated as a law. |
| PH-011 "A peer sends an unknown authority variant" | `check_cap`, `check_version`, `tag_kind`, `check_tag`, closed `WireError`, `DecodeResult` | `PH-011 version 0 denied UnknownVersion`; `PH-011 version 2 denied UnknownVersion`; `PH-011 version 0xFFFFFFFF denied UnknownVersion`; `PH-011 tag 0 denied UnknownTag`; `PH-011 tag 5 denied UnknownTag`; `PH-011 tag 0xFFFFFFFF denied UnknownTag` | A rejected input returns `Malformed{reason}` and carries no message, so no record exists to act on. That a host adapter performs no protected operation on a `Malformed` result is a section 2 obligation. |
| PH-011 "A peer supplies a complete trusted context" | `Message` has no Context, Ledger, Binding, Registry, plan, grant, or caller field; `ClaimedSubject` | `PH-011 a tag-5 record shaped like a Context, Ledger, and caller denied UnknownTag`; `PH-011 no record is built from a serialized trusted context` | The wire part only: no schema variant can carry authoritative context. That the monitor builds its context only from its own authenticated state is Task 2 (HostIdentity) and section 2. |
| PH-011 malformed lengths | `check_cap`, `decode_tag`, `decode_length`, `check_header_length`, `width_matches`, `parse_body`, `check_byte_cap`, `pack` | `PH-011 empty input denied BadLength`; `PH-011 version word only denied BadLength`; `PH-011 version and tag only denied BadLength`; `PH-011 header only denied BadLength`; `PH-011 Use header length one short denied BadLength`; `PH-011 Use header length one long denied BadLength`; `PH-011 Delegate header length one short denied BadLength`; `PH-011 Delegate header length one long denied BadLength`; `PH-011 Complete header length one short denied BadLength`; `PH-011 Complete header length one long denied BadLength`; `PH-011 Release header length one short denied BadLength`; `PH-011 Release header length one long denied BadLength`; `PH-011 correct header with a truncated body denied BadLength`; `PH-011 one trailing word denied BadLength`; `PH-011 11 words denied TooLong`; `PH-011 3 bytes denied BadLength`; `PH-011 5 bytes denied BadLength`; `PH-011 41 bytes denied TooLong` | Framing of a byte stream into messages (how a native transport finds message boundaries) is outside this module; `decode_bytes` takes one message's bytes. |
| PH-011 out-of-range values | named bound predicates (`host_in_bounds` through `status_in_bounds`, `byte_in_bounds`), `message_in_bounds`, `admit` | `PH-011 zero host denied OutOfRange`; `PH-011 zero slot denied OutOfRange`; `PH-011 zero sequence denied OutOfRange`; `PH-011 zero target_session denied OutOfRange`; `PH-011 operation 0 denied OutOfRange`; `PH-011 operation 4 denied OutOfRange`; `PH-011 rights 0 denied OutOfRange`; `PH-011 rights 8 denied OutOfRange`; `PH-011 lifetime 0 denied OutOfRange`; `PH-011 lifetime max_lifetime plus 1 denied OutOfRange`; `PH-011 status 0 denied OutOfRange`; `PH-011 status 3 denied OutOfRange`; `PH-011 a byte value of 256 denied OutOfRange` | Bounds are structural. In-bounds rights are requested rights, not granted; capping them by the table entry, and capping `lifetime` by the parent's expiry, is Task 2. |
| PH-011 check order | `decode` (documented order in the module header) | `PH-011 order: the length cap precedes the version`; `PH-011 order: the version precedes the tag`; `PH-011 order: the tag precedes the header length`; `PH-011 order: the body count precedes field bounds` | Header length and body count share `BadLength`, so their relative order is source-reviewed, not observable. |
| PH-003 "A guessed numeric handle" (wire part) | `Ref` (four identity words, no rights, holder, subject, or expiry, enforced by the type definition), `ClaimedSubject`, `Message.ref` | `PH-003 a Use naming another session's slot decodes to a Ref of four identity words only` (asserts the whole decoded Use, so a swapped field fails); `PH-003 the guessed Use's subject stays a ClaimedSubject, untrusted` | The wire part only: a guessed number decodes to a description. That the description grants no access is the monitor's resolution (Task 2, HostIdentity). That native handles are never serialized is source-reviewed: no `Message` field is a native selector, descriptor, handle, or driver token. "A reference crosses hosts" is Task 2. |
| PH-004 (wire part) | `Ref.incarnation`, `Ref.generation`, `incarnation_in_bounds`, `generation_in_bounds` | `PH-004 zero incarnation denied OutOfRange`; `PH-004 zero generation denied OutOfRange`; `PH-004 references differing only in incarnation encode and decode differently`; `PH-004 references differing only in generation encode and decode differently` (each requires both decodes to succeed) | The wire part only: every reference carries both fields. "Handle reuse after restart" and "Conflicting live mappings" are resolution properties of Task 2. |
