# Historical Frontend evidence for the native canary commit

For the fixed public Copy, `MountAuthority.descriptor` now retains the exact
Frontend state and reference passed to its one accepted `DataOS.commit_from_capability`
call with that call's full committed session, ledger and write intent. The
original raw `CommitResult`-to-Grant installer is removed. The retained
Frontend is historical evidence: it does not authenticate a caller, prove a
current registry or issuer, mediate LinuxHost, or establish a native host.
Mount's ADMIT, policy checks, WRITFS1 wire behavior and native runner remain
the existing single path. Public Bend constructors and existing implementation
helpers remain a trusted in-process boundary; worker bytes cannot supply them.

The focused synthetic `local Copy commit retains exact nonfirst frontend
descriptor and denies rejected inputs` duplicates a real descriptor to ID 3,
compares every retained Frontend field and the exact caller/ref against the
inputs to that commit, and checks rejected Frontend and empty-registry inputs.
It then revokes a synthetic source approval: fresh projections deny while both
cached commit-time projections still resolve, illustrating why historical
records are not live authority. A repeated commit rejects with committed session
and ledger unchanged. The fixed fixture is Free; this does not demonstrate
nonzero charge replay.

The [Mount model checks](mount-bend.txt) retain their existing 69-vector count
and include forged `Granted` wrapping `Rejected` (denied without changing the
prepared Mount state, no artifact or revision claims), duplicate ADMIT, REVOKE,
and STOP. Retention checks compare session and ledger, the full intent including
policy, label and backend, and the complete historical Frontend and reference.
The [LocalSupervisor](local-bend.txt) and Mount results match their generated
[Node](local-node.txt) and [Node Mount](mount-node.txt) outputs. The generated
Mount module passed nine nonprivileged [transport checks](bridge.txt); this is
not a FUSE mount or process-authentication test.

The combined [Bend](tests-bend.txt), [Node](tests-node.txt) and [native CPU](tests-native.txt) full outputs
match, with 2,993 named PASS lines and 53 other PASS lines. Exact tool details are recorded in [commands](commands.txt).
[Proof](proof.txt), the [pinned Lean verdict](verdict.txt), its expected
[false-kernel negative](negative.txt), and [strict OpenSpec](openspec.txt)
complete the model checks. The nonprivileged Linux [handoff](handoff-mock.txt)
and [retirement](retire-mock.txt) mocks do not qualify a mounted or confined
host. No native identity probe, FUSE mount, VM or GPU test was performed.

The premerge native-generation [failure](mount-premerge-arity.txt) and its
diagnostic-only [compiler output](mount-premerge-diagnostic.txt) were preserved.
It identified an oversized folded test continuation; the final test retains both
assertions in named helpers and generates with the unmodified pinned compiler.
Earlier exploratory [definition-order](initial-definition-order-error.txt) and
[case-count](initial-case-count-error.txt) failures are also retained. A
preliminary Node run was stopped when the asdf shim recursively invoked itself;
its partial output is not verification. Exact combined-tree Bend input hashes
are in [bend-input-sha256.txt](bend-input-sha256.txt); the repository-wide source
manifest identifies the delivered tree.
