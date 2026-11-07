# Linux public canary: automatic master CI

[Run 42356867007](https://github.com/Spaceghost/writ/actions/runs/42356867007)
passed its scoped public-canary workflow at exact source
`e129c931ceb1d249cf0b0874a91390e5eef840c9`. The retained logs show 2,263
core checks on both generated JavaScript and native CPU, 70 mount checks on
each, nine native transport checks, and ordinary Bend proof checking. Ordinary
proof output explicitly requests `--verdict` for the separate kernel check.
The two core output files are byte-identical, SHA-256
`f417d996a69f6d893d85a04ecc6d6f119dfae4dfea785aacc31353551cf9262f`;
the mount outputs also match each other.

The [protected setup attempt](artifacts/writfs-linux-native-1/setup-refusal.log)
was refused at step 8 before input loading or Bend admission; it receives no
protected-host qualification. The workflow's success does not override that
refusal or qualify a Linux worker.

The original artifact ZIP SHA-256 matches GitHub's reported digest. Raw entry
hashes are retained; text copies are normalized as described in the
[index](../README.md). Eight tracked paths in the workflow's source/build
inventory match this source; two generated or native runner outputs were not
available for independent rehashing. This is not process attestation.
