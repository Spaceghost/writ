# Planner boundary and comparator integration preview

This isolated preview combines the N48 codec regression candidate
`262a8d4d683c4c48711e734bd1358bc4b33a3993` with the non-authoritative
plan-field comparator `8fae6965d71e260026353a44854d31c4f6cb6ec2`. The codec
regression adds one aggregate boundary test; the comparator adds 60 synthetic
checks. Neither branch's previous outputs or platform runs are reattributed to
the combined source. The comparator returns only a Boolean and does not resolve
request IDs, expiry, manifest, evidence, authenticated caller, registry state or
admission. All planner acceptance tasks remain unchecked.

On 2026-11-06 pinned Bend 2.0.39 and generated JavaScript under Node each
completed **2,223 checks** and `ALL LIBRARY TESTS PASSED`. Their stdout is
byte-identical, SHA-256
`600b77f04ccc713259ac6637a91851acda87f71ba937ad971da4392d5e11fa9f`.
The [capture](planner-boundary-comparator-bend-node.log) and
[Bend source inventory](planner-boundary-comparator-bend-source.sha256)
identify the actual inputs. Generated JavaScript stayed outside the checkout.

`bend PROOF.bend --verdict` exited 0 and reported
[ALL PROOFS CHECK](planner-boundary-comparator-verdict.log) using the
audited Lean-built BendTT kernel, SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
Existing proof declarations do not import or prove the new comparator or
boundary tests. This is a regression verdict for existing laws, not a proof of
the new code. Strict OpenSpec validation passed 44/44.

The Nix JavaScript check at exact source `6985302b7bbbd6ffaf2afcd7790c42f3a564f4c0`
also passed 2,223 checks with the same output hash. Its derivation was
`/nix/store/ikf417sz2b3zy3xz3cl5dfjj2wxdly8v-writ-tests-js.drv`, and its
output was `/nix/store/a71kh2yac6yb6r346yfqxz0064lj4xkb-writ-tests-js`.
This does not establish a full flake check or Nix native execution.

No native CPU build, completed platform CI, GPU test, protected-host
qualification or endpoint has been established for this combined source.
The Genode count pin is updated to 2,223 for future exact-source runs. The
prior [comparator record](planner-plan-match-local.md), [mutation review](planner-n48-mutants-dd3dac9/README.md)
and [planner codec record](planner-envelope-local.md) retain their own source
and limits.
