# Structurally valid mixed-binding partial close

At source revision `5ba7ebc976808ad92ec0ea173d53736ca044693f`, a supplied
synthetic binding state can have a root handle owned by subject 7 and an open
descendant handle owned by subject 8. The binding model considers that state
structurally valid. A caller authenticated as subject 7 with the root's exact
token can close the root, but the same caller is rejected when closing the
descendant. The enclosing `HostBinding.bind_close` nevertheless reports
success, closes only the root handle, advances both object generations, prunes
the descendant delegation and refunds capability quota. The descendant alias
is stale while its frontend handle remains open.

The [witness](witness.bend) starts from the existing `HostBindingTests.derived()`
fixture and changes only the subject of frontend handle 3 from 7 to 8. It checks
both the unaltered and modified states with `H.valid`, confirms caller/token
matching at the root and mismatch at the descendant, and runs the descendant
`F.close` after a separately staged successful root close. A positive control
shows that the unaltered fixture's enclosing close succeeds and closes its
descendant. The witness then checks the modified state's actual enclosing
transition and its outcomes; it does not alter the Writ implementation.

The modified state is a **synthetic, structurally valid host-supplied model
state**. Existing `bind_open` and `bind_attenuate` copy their parent's subject
and token; the witness does not show that the modified state is reachable from
an empty model through those transitions. No native host, actual capability,
process, or filesystem was exercised, and no native exploit or host impact is
established. Structural validity does not authenticate a host snapshot.

On 2026-11-07 local time (2026-11-08 UTC), the pinned Bend 2.0.39 interpreter
and generated Node v26.10.0 each passed all 16 [witness checks](witness.stdout)
with byte-identical complete stdout, SHA-256
`7eefc48f59413725971e5e1d9b57b9c78bc11844643e8bf6b2a3874f37b5500d`.
Bend, JavaScript generation and Node exited 0 with empty stderr. The generated
JavaScript SHA-256 was
`f5b595bfc17d45ae9204b44f2b76a5c1d302befe68056092d20ca35f48f803c9`;
it is not included in the source package. The Bend executable SHA-256 was
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`.
The [tested inputs](tested-inputs.sha256) identify the witness and relevant
model files, not a complete compiler inventory. The [capture archive](captures.tar.gz),
SHA-256 `bca682fa1c5c575d2fa4e4847f5eb42d294e37a45299c290469c17aa0f1ee576`,
retains commands, status files, stderr, output comparison and the earlier
seven-check exploratory witness. Strict OpenSpec validation passed 45/45.

From the repository root with the pinned Bend toolchain on `PATH`, reproduce
the two model runs with:

```sh
bend verification/hostbinding-partial-close/witness.bend
bend verification/hostbinding-partial-close/witness.bend -o ~/tmp/hostbinding-partial-close.js
node ~/tmp/hostbinding-partial-close.js
```

This records a gap in the current model. Proposed
[FR-009](../../openspec/changes/add-versioned-frontend-revision/specs/frontend-revision-v2/spec.md)
requires an all-or-nothing close for the complete original cut, but its task
remains unchecked. This record neither repairs that gap nor the separate
[legacy terminal-revision owner-cleanup failure](../../docs/superpowers/records/2026-11-07-frontend-revision-exhaustion/README.md).
No V1/V2 cleanup, authenticated migration, host qualification or GPU claim
follows from these model checks.
