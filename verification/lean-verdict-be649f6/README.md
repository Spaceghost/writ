# BendTT verdict on source be649f6

On exact source `be649f6b0784e12e9b91e39028cb6f87b8629b70`, pinned Bend
2.0.39 `bend PROOF.bend --verdict` exited 0 and printed `ALL PROOFS CHECK`.
The run used an isolated BendTT executable built from the unmodified packaged
`bendtt.lean` by official Lean 4.34.0. Lean checked and compiled the BendTT
kernel; Bend then used that executable to recheck its emitted proof book. This
is a kernel verdict for the named proof driver, not a proof of the whole system.

`LAWS.bend` contains 36 law declarations and `PROOF.bend` has 36 matching
proof definitions; [law-names.txt](law-names.txt) lists them. These cover guard,
denied-state, grant issuance, portable-host denial, policy-aware audit and
executor-rendezvous laws as stated, including their stated assumptions and
limits. They do not authenticate caller-supplied facts, establish native
isolation or durable publication, or prove full system security. `HostHandoff.bend`
is not imported by this proof driver and no handoff-specific law is claimed.

The official Lean Linux archive was verified against the release's published
SHA-256 in [lean-release-metadata.json](lean-release-metadata.json). The Nix
Bend package is pinned to the official 2.0.39 release; its wrapper and underlying
binary have separate hashes in [environment.txt](environment.txt). The exact
kernel source, generated C, built executable and emitted proof-book hashes are
also recorded there. The [105-file Bend source inventory](bend-source-sha256.txt)
identifies the tracked `.bend` inputs in the source tree. Generated C, binaries
and the emitted proof book remained outside the checkout and are not included.

The [reproduction transcript](audit-run.sh.txt) records the exact isolated
Lean compile and link, `BENDTT`-selected verdict and `/bin/false` negative
control. [audit-observations.txt](audit-observations.txt) records commands,
UTC times, exits and the same kernel hash immediately before and after the
verdict; these are observed hashes, not cryptographic process attestation.
Separate raw stdout and stderr files are retained, including empty files.
Both kernel build steps and the verdict exited 0; the control exited 1 with
an infrastructure error when the selected executable returned no verdict.
That control shows the verdict path does not accept an unsuccessful kernel;
it is not a malformed-proof rejection test. A separate first run emitted a
BendTT translation; a [captured direct recheck](direct-audit-observations.txt)
records the invocation, translation and kernel hashes before and after,
exit 0 and separate stdout/stderr. These hashes are observations, not process
attestation. The supported `BENDTT`
override avoided Bend's shared home cache. The compiler, Lean runtime, C
compiler, libraries, operating system and the recorded source remain trusted.

Earlier failed Lean startup and missing-tool attempts remain intact in
[kernel-verdict.txt](../kernel-verdict.txt); their cause was not determined.
The fresh verified Lean distribution started on this host. An initial timing
wrapper was missing and did not start Lean; [that setup failure](initial-wrapper-attempt.txt)
is retained separately from the subsequent successful builds.
