# Bounded mount-frame description

A synthetic peer sends 48 bytes containing version 1, mount opcode 1, a
36-byte body length, eight token words and a requested-rights word. A frame
ending inside the token is malformed and yields no partial description. The
[proposed POSIX contract](specs/posix-adapter/spec.md) requires this bounded
parsing, but no native device or authenticated capability session exists.

[`PosixMountFrame.bend`](../../../PosixMountFrame.bend) implements only this
one proposed untrusted mount-description shape. All numbers are little-endian
U32 words; the three-word header is version, opcode and body length in bytes.
The body is eight token words in order followed by one requested-rights word.
The maximum is 12 words or 48 bytes. An over-limit input returns `TooLong`
after inspecting at most cap+1 list constructors. For byte inputs, the cap is
followed by an exact 48-byte shape check before byte-range validation; only
then are version, opcode, declared length and exact body decoded. Word inputs
check the cap and header before those same frame checks. Short, extra,
unsupported and out-of-byte-range encodings return a `Malformed` value with no
token-bearing partial result.

This description carries no subject, handle, label, grant or authority record.
The token and the requested-rights word are untrusted data: even an all-zero or
unknown rights word can be decoded as a description and must be rejected by the
existing authority path if it is not valid or granted. A successful decode does
not authenticate the caller, validate a capability, open a session, allocate a
native descriptor, deliver input, or authorize an effect. Public constructors
and exported implementation helpers are forgeable. Do not log decoded tokens.

This is not the complete POSIX ABI. All opcodes other than the synthetic mount
description, all additional fields, 64-bit labels, descriptor operations,
responses, streaming and native buffering remain unsupported and unimplemented.
An appended label-like value is refused, not truncated or accepted as an
authority fact. The related [`HostWire`](../../../HostWire.bend) describes a
different portable-host table-reference schema; their messages are not
interchangeable. Encoding helpers are shared, but no interoperability or
conversion of the wire token into a trusted frontend caller is provided.

The [traceability record](../../traceability/posix-adapter.md) names the exact
model checks and remaining gaps. Task 1.1 and every native host task remain
unchecked. A future real implementation still needs an agreed complete ABI,
trusted host identity, authenticated current registry lookup, resource
admission before native buffering, confinement, revocation, exact sealed-output
commit and all applicable host acceptance evidence.
