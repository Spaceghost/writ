# Working on the rclone contribution

This contribution is optional. Keep it outside Writ's root entry points and
normal library test suite. The root Writ invariants still apply.

All policy and service behavior belongs in `bend/`. The explicit Go exception
is `go/`, containing rclone interfaces, bounded transport, and transport tests.
Do not duplicate policy decisions in Go or turn a denial into `fs.ErrorCantCopy`.
Generic plaintext reads must remain denied in the reference profile.

The loopback reference service is bounded and memory-only. Its fixed bootstrap
authority is for local integration exercises. Do not imply crash durability,
production credential issuance, arbitrary worker confinement, or a complete OS
security boundary. Keep the wire contract and limits explicit.

Run the contribution's Bend tests on JavaScript and native CPU, the Go transport
tests, and real CLI integration checks. Keep generated code, executables, module
caches, and test data in a build directory outside the checkout.
