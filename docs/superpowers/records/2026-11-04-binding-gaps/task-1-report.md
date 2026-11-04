# Task 1 report: re-check "routed as another subject" at use

Status: DONE (commit 71edf5c on lane/binding-gaps, not pushed)

## Change
- `HostBinding.bend` `holder_authorized`: the delegated arm now also requires
  `Bool.not(routed_otherwise(routes, holder, object_owner(object), object_service(object)))`
  after the existing root-route (`alias_routed` on `chain_root`) requirement. The route arm
  is unchanged. Denial stays `SubjectMismatch` via `resolve_subject`, so denial order is
  unchanged. Comment explains: use-time counterpart of `delegate`'s target check; a
  rerouted domain acts for another subject on the service, keeping authority would merge
  subjects; a route on another service changes nothing; on Genode it models a parent
  reconfiguration the monitor observes through its own route records, not through the
  invoking domain; runtime enforcement still rests on GA-010.
- `delegate_resolved` comment: one line pointing to the use-time repeat.

## Tests (HostBindingTests.bend, all in ga005_checks, after existing checks)
Fixtures: `worker_rerouted_routes`, `worker_other_service_routes`, `worker_rerouted`
(session_shared + W routed as subject 8 on service 1), `worker_opened_rerouted`,
`worker_other_routed` (W routed on service 2), `mounted_worker_rerouted`; transition
`rerouted_delegatee_open`.
1. `GA-005 delegatee rerouted after delegation fixtures are valid states` (valid on all three hand-built states)
2. `GA-005 a delegatee later routed as another subject on the service denied SubjectMismatch at use` (via `denied`, state unchanged) + `VECTOR GA-005-7 bind_open denied SubjectMismatch`
3. `GA-005 rerouting the delegatee also withdraws its derived alias` (W's opened alias 3, attenuate denied)
4. `GA-005 a later route for the delegatee on another service leaves its delegation usable`
5. `GA-005 delegation to a worker already routed as another subject is still denied SubjectMismatch` (delegate-time)
- Summary line updated: 126 -> 131 checks, 40 -> 41 vectors (131 `Test.check(` and 41 `vector(` calls in the file).
- Worker comment in the identities section notes the rerouted fixtures give W a route.
- Mutation check: running the new tests against HEAD's HostBinding.bend fails on check 2
  (the use-time denial), so the test is not vacuous.
- No existing check's assertion or name changed: PASS lines vs stored
  verification/tests-js.txt differ only by the five added lines; the 40 existing VECTOR
  lines are byte-identical to verification/host-binding-vectors.txt.

## Traceability
- Vector table: GA-005-7 row added.
- Fixture domain sentence: notes which fixtures route W as subject 8.
- GA-005 row: new check names, GA-005-7, and coverage-boundary text stating
  `routed_otherwise` is checked at delegation and at every use, that this closes the
  parked use-time finding of the 2026-11-03 re-review, that rerouted fixtures are
  hand-built and shown valid, and that route records tracking the parent is a host obligation.
- GN-004 row: description, new check name, GA-005-7.
- Discrepancy: the file had no sentence saying the check runs "only at delegation time"
  and no parked-items note (grep for "parked" finds only the plan). I put the closure
  note in the GA-005 coverage boundary instead. Task 3 expects to add a line to a
  "parked-items note"; it will need to create one or reuse this sentence.

## Verification (final runs, after the last edit)
- `bend HostBinding.bend --check-only`, `bend HostBindingTests.bend --check-only`,
  `bend DataOS.bend --check-only`: ALL PROOFS CHECK.
- `bend Tests.bend` (JS): ALL LIBRARY TESTS PASSED, exit 0, 769 PASS, 41 VECTOR (was 764 / 40).
- Native: `bend Tests.bend -o ../writ-build/binding-gaps/tests-native`, run with
  `+RTS --threads 4 --gpu off`: ALL LIBRARY TESTS PASSED, exit 0, 769 PASS, 41 VECTOR.
  JS and native VECTOR lines identical. This is a CPU run (GPU off), not a GPU test.
- `bend PROOF.bend`: ALL PROOFS CHECK. `--verdict` not run: no Lean toolchain on this host.
- `bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`: 43 passed, 0 failed.

## Not done (Task 3 scope)
Stored runs, host-binding-vectors.txt, VERIFICATION.md, environment.txt, manifest not
regenerated; they are now stale relative to the tree (764/40 vs 769/41).
