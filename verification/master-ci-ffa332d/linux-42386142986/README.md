# Linux public canary: automatic master CI

[Run 42386142986](https://github.com/Spaceghost/writ/actions/runs/42386142986)
passed its scoped public-canary workflow at exact source
`ffa332ddc289b54d34908ee6799b925550e12750`. The retained logs show 2,448
core checks on both generated JavaScript and native CPU, 70 mount checks on
each, ten native transport checks, and ordinary Bend proof checking. Ordinary
proof output explicitly requests `--verdict` for the separate kernel check.
The two core output files are byte-identical, SHA-256
`7bd212f679c4e4eb7554c7970abaf912090b8773a82be45f48ba4c7276348573`;
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
