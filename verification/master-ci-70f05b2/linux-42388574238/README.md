# Linux public canary: automatic master CI

[Run 42388574238](https://github.com/Spaceghost/writ/actions/runs/42388574238)
passed its scoped public-canary workflow at exact source
`70f05b25eb92581c2f95993151e20ad6b4d71509`. The retained logs show 2,472
core checks on both generated JavaScript and native CPU, 70 mount checks on
each, ten native transport checks, and ordinary Bend proof checking. Ordinary
proof output explicitly requests `--verdict` for the separate kernel check.
The two core output files are byte-identical, SHA-256
`249ab6deda8e904a60f064597ad367aaf77c354aadc9261ecc6e3cf1bffa6181`;
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
