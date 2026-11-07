# Linux public canary: automatic master CI

[Run 42382988204](https://github.com/Spaceghost/writ/actions/runs/42382988204)
passed its scoped public-canary workflow at exact source
`4671e205f0dc4f9e8ce8f1d85f6767497092e30f`. The retained logs show 2,413
core checks on both generated JavaScript and native CPU, 70 mount checks on
each, ten native transport checks, and ordinary Bend proof checking. Ordinary
proof output explicitly requests `--verdict` for the separate kernel check.
The two core output files are byte-identical, SHA-256
`f81c3a25ba677b8d006635528790ed6efbdfdcc3c139f645d94f68b7adf41909`;
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
