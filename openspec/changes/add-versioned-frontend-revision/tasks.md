# Versioned frontend revision tasks

Only the standalone descriptive arithmetic primitive in task 1.1 is complete.
All integration, migration, cleanup and qualification work remains pending.
Structural OpenSpec validation is not implementation or qualification evidence.

## 1. V2 model and bounded cleanup

- [x] 1.1 Implement tagged two-U32 revision comparison, safe carry and no-wrap terminal behavior in Bend; test both word boundaries, stale tags, maximums, and eager Node branch staging. ([Primitive and recorded checks](../../../verification/frontend-revision-v2/README.md); descriptive only, with no authenticated frontend or migration.)
- [ ] 1.2 Implement complete bounded original-handle counting and the cleanup-plus-retirement reserve for every V2 mutation; test all three allocators at `O + 2` and `O + 3` remaining successors, attenuation at `O + 1` and `O + 2`, zero-right/open revoked handles, exact last cleanup and retirement, caller mismatch, incomplete traversal and full unchanged denials.
- [ ] 1.3 Recheck all existing frontend authority, epoch, token, scope and commit contracts through V2; test read-only resolution under allocation exhaustion and prove no compatibility fallback accepts V1 requests as V2.

## 2. Exact legacy migration and coupled bindings

- [ ] 2.1 Implement a Bend-only candidate conversion and separately independent original-state verifier; test exact max-V1 mapping, every handle/token/plan field, tombstone/order preservation, altered high words, omissions, duplicate entries, bounded work and positive controls.
- [ ] 2.2 Specify and implement monitor-authenticated migration control, instance identity, serialization, resource admission, atomic state/fence/replay installation and rollback-resistant recovery. Exercise stale, forged, replayed, interrupted, ambiguous and restored snapshots against a real qualified integration; pure model fixtures are not host evidence.
- [ ] 2.3 Version the `HostBinding` facade and make multi-handle `bind_close` atomic over the independently verified original cut. Test repeated aliases, descendants, prior tombstones, missing/rejected later close, caller mismatch, denied work and unchanged whole-state/quota outcomes.
- [ ] 2.4 Bound and validate the binding revision, generation and quota/refund counters for each accepted binding transition; keep `revoke` without a frontend caller separate and demonstrate its remaining host cleanup obligation.
- [ ] 2.5 Inventory and version the Genode and Unikraft fixed-width channel codecs and monitor call sites for V2, or explicitly leave a range-limited V1 profile incompatible or incomplete. Test distinct revision high words with equal low words, unsupported versions, descriptor narrowing and stale requests; retain monitor-owned state and subject provenance, and do not treat a reply word or wire tag as caller authentication.

## 3. Evidence and qualification

- [ ] 3.1 Add non-vacuous Bend regression and mutation cases for FR-001 through FR-012, including last-allowed cleanup/retirement, all field comparisons, version fencing, rollback, an old reference presented to a new instance with the same numeric handle ID, and a freshly authenticated V2 request to an exact preserved handle. Run the full Bend suite, generated Node, native CPU, applicable native tests, and pinned Lean verdict; do not claim a physical GPU test from CPU fallback.
- [ ] 3.2 Establish actual authenticated migration, confinement, serialization, retained tombstones, replay fencing and crash recovery for every claimed host profile. A library model, synthetic fixtures or OpenSpec validation does not qualify a host.
- [ ] 3.3 Update current baseline specifications, named traceability, source manifest and reader guidance only after corresponding behavior and evidence exist; validate OpenSpec 1.16.0 strictly and preserve unresolved outcomes.
