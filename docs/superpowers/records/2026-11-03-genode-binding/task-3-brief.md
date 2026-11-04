### Task 3: Tests

Create `HostBindingTests.bend` with a `main` that runs, in the style of `FrontendTests.bend`, one named check per scenario of GA-001 through GA-011 in the spec, at minimum:

- alias used after generation bump denied `StaleGeneration`; alias at current generation proceeds
- mount with matching route subject succeeds; mount whose route subject differs from the caller denied `RouteMismatch`
- open mints a distinct object; the parent object's aliases are unaffected
- close goes stale for two holders; close with stale revision leaves state unchanged (compare every field)
- delegated alias used by a non-delegated holder denied `SubjectMismatch`; recorded delegation accepted
- delegation requesting wider rights denied `WidenedRights`; narrower delegation carries only the narrower rights
- open with zero cap quota denied `QuotaExhausted` with no Frontend handle created; after quota top-up the open proceeds
- every denial returns the identical input state (write one helper that compares `State` structurally and use it in every denial check)
- two-level delegation chain: revoking the root makes both children stale; child wider than parent denied

Register the module in `Tests.bend`. Run the full suite on the JavaScript runner and natively (`bend Tests.bend -o ../writ-build/tests-native` then `+RTS --threads 4 --gpu off`). Record both final lines and the new total PASS count in your report.

Acceptance: all new checks pass on both backends; `ALL LIBRARY TESTS PASSED`.

