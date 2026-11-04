# One admitted native reader

## Example and current gap

A host freezes a public report and starts a supervised reader. Bend admits an
exact copy into the reader's registered input domain. That reader opens mounted
`data`; an unrelated caller is denied. Revocation stops future observations and
preserves the committed receipt. A storage snapshot alone cannot demonstrate
this behavior.

## Decisions

Keep one `Mount.bend` state machine and `MountAuthority.bend` authority path.
`DataOS.commit_from_capability` remains the final admission entry. OPEN and STAT
do not authorize release. Fixed operator-owned logical records and actor slots
are not credentials; the native supervisor establishes their meaning.

Freeze at most 64 KiB, hash the actual decoded bytes in Bend and retain the
immutable host buffer, sealed memfd or private ROM copy. Expose one logical name
and one admitted actor. Bound handles, requests, buffers, processes and protocol
exchanges. Never reuse a handle within a monitor instance.

The private ASCII protocol uses canonical unsigned decimal and lowercase hex.
Only the broker owns the channel and policy state. Replies must have the next
exact sequence. A malformed reply, timeout or interpreter loss stops service,
without retry, resynchronization or an alternate policy engine.

Native callbacks join OS facts to retained process/session lifetimes. Windows
captures the effective request token at open; later callbacks use their retained
per-open binding and do not claim fresh per-read identity. Linux joins kernel
context to a retained pidfd/start time. Genode joins exact trusted parent routing
to a retained session object; forged client suffixes do not inherit authority.

Native Node supplies the Windows/Linux policy runtime. Native QuickJS supplies
Genode's runtime, with heap, stack and execution bounds. Its bounded allocator
charges cached reservations against the existing 64 MiB limit and releases them
at teardown. This preserves generated policy and engine algorithms without
weakening Bend C's guarded sparse-memory assumptions.

## Security and evidence

Use public fixtures throughout qualification. Record actual mounts, native
processes, functioning positive controls and receiver-side checks. Required
native control setup must succeed before delivering input.

Confinement claims name their exact profile and tested channels. Windows'
zero-capability, Win32k-disabled reader passes mounted access and revocation but
cannot initialize its direct network/clipboard/COM probes; its full confinement
gate remains failed. A separate no-data LPAC diagnostic has registryRead and
Win32k enabled, no input or policy channel, and no admitted actor mapping.
Its API checks do not replace direct byte-worker qualification.

General enrollment, external issuance, dedicated service identities, arbitrary
delegation, all-route confinement, durable journals and restart recovery remain
separate product gates. Genode diagnostic LOG capabilities are explicit.

Revocation stops later mediated observations; it cannot retract delivered bytes.
Bounded process/session facts and fixed reasons do not establish human intent.
The contribution's journals are diagnostic rather than durable audit.

## Migration and rollback

The contribution is optional and adds no dependency to the core library. Retire
the owned worker, quiesce the dispatcher or session, stop the private interpreter
and release only this instance's resources. Cleanup failure remains a failure.

## References

The [product design](../../../../docs/WRITFS-PRODUCT.md) and
[native protocol](../../../../contrib/native-hosts/PROTOCOL.md) specify the native
API sources, source-boundary responsibilities and remaining deployment gates.
