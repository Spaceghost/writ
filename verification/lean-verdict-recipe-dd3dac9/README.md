# Fresh-checkout BendTT recipe validation

On 2026-11-06 the Bash block in [docs/INSTALL.md](../../docs/INSTALL.md)
was extracted unchanged as [recipe.sh.txt](recipe.sh.txt) (SHA-256
`af7658d5db305518bc7424dbb3799d33fc7c068ac29008d3fd6f22f0b3000c23`)
and run from a fresh, detached clean checkout of
`dd3dac976326cd1dc096e0b716967720ada8c756`. It used the already downloaded
and SHA-256-verified official Lean 4.34.0 Linux x86_64 archive through
`WRIT_LEAN_ARCHIVE`; no second download was performed. The initial `TMPDIR` was
intentionally relative (`../writ-lean-temp-parent`); the recipe resolved it
outside the checkout and assigned a private absolute temp directory. The run
used low CPU and I/O priority to avoid competing with an ongoing native build.

The [recipe stdout](recipe.stdout) records archive and kernel-source hash
success; the outer process observed exit 0. The extracted Lean reported [version 4.34.0](lean-version.txt),
and the pinned compiler reported [Bend 2.0.39](bend-version.txt). The
[tool hashes](tool-hashes.txt) include the checked archive, installed Bend,
Lean and leanc, copied kernel source, generated C and built kernel. The
kernel SHA-256 before and after the verdict matched
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
The fresh kernel produced [ALL PROOFS CHECK](verdict.stdout); the `/bin/false`
control exited 1 with the expected [infrastructure error](negative.stderr).
The recorded before/after commit and empty normal Git status files show the
checkout was observed clean at those points. These observations are not
continuous monitoring, an audit of ignored/external inputs, or process attestation.

[guard-checks.py.txt](guard-checks.py.txt) ran three separate rejection checks:
TMPDIR inside the checkout, a bad archive, and an injected failing Git status
command. All three [rejected with exit 1](guard-checks.stdout). They are small
synthetic shell fixtures, not a test of every failure or an invalid-proof
rejection test. The generated C, Lean archive, extracted distribution and
kernel binary were kept outside the checkout; only small text evidence is
retained here.

The verdict concerns only this checkout's existing proof driver and its
assumptions. It does not prove the entire system, native confinement, durable
recovery, GPU behavior, compiler correctness or later source revisions.
