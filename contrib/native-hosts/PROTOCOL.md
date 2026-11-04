# Native host protocol, version 1

An OS adapter freezes one public canary, starts its trusted policy interpreter,
and admits one supervised reader. An unrelated process must be denied by the
mounted view. This bounded bring-up profile is not an external grant issuer or
a qualified protected-data service.

The adapter exclusively owns the interpreter's stdin/stdout (or equivalent
in-process call). Workers have no access to this channel. Every request is
serialized, followed by exactly one reply; a timeout, interpreter failure,
malformed reply or sequence mismatch makes the host stop serving bytes. The
host must retain the updated Bend state before applying any accepted effect.

## Encoding

Requests contain seven ASCII fields separated by one TAB, followed by one LF:

```text
WRITFS1<TAB>operation<TAB>actor<TAB>handle<TAB>offset<TAB>count<TAB>argument<LF>
```

The four numeric fields are canonical unsigned decimal U32: no signs, leading
zeroes except `0`, whitespace, overflow or alternate spelling. No CR, embedded
LF, extra field, non-ASCII input or unknown operation is accepted. Frames are
at most 131200 bytes excluding LF. The argument is the exact literal below or
canonical lowercase payload hex. Empty payload hex is allowed.

Replies contain five ASCII fields and LF:

```text
WRITFS1<TAB>sequence<TAB>status<TAB>value<TAB>detail<LF>
```

Sequence starts at 1 and increases on every processed frame, including denials.
The interpreter has a bounded lifetime and never wraps counters. Status is `OK`,
`DENY`, or `ERROR`. Value is canonical U32. Detail is a fixed reason code, except
INIT success returns the lowercase SHA-256 digest of the actual canary bytes.
Replies are at most 256 bytes including LF. No payload or untrusted path appears
in a reply or audit reason.

## Operations

| Operation | Actor, handle, offset, count, argument | Successful value |
| --- | --- | --- |
| `INIT` | `0, 0, 0, 0, <payload hex>` | Byte length, at most 65536; succeeds once |
| `ADMIT` | `1, 0, 0, 0, public-canary` | `1`; full Bend capability-to-commit gate admits the fixed reader domain |
| `STAT` | `<actor>, 0, 0, 0, root` or `data` | `0` for root, payload length for data |
| `LIST` | `<actor>, 0, 0, 0, root` | `1`; sole entry is `data` |
| `OPEN` | `<actor>, 0, 0, 0, root` or `data` | Fresh nonzero handle; read-only operations only |
| `READ` | `<actor>, <handle>, <offset>, <count>, -` | Admitted byte count, clipped at EOF; root cannot be read as a file |
| `CLOSE` | `<bound actor>, <handle>, 0, 0, -` | `0`; retires exactly that handle, including after revocation |
| `REVOKE` | `0, 0, 0, 0, -` | New revision; terminal for new observation and admission |
| `STATUS` | `0, 0, 0, 0, -` | Phase: 0 empty, 1 initialized, 2 admitted, 3 revoked, 4 stopped |
| `STOP` | `0, 0, 0, 0, -` | `0`; terminal, retains prior commit evidence |

There is one admitted actor slot, `1`. Native adapters assign it only after
matching their retained launch/session identity and lifetime to OS evidence.
They supply `0` for unknown requesters. No client chooses a slot. A PID, UID,
SID, label or package identity alone is insufficient. Each native host/service
instance owns fresh policy state and its own actor/handle table.

All metadata operations require admission and actor 1. The host may expose only
fixed public mount/volume structure before this point. Do not use a successful
STAT or OPEN as release authority: ADMIT first executes the complete Bend gate.
The fixed source is logical object/version 1/1; its destination is the registered
reader input domain, logical object/version 2/1. Full committed session, ledger,
write intent and retained origin policy stay in Bend state. Host slot 1 identifies
that domain only within this invocation; it is not a portable credential.

Handles are monotone, never reused, with at most 32 live handles and 65535 total
opens per interpreter. Each READ is at most 65536 bytes. Offset/count validation
occurs before narrowing native integers. Unsupported writes, links, alternate
streams and namespace mutations fail without an alternate path to bytes.

Revocation gates subsequent mediated requests; bytes already observed, cached
pages or transferred native handles are separately contained by the selected
host profile. CLOSE is cleanup by the broker for an existing bound handle, not
fresh caller authentication. Windows callbacks without current requester
evidence must use their per-open binding and report that limitation accurately.

## Generated-module interface

Build `writfs/Mount.bend` to a `.mjs` artifact using pinned Bend 2.0.39. Its default
export provides `initial()`, `dispatch(state, frame)`, `next(step)`, and
`reply(step)`. `frame` excludes LF; `reply` includes LF. Only the interpreter owns
the returned state. It never serializes it to a worker or accepts replacement
state from a peer. `runtime/node-policy.mjs` supplies bounded framing for native
Windows/Linux; the Genode adapter invokes the same pure module with QuickJS.

The public-canary profile deliberately uses a fixed local standing policy and
the existing trusted-input contract. Physical public status is an operator
precondition. It supplies no external owner approval, wall-clock expiry feed,
multi-user issuer, durable publication, or general desktop DLP claim.
