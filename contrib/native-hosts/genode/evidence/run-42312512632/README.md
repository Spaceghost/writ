# Genode native public-canary CI run 42312512632

[Workflow run](https://github.com/Spaceghost/writ/actions/runs/42312512632)
executed exact source `61ab2a453915c4162e7ba726b9dfd6f1759f3410` in the
recorded Genode 26.08 base-hw QEMU profile. The generated core model corpus
passed 2,285 assertions and the mount model corpus passed 69; reported times
were 195,534 ms and 124,063 ms. The run also passed its separately scoped
native public filesystem and libc/VFS canary boots, and the 24 allocator
invariant checks. The QuickJS tracked peak was 60,675,673 live bytes of its
134,217,728-byte limit; the guest log's missing real-time clock warning is
retained.

This is native Genode/QEMU and public-canary evidence for the recorded source,
not physical GPU, a qualified protected-worker identity or confinement profile,
a durable store, authenticated witness, supported sink, or recovery. The
model suite does not qualify any of those absent host services.

All text artifacts from the workflow are retained with terminal escapes,
carriage returns and trailing whitespace normalized. `artifact-raw-sha256.txt`
hashes the original downloaded files; the 204 relative tracked source hashes in
`source-and-build-sha256.txt` also match commit 61ab2a4 (generated build paths
are recorded separately). That file, `environment.log`, `ci.json` and
`artifact-metadata.json` retain the source,
toolchain, native build and workflow identities.
