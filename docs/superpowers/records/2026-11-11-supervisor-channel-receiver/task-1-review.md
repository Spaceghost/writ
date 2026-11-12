# Task 1 review: Bend channel attribution (63d0e415)

Spec compliance: ✅ (all interfaces, 8 tests, Tests.bend registration, count 3072 -> 3080 present; steps 4-6 not re-run by me, focused run confirmed 8/8 PASS)

Quality: Approved

## Judged points
1. attribute -> attribute_checked(valid_roles(map), ...) validates the map before inspecting the fact in every branch (FromRole, UnknownSender, Malformed all go through attribute_fact only on True). valid_roles enforces nonzero (role_is_zero) and uniqueness against all later entries (index_free recursion), so non-adjacent duplicates are caught.
2. malformed_each covers all 7 reasons with reject_equal (exhaustive pairs, same reason echoed). invalid_maps_deny covers duplicate and zero index, including FromRole{0n} on the zero map, plus direct valid_roles checks. IT.denied asserts Rejected with equal reason AND State.equal(state, input), so unchanged state is asserted.
3. Importing LocalSupervisorTests/IssuanceTests is safe: Tests.bend calls each module's main() explicitly, imports do not run main, so no double registration; count rises only by the 8 checks here (focused run prints exactly 8). Coupling is test-to-test but only for fixtures (LS.empty, LS.scope, IT.denied); acceptable, though a fixture rename there would break this file.
4. Vacuity: tests are not vacuous overall. Residual: principal_of falls back to Principal{0n} on Denied, so attributed_source_submits fails safely, but destination_role_rejected would still pass with NotAuthority if attribution failed; it is anchored by the separate check that role 2 attributes to 102 (payload_principal_is_ignored).

## Findings
- Minor, LocalChannelTests.bend:249-253: destination_role_rejected could pass if attribution denied (from = 0). Fix: also assert principal_is(C.attribute(roles(), C.FromRole{2n}), 102n) inside that check.
- Minor, LocalChannelTests.bend:178: synthetic marking is only in a comment block; fine, but name could be synthetic_roles for clarity.
- Minor, LocalChannelTests.bend:255-259: payload_principal_is_ignored is structurally a duplicate of role-2 attribution (attribute takes no payload); acceptable as documentation per the brief.
