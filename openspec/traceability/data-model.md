# Data Model Traceability

Baseline: [data-model/spec.md](../specs/data-model/spec.md).

`Tested` refers to executable checks in the recorded JavaScript and native CPU
runs. `Reviewed` means a source or documented-contract correspondence; it does
not claim a dedicated test for every scenario. The whole-system authority and
payload boundaries remain in [DESIGN.md](../../DESIGN.md).

| Requirement | Implementation | Evidence and coverage |
| --- | --- | --- |
| DM-001 | [Core.bend](../../Core.bend): `all_types`, the eight type helpers, `State.unknown`, `nodes_valid` | **Tested:** [CoreTests.bend](../../CoreTests.bend), "valid graph admitted", "empty seed type domain rejected", "unsupported seed type domain rejected". The valid fixture contains the all-types seed. [BackplaneTests.bend](../../BackplaneTests.bend), "static narrowing cannot change declared output schema", establishes that a static domain does not authorize runtime relabeling. |
| DM-002 | [Core.bend](../../Core.bend): `State`, `sink_gate` | **Tested:** `CoreTests`, "untrusted provenance is checked separately" and "callee effect requires grant even when requested mask is zero". These distinguish provenance, secrecy, and effects at the observable sink boundary. |
| DM-003 | [Core.bend](../../Core.bend): `Bits64.join`, `meet`, `equal`, `subset` | **Tested:** `CoreTests`, "exact 64-bit union across both words", "exact 64-bit intersection", "bit 63 cannot be satisfied by low word"; [PropertyTests.bend](../../PropertyTests.bend) exercises bits 31, 32, and 63 through propagation. |
| DM-004 | [Core.bend](../../Core.bend): `Stamp.equal`, `verify`; [Backplane.bend](../../Backplane.bend): `word64_matches_nat`, `stamps_agree` | **Tested:** `CoreTests`, "changed graph generation denies", "changed policy generation denies", "authority epoch high word is checked". `BackplaneTests`, "stamp bridge preserves high word", "stamp bridge cannot truncate high word", "bit63 epoch mismatch cannot alias low epoch". |
| DM-005 | [Transfer.bend](../../Transfer.bend): `CodeId.equal`; [Frontend.bend](../../Frontend.bend): token lookup; [Backplane.bend](../../Backplane.bend): artifact equality/preservation | **Tested:** [TransferTests.bend](../../TransferTests.bend), "all 256 code bits bound"; [FrontendTests.bend](../../FrontendTests.bend), "all 256 token bits participate in lookup"; `BackplaneTests`, "write intent preserves all 256 artifact identity bits" and "artifact identity differs in final word". No cryptographic digest calculation or signature verification is asserted. |
| DM-006 | [Transfer.bend](../../Transfer.bend): `ObjectVersion.equal`, `Objects.equal`, `Plan.equal`, `scoped` | **Tested:** `TransferTests`, "read object version exact", "preflight source version exact", "old read cannot approve expanded source manifest". **Reviewed:** structural manifest equality is order- and multiplicity-sensitive; the explicit reorder and repeated-occurrence scenarios do not have dedicated named checks in the current suite. Billing remains governed by origin payment rules, as documented in `DESIGN.md`. |

## Bounds and assumptions

The 2^48−1 compiled natural-number arithmetic cap is documented in
[LIBRARY.md](../../LIBRARY.md); it is not an executable overflow-handling test in
this suite. Exact 64-bit restriction values and 256-bit identities use U32 words
and are not narrowed to that scalar domain. Snapshot/manifest completeness and
authentication are supplied by the monitor; records do not prove their origin.
