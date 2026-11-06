# Model-only Linux integration candidate

A synthetic frame can describe a worker's launch and peer credentials. The
Linux Bend adapter tests their modeled consistency and calls the shared host
transitions. It cannot establish that a real process sent the frame, prevent a
transferred descriptor from reaching a different process, or confine a worker.
This tree includes no protected-worker native broker, launcher, or invocation
harness; the separate WIP `lane/linux-host` contains unfinished native sources
and their unresolved risks. The existing native WritFS public canary is a
separate contribution and does not qualify this profile.

This candidate ports only the Linux monitor and its synthetic tests from that
lane onto master `a286870`. The model adds 118 checks to the prior 1,942-check
suite. No Linux acceptance task is checked or claimed complete. Named scenario
coverage and missing host evidence are in
[Linux host traceability](../../../../openspec/traceability/linux-host.md); the
[synthetic identity record](task-2-synthetic-report.md) retains the known
separate-branch source-review findings and earlier failed/incomplete results.

The full Bend and Node suites each pass 2,060 checks with byte-identical output
(SHA-256 `c655abd826c42113d23cc2dae7a5795b971aa176251610398522a4f944740076`).
Host QuickJS passes 2,060 checks, program exit 0, no exception, 19,944 ticks,
and 16,089,224 peak live bytes. `bend PROOF.bend` reports `ALL PROOFS CHECK`;
no Lean kernel verdict is available. OpenSpec strict passes 44/44. The optimized native CPU suite for the
standalone 2060-check candidate also passed with the same output hash. These are model and backend
checks, not authenticated Linux identity, native confinement, Genode guest,
or GPU evidence.

At that candidate, the Nix assertion and Genode workflow expected 2,060 checks; workflow path
filters include the imported Linux monitor. Existing 1,942-check recorded CPU
and Genode results are historical and are not relabeled. The 2,060-check Nix
run remains unrecorded. [Genode run 42307229741](https://github.com/Spaceghost/writ/actions/runs/42307229741)
passed 2,060 core and 69 mount checks for `a88c5e5`; its retained
[environment](../../../../contrib/native-hosts/genode/evidence/42307229741-environment.log)
and [corpus](../../../../contrib/native-hosts/genode/evidence/corpus-42307229741.log)
record the exact source and result. A related full integration
preview attempted an offline Nix JS check and stopped it when uncached
compiler dependencies began rebuilding; that attempt did not reach the test.

The subsequent combined Linux and HostWire candidate expects 2,065 checks;
see the root [verification record](../../../../VERIFICATION.md) for its
separate results and remaining evidence gaps.

## Combined candidate execution

The combined [Nix flake check log](../../../../verification/nix-combined-flake-check.log)
records `nix flake check --no-update-lock-file --option max-jobs 1` passing
all checks, including the already built JavaScript, native CPU, ordinary proof
and OpenSpec derivations plus both version checks. It ran on source `73a8055`
with evidence-only files staged; no Bend, OpenSpec or Nix inputs changed in
those staged files. The Nix native and JavaScript output hashes match the
2,065-check Bend capture. This does not establish a Lean kernel verdict or GPU.


Source `73a80554e1b11ef29282ec724ce23f2f71716401` adds the HostWire bounds
fix to this model. Bend, Node and optimized native CPU passed 2,065 checks
with byte-identical output (SHA-256
`6f7c55909c94af843f65152f51f453798d0684e3e19c1db766bfa79ed7b5d449`).
Host QuickJS passed 2,065 checks at 19,918 ticks, and the [Nix JavaScript
check log](../../../../verification/nix-combined-tests-js.log) produced the
same output (`nix build --no-link --option max-jobs 1
.#checks.x86_64-linux.tests-js`, output
`/nix/store/fhf011ifd1abbqm6jgsib2nicb69a26z-writ-tests-js`). The [Nix native CPU check log](../../../../verification/nix-combined-tests-native.log)
also passes (`nix build --no-link --option max-jobs 1
.#checks.x86_64-linux.tests-native`), with the same output hash and output
`/nix/store/f9qxpwsi9bgarz3i1wfq6cfgav1az4h3-writ-tests-native-run`. Ordinary proofs
pass without a Lean kernel verdict and OpenSpec strict passes 44/44.

[Genode run 42308676812](https://github.com/Spaceghost/writ/actions/runs/42308676812)
passed 2,065 core and 69 mount checks in a base-hw x86-64 QEMU guest; the
[environment](../../../../contrib/native-hosts/genode/evidence/42308676812-environment.log),
[source/build hashes](../../../../contrib/native-hosts/genode/evidence/42308676812-source-and-build.sha256),
[corpus](../../../../contrib/native-hosts/genode/evidence/corpus-42308676812.log),
[filesystem](../../../../contrib/native-hosts/genode/evidence/filesystem-42308676812.log),
and [VFS](../../../../contrib/native-hosts/genode/evidence/vfs-42308676812.log)
logs are retained. The [Linux public-canary run](../../../../contrib/native-hosts/linux/verification/run-42308676909/README.md)
and [Windows Node run](../../../../verification/windows-policy-run-42308676869/README.md)
also passed their stated scopes. The Linux setup-refusal failure output is
preserved as an expected denial. Captured terminal output is normalized; raw
artifact hashes are retained alongside it. None of these results qualifies the
separate Linux protected-worker profile, a Windows protected host, or a GPU.
