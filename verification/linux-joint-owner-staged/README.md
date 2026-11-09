# Synthetic Linux joint owner: staged continuation verification

A synthetic selected worker can launch, be dispatched, receive a descriptor,
and reach the existing shared admission path with a same-call issued slot. A
revoked issuer update requires whole-instance containment and a trusted drain
returns actual stop effects. This record covers the in-memory model, not an
authenticated host. The earlier [WIP record](../linux-joint-owner/README.md)
retains failed native generation and incomplete experiments.

The source now stages Frontend mount/open and issue through independently
self-guarding helpers; only same-call singleton results reach the retained
owner. Drain similarly obtains its actual shared `H.revoke` Step after its own
root, issuer, incarnation and capacity checks, and emits only newly returned
stop effects while retaining history. No worker frame supplies these model
records or selects the generic profile. A real host must enforce private owner
state, trusted profile selection, fresh authenticated authority and time,
synchronous containment and effect ordering; the model does not establish those
properties or mediate the separate native Mount dispatcher.

The selected provider grant is exact; reader checks use subject-wide current
projections, so another current same-scope reader grant may satisfy them.
Negotiation readiness does not prove committed ledger, budget, evidence expiry,
original-graph verification or a Copy. Sampled ingress cannot enforce expiry
during silence; native timer, authenticated feed, recovery, resource bounds and
host confinement remain unqualified. No FUSE mount, native identity probe, VM,
GPU execution, or protected-host acceptance was performed.

Pinned Bend 2.0.39, generated Node and generated C/native CPU each produced
byte-identical [full outputs](tests-bend.txt), [Node](tests-node.txt) and
[native](tests-native.txt): 2,977 named PASS lines and 53 other PASS lines.
The [focused Bend](focused-bend.txt), [Node](focused-node.txt) and
[native](focused-native.txt) results match across 43 checks, including exact
lineage and selection, clock/reader failures, malformed owner and attempt boxes,
partial and repeated drain, and terminal capacities. Native C was compiled at
`-O0`; CPU execution is not GPU evidence. The [Bend source manifest](bend-input-sha256.txt)
identifies the tested model inputs.

Two synthetic mutation controls exercise deferred evaluation on all three
backends. The frontend-capacity guard returns containment with a maximum
frontend revision, while removing that guard produces a Nat overflow. Separately,
replacing `P.issue_result` with an overflow trap shows a refused Frontend open
returns without evaluating it, while a valid open reaches the trap. These are
bounded tests of particular branches, not proofs of global termination. The
[commands](commands.txt) identify source patches, controls, outputs and prior
failed attempts.

[Ordinary proof](proof.txt), [pinned Lean verdict](verdict.txt), the expected
[false-kernel control](negative.txt), and [strict OpenSpec](openspec.txt) passed.
The nonprivileged production-callback [handoff mock](handoff-mock.txt) and
[retirement mock](retire-mock.txt) passed; they do not mount or probe native
identity. The first mock build used incorrect bare make targets and failed;
its [log](mock-build-first-failed.txt), corrected [build](mock-build-retry.txt),
and cleanup are recorded in the commands.
