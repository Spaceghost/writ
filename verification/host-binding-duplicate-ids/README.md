# HostBinding duplicate-ID regression

The PH-004 model must deny ambiguous reference mappings instead of selecting a
record by list order. Ten synthetic checks add two valid controls and test
duplicate object and alias IDs in both orders: each duplicate fixture is
invalid, and an attempted open returns `StaleRevision` with the exact supplied
state unchanged. A current-generation entry appears first in one order and a
different-generation entry first in the other. The alias fixture duplicates an
already recorded delegated alias, keeping its holder and object unchanged; it
does not rely on a second uncopied minter to reject the state.

These are constructed monitor states, not authenticated identities or native
capabilities. The checks do not establish native selector uniqueness, host
incarnations, isolation, replay after restart, or every possible ambiguous
mapping. No security law or production source changed.

## Local observations

Before the final commit, pinned Bend 2.0.39 (binary SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`)
ran `bend HostBindingTests.bend`: [focused output](focused.log) has 154 PASS
checks and 41 vectors. `bend Tests.bend` and generated JavaScript run with
Node 26.10.0 each produced 2,273 PASS checks and the success sentinel; their
stdout was byte-identical to [suite.log](suite.log), SHA-256
`1290d7761819f3e9af56ebd72401c3e13886d13722fa77e21dac8e6dc826db7a`.
Generated JavaScript SHA-256 was
`6ec554ca59df5a3b0f483af08c6369f62627e0e59026861570152440515c5a1c`,
and the generated file was kept outside the checkout. The 110 individual
[Bend input hashes](bend-inputs.sha256) identify the files used; they can be
checked against the candidate tree. These hashes and the logs are local
observations, not independent process attestation.

`bend PROOF.bend --verdict` printed [ALL PROOFS CHECK](verdict.log) with the
Lean-built BendTT kernel SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`,
matching the previously retained kernel record. It checks the 37 existing laws;
there is no new duplicate-ID law. OpenSpec 1.16.0 strict validation passed
44/44 and is structural, not proof of host behavior. No GPU or host identity
probe was run. Earlier CI and native captures retain their original source
attribution.

The optimized native build started before commit `0be9dc9` with the 110 Bend
input hashes above already recorded. Those hashes matched the committed tree
after the run ([check](inputs-after.log)); this is a local observation, not
process attestation. Pinned Bend built with `CC=clang-23`, `nice -n 15` and a
1,800-second timeout; [process inspection](compiler-observed.txt) showed
`-O3`. The [build](native-build.exit) exited 0 with an empty
[build log](native-build.log). The executable ran with `+RTS --threads 4 --gpu
off`, exited [0](native-run.exit), and its combined stdout/stderr
([native-cpu.log](native-cpu.log)) contains 2,273 PASS lines and the success
sentinel, byte-identical to `suite.log`. The native executable SHA-256 was
`9b853c203664960c7a2f448e6096f0dcb66213ee9f9f95af7bab845f576ad0e4`;
it and its generated GPU artifact remain outside the source tree. This CPU
run is not a GPU test or native host qualification.

## Guard-specific negative controls

In two detached scratch worktrees based on `e765650`, the current test file
was copied in and the single object uniqueness guard or single alias
uniqueness guard was replaced with `True{}`. The exact source deltas are
[object.patch](mutants/object.patch) and [alias.patch](mutants/alias.patch).
They have zero context and require `git apply --unidiff-zero`.
For each of the eight new invalid/denial assertions, a separate run kept that
assertion, both valid controls and all pre-existing tests, and removed the
other seven new invalid/denial assertions from the scratch test file. Each
matching mutant exited 1 at its named assertion: [object validity current](mutants/01.log),
[object validity other](mutants/02.log), [object denial current](mutants/03.log),
[object denial other](mutants/04.log), [alias validity current](mutants/05.log),
[alias validity other](mutants/06.log), [alias denial current](mutants/07.log),
and [alias denial other](mutants/08.log). This samples two removed guards; it
is not an exhaustive mutation analysis or a proof of the full protocol.
