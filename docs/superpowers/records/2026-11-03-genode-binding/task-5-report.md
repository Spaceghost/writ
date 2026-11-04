# Task 5 report: vectors, mapping, and records

Status: DONE_WITH_CONCERNS (minor; see the end)

Commits on lane/genode-binding (not pushed):
- ff7fc89 "Emit canonical HostBinding vectors and fold in deferred test minors": HostBindingTests.bend,
  LAWS.bend (comment only), HostBinding.bend (one comment line), verification/host-binding-vectors.txt (new).
- cf14441 "Record HostBinding vectors, traceability, and verification counts": VERIFICATION.md,
  openspec/traceability/genode-capability-adoption.md (new), tasks.md, verification/tests-js.txt,
  verification/tests-native.txt, verification/source-sha256.txt.

## Results
| Run | Exit | Final line | `^PASS:` | `^PASS ` (Transfer) | Total |
|---|---|---|---|---|---|
| `bend Tests.bend` (JS), run 1 and run 2 | 0 | ALL LIBRARY TESTS PASSED | 687 | 53 | 740 |
| native `tests-native +RTS --threads 4 --gpu off` | 0 | ALL LIBRARY TESTS PASSED | 687 | 53 | 740 |

- 740 = 638 baseline + 102 HostBinding. JS run 1, JS run 2, and native output are byte-identical. The
  native run is CPU only (`--gpu off`); it is not a GPU test.
- HostBinding summary line: `HostBinding: 102 checks passed, 30 vectors emitted; GA-010 is a reviewed host
  obligation, not a model test`.
- Vectors: `set -o pipefail; bend Tests.bend | grep '^VECTOR ' > verification/host-binding-vectors.txt`, then
  the same into ../writ-build/genode-binding/t5-vectors-run2.txt; `cmp` silent, both SHA-256
  5b1918a531cd76b4936b3cf73a6f1b32aa1c8d94e31d7ea7149bb38708cce4ba. The native run's VECTOR lines also match.
- `bend DataOS.bend --check-only`: exit 0. `bend PROOF.bend`: ALL PROOFS CHECK (identical to verification/proofs.txt).
- `bend PROOF.bend --verdict`: exit 1, `Error: BendTT infrastructure: the kernel did not build (lean: Executable
  not found in $PATH: "lean"); --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or
  $BENDTT set to a built kernel`. No verdict obtained.
- Manifest: regenerated as `git ls-files` minus itself, `LC_ALL=C sort`, `sha256sum` (the existing file's
  order and coverage match that rule exactly; no header describes it). `sha256sum -c --quiet` passes; 297
  entries, coverage equals the tracked tree. It includes the other files already on the branch.
- Final re-check on the committed tree: JS and native rerun outputs equal the stored files; proofs and
  manifest check pass.
- Comment-only edits: LAWS.bend and HostBinding.bend have identical non-comment, non-blank lines vs f367256.

## HostBindingTests.bend changes
- Vector renderers `reason_name`, `alias_outcome` (`accepted alias=<a>;object=<o>`, so a host aliasing the
  parent object or minting an object for a delegated copy disagrees), `close_outcome` (`object=<o>`),
  `revoke_outcome` (`domain=<d>`), `vector`. Each renders the actual Change. Every vector line is printed
  right after the check asserting it; those checks now call named zero-argument transitions
  (`stale_open`, `suffix_mount`, ...) so the check and vector share inputs. The expressions are unchanged.
- 30 vectors: GA-001-1..2, GA-002-1..4, GA-003-1..3, GA-004-1..4, GA-005-1..3, GA-006-1..3, GA-007-1..3,
  GA-008-1..3, GA-011-1..5. None for GA-009 (meta) or GA-010 (reviewed-only).
- Deferred minors: rewrote the `generations_state` comment (valid but unreachable; transition staleness is
  GA-004 and GA-011). Replaced "GA-007 quota denial creates no Frontend handle" with "GA-007 only the retried
  open adds a Frontend handle and advances Frontend" (retry vs exhausted delta for handle count and Frontend
  revision). Added `GA-002 route withdrawal fixture is a valid state`. Added the GA-006 same-descriptor variant
  (`attenuated_copy_change`/`attenuated_shared`): `GA-006 read delegation of the same read-only descriptor is
  recorded` and `GA-006 delegatee of the read-only descriptor shares its object and carries read only`.
  Renamed shadowing parameters and pattern binders: `subject`→`caller_subject`, `domain`→`account_domain`
  / `wanted_domain`, `reader_caps`→`reader_slots`, `routes`/`quotas` params→`new_routes`/`new_quotas`,
  binders→`kept_routes`/`kept_quotas`, `service`→`wanted_service`, and `caps_of`'s `quotas`→`accounts`.
  Updated the header's GA-009 note.
- One extra check beyond the brief: `GA-011 revoking R's domain commits`, which asserts the revoke behind
  vector GA-011-1 (otherwise that vector would have no asserting check). Net: 98 − 1 + 1 + 2 + 1 + 1 = 102.
  Diffing the check names against f367256 shows only the five new names and the one replaced name.

## Records
- LAWS.bend: `generation_bump_monotone` comment reworded per review (contributes to staleness; the
  never-lowered property and the `bumped(False{}, o) == o` branch are not stated; "wrap" dropped).
- HostBinding.bend: `# Exported helper, not a release API: named so LAWS.bend can state the bump.` above `bumped`.
- Traceability: vector table (inputs, expected suffix, asserting check, one row per vector, checked
  mechanically against the vectors file). GA table: implementation, exact check names (all 80 cited names
  verified to exist), vectors, boundaries. GN/PH table: model evidence, vectors, reviewed-only parts. GA-010
  is marked reviewed-only by nature. GA-009's host-replay scenario, RAM quota, incarnations, cross-host,
  quiescence, and plaintext recall are reviewed-only.
- VERIFICATION.md: 36 .bend files; rerun toolchain line (Bend 2.0.39, clang 23.1.1, Node v26.10.0);
  HostBinding row 102; total 740; vectors subsection with command and cmp/hash; six laws; Task 4 `--verdict`
  error verbatim; a note that tasks 1.1-2.3 of this change are now checked.
- tasks.md: 1.1-1.4 and 2.1-2.3 checked. The intro line now says sections 1 and 2 are complete and 3 is
  pending. Section 3 is unchecked.

## Concerns
- `verification/environment.txt` (34 files, 638 checks, clang 19.1.1, node v24) and
  `verification/kernel-verdict.txt` ("three laws") are now stale. Neither was in my allowed file list.
  VERIFICATION.md says kernel-verdict.txt describes the earlier attempt. The integration step should refresh
  both.
- VERIFICATION.md's header ("clang 19.1.1") and its OpenSpec counts (for example "197 tasks", "22 pending
  changes") describe the original record. Other lanes have already changed them. I added a rerun line instead
  of rewriting history.
- I did not run OpenSpec: only 1.11.0 is installed, not the pinned 1.16.0. The traceability file is not an
  OpenSpec item, and task 3.2 (strict validation) is unchecked.
- openspec/README.md does not link the new traceability file, because it was not in my allowed list. The
  pending-change traceability files may not be linked there by convention anyway.
- Stored tests-js.txt/tests-native.txt now contain the 30 VECTOR lines. PASS counting is unaffected.
