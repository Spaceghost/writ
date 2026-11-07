# Planner N48 round-trip mutation review

A planner description with a valid nonzero high word must retain that value
through the public word codec. The prior 60-check fixture used zero high words
for several fields, so it could not detect selected truncations. One new Bend
test, `planner-envelope structural roundtrip preserves every maximum N48 high
word`, builds a description with distinct low words and the maximum allowed
high word in every N48 field, including two ordered sources, then compares the
decoded structure with the original. These remain untrusted descriptions; this
test does not authenticate an identity or change an authority path.

In a detached scratch checkout of `dd3dac976326cd1dc096e0b716967720ada8c756`,
ten individual mutants zeroed one decoded high word while leaving the existing
range checks in place. The [zero-context patches](mutants/) reproduce the exact
mutated source hashes in `results-before.json`; each was reapplied and checked.
Raw Bend/Node focused outputs are retained. Classification requires exit 0 and all 60 earlier PASS
lines to survive, or a nonzero exit and a named `FAIL:` to be killed. The same
classification was observed in Bend 2.0.39 and generated JavaScript under Node
26.10.0. All seven survivors then failed the new check; the three controls that
were already detected remain detected:

| Decoded high word | Before | After |
| --- | --- | --- |
| Request | Killed by existing request-boundary check | Killed by existing check |
| Expiry | Survived | Killed by new check |
| Graph stamp | Survived | Killed by new check |
| Policy stamp | Killed by existing mixed round trip | Killed by existing check |
| Authority stamp | Survived | Killed by new check |
| Invocation | Survived | Killed by new check |
| Destination object | Killed by existing mixed round trip | Killed by existing check |
| Destination version | Survived | Killed by new check |
| Source object | Survived | Killed by new check |
| Source version | Survived | Killed by new check |

The source-object and source-version mutants change each decoded occurrence of
that component; the other mutants change only the named field at the final
decoded proposal. [Bend before/after summaries](results-before.json) and
[results-after.json](results-after.json), the [Node summary](results-node.json),
and the per-mutant raw stdout/stderr show the results. Scripts ending in
`.py.txt` record the scratch procedure; the after and Node scripts are adapted
to accept zero-context patches with `git apply --unidiff-zero`. For replay,
copy the retained patches into `/tmp/writ-planner-boundary-audit/`; the after
runs use the candidate test file copied into the scratch checkout. No mutant
was applied to production.
These are ten selected faults, not exhaustive mutation coverage or proof of a
production defect.

The unmodified codec source has SHA-256
`d28e1de8fdd3b9257ffe016588056973701450691466cdae00765c5024b885f8`;
the new test source is
`cccfcd8dc7417872052cd7cb54267a9d2656a833b33fcf5a95a19aabf1bd2b57`.
The [Bend source inventory](bend-source-sha256.txt) identifies all test inputs.
Focused Bend passes 61 checks. Full Bend and Node each pass 2,163 checks with
byte-identical [output](full-bend-node.log), SHA-256
`a2bdd3383323d06aa9bac21e698f30fe0c0aadbacae7c4ab8b04648e272dfa47`.
The existing `PROOF.bend --verdict` passes with the previously verified
Lean-built BendTT kernel; those 36 existing laws do not prove this codec.
Strict OpenSpec validation passes 44/44. Native CPU and platform CI have not
yet been run for this revision and require the planned source review first.
No protected-host qualification or planner integration is claimed.
