# Linux public canary: automatic master CI

[Run 42378765744](https://github.com/Spaceghost/writ/actions/runs/42378765744)
passed its scoped public-canary workflow at exact source
`bfb805282a5beb390c923824bef52626303e6481`. The retained logs show 2,356
core checks on both generated JavaScript and native CPU, 70 mount checks on
each, ten native transport checks, and ordinary Bend proof checking. Ordinary
proof output explicitly requests `--verdict` for the separate kernel check.
The two core output files are byte-identical, SHA-256
`061c5309a0531d6895da81805dbe4e5f2b386bf7ec0942192ad51a2ca0fdccdd`;
the mount outputs also match each other. Revocation, policy-failure and
broker-crash public canary logs are retained.

The [protected setup attempt](artifacts/writfs-linux-native-1/setup-refusal.log)
was refused at step 8 before input loading or Bend admission; it receives no
protected-host qualification. The workflow's success does not override that
refusal or qualify a Linux worker or staged execution.

The original artifact ZIP digest matches GitHub's reported digest. Raw entry
hashes are retained; text copies are normalized as described in the
[index](../README.md). Eight tracked paths in the workflow's source/build
inventory match this source; two generated or native runner outputs were not
available for independent rehashing. This is not process attestation.
