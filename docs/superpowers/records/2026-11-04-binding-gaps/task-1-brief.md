### Task 1: Re-check "routed as another subject" at use

Today `routed_otherwise` is evaluated only in `delegate`. A delegatee that is later routed as a different subject on the object's service keeps its delegated authority. Add the check to `holder_authorized`'s delegated arm: if the holder has a recorded route on the object's service naming a subject other than the object's owner, deny `SubjectMismatch`. Keep the root-route requirement. Add tests: (a) delegatee W authorized through a node, then a route for W on the same service naming subject S is added to the state (a hand-built but `valid` state, since no transition adds routes); W's open is denied `SubjectMismatch`, state unchanged; (b) a route for W on another service does not affect it; (c) the delegate-time check still denies as before. Add vectors for (a). Update the GA-005 and GN-004 rows and the "coverage boundary" text in the traceability file.

Acceptance: new checks pass on both backends; every existing check unchanged; vectors identical across runs.

