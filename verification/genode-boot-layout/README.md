# Synthetic fixed-layout checks

The isolated Linux C layout primitive checks the reviewed fixed public-fixture
mapping on test-owned temporary trees; it is not the complete proposed
inventory. The [33 control results](synthetic.log) include both scenarios,
changed and unsafe types, unsupported-operation injection and modifications
between independent scans. Its deliberate wrong-config positive shows that
passing layout checks does not establish contents. A separate ordinary
non-test build exported only the [layout-check symbol](production-symbols.txt).

Commands and compiler flags are in the [helper README](../../contrib/native-hosts/genode/boot-inventory/README.md).
The compiler was GCC 16.2.1 on this Linux host; the test, undefined-behavior-sanitized and production shared objects were external `/tmp` artifacts. The sanitized run had byte-identical output to the normal controls, and `-fanalyzer -Werror` accepted the production build. Tests created only exclusive, owned `/tmp` fixture trees and
used no real devices, Genode, QEMU, protected data, workload or host probe. The
checks do not implement the required procfs reopening, hashing, exclusive
publication, external deadline or supervisor, and they do not establish boot
consumption or cleanup. Unsupported actual bind-mount, procfs, interrupted
publication and worker-termination cases remain untested. No host or GPU
qualification is claimed.

The pinned Bend 2.0.39 executable had SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`.
`bend Tests.bend` exited 0 with 2,318 PASS lines and the final suite sentinel
([stdout](bend.log)); `bend PROOF.bend --verdict` exited 0 with
[ALL PROOFS CHECK](proof-verdict.log), using audited BendTT SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
Both commands ran against the unchanged Bend sources in the worktree based on
`161655144b2946a3ec2750ce0de51250387e6075`, after the native layout edits;
they do not verify this C primitive. An initial attempt to run each command via
the old recorded `/nix/store/0zkagxgg1y0awz43syx8048diggprj1q-bend-2.0.39/bin/bend`
failed with exit 127 because that path was absent. `bend --version` was also
unsupported; the replacement path's executable hash was verified before use.
OpenSpec 1.16.0 strict validation passed 44/44. No GPU execution was performed.

An initial development run stopped after its fifth check because the Python
fixture teardown treated a list returned by a setup callback as a socket. The
test harness was fixed before the recorded normal and sanitized runs. The one
owned temporary tree left by that failed teardown was removed after verifying
its unique synthetic config, links and 33 generated extra names.
