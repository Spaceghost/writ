# Windows 10 VM: model, JavaScript bridge and library suite

On 2026-11-07 a Windows 10 VM ran the generated WritFS canary model and the
Node bridge tests against public, synthetic test data, then separately ran the
generated library suite. The model reported 70 PASS lines (69 vectors plus
the exported-count check), the JavaScript bridge 9, and the library suite
2,809. All three processes exited 0 with empty stderr. This is separately
scoped Windows 10 model and Node subprocess evidence, not native WinFsp mount,
native C pipe transport, LPAC, GPU, confinement, or host-qualification evidence.

## Inputs and environment

* Windows reported `Microsoft Windows [Version 10.0.19045.6093]`; the test
  account was not elevated. See the original [inventory](inventory.txt).
  Node and CMake were not found on PATH; the Visual Studio installer and WinFsp
  runtime were not found at the default locations checked. This is not an
  inventory of every installed tool or location.
* The portable Windows x64 Node reported [v22.23.4](node-version.txt) with
  [exit 0](node-version.exit). Its downloaded nodejs.org archive SHA-256 was
  `cbc74b5e0982c9dbb41525fd8fb5dcd32fbee237863f7829072f4639a1ce5f20`;
  `node.exe` SHA-256 was
  `dccc52de28d8df2ee22d2062424f8c563070d95d8ad70c54c4bf01d590dec14f`.
  These hashes identify the local files; they are not a signature verification.
* The source package identified revision
  `9131a2a77c89905e6e69e1f793d369a2128ea165`, and the scoped
  [source inventory](source-SHA256SUMS) was checked with `sha256sum -c` on
  the host. Generated modules are identified by [generated-SHA256SUMS](generated-SHA256SUMS):
  `mount.mjs` SHA-256 `4dea0e692616bf41ef086c4b6b16f94cddcaa172b76c7350e6813dfe46026882`;
  `mount-tests.js` SHA-256 `6736a2cb79d2d873466470ad60c96da5a56603727d874ff6a7b09be245187ba7`.
  The generated files were checked against these hashes on the host and are
  not committed. Source commit `810e8ee` adds separate historical runtime
  evidence after `9131a2a`; it was not the source of these two generated files.
* The separate full-suite JavaScript was generated from source commit
  `810e8ee` with pinned Bend 2.0.39 and has SHA-256
  `0207cfdfb1c79b28ce057b83d3810c3f3b865bddecd8f277d2ed87491ad97d4d`;
  the host checked it against [full-tests-810e8ee.sha256](full-tests-810e8ee.sha256).
  Generation used the source checkout with an unrelated local board-answer
  modification outside compiler inputs; it was not a pristine whole worktree.

The unmodified [model runner](model.cmd) records the actual absolute shared
folder paths and commands: portable `node.exe --version`, then `node.exe`
with `mount-tests.js`, and finally `node.exe check-bridge.mjs mount.mjs`.
The [inventory runner](inventory.cmd), [additional tool check](tools.cmd),
and its original [output](tools.txt) are also retained. The inventory checks
were not a build or an attempt to install a dependency. The separate
[full-suite runner](full.cmd) invokes the generated library suite with the same
portable Windows `node.exe`.

The full-suite generation command was:

```sh
nice -n 15 env TMPDIR=/mnt/MediaVolume/Media/writ-windev-tmp BEND_NO_TELEMETRY=1 /home/jadams/.local/share/writ-toolchains/bend-2.0.39/bend/bin/bend Tests.bend -o /mnt/MediaVolume/Media/writ-windev-tmp/package-9131a2a/generated/full-tests-810e8ee.js
```

## Results and limits

* Model: [stdout](model.stdout), [stderr](model.stderr), [exit](model.exit).
  `ALL NATIVE MOUNT MODEL TESTS PASSED` is the model's own output and refers
  to this generated model, not an observed filesystem mount.
* Bridge: [stdout](bridge.stdout), [stderr](bridge.stderr), [exit](bridge.exit).
  The harness spawns Node child processes and exercises the JavaScript bridge
  over their standard streams. Its own output calls these “NATIVE TRANSPORT
  PROBES”; that wording does not mean the separately implemented native Windows
  C pipe transport, its deadline controls, or native host confinement were
  exercised here.
* Full library suite: [stdout](full.stdout), [stderr](full.stderr),
  [exit](full.exit). It printed 2,809 lines matching `^PASS[: ]` and ended
  `ALL LIBRARY TESTS PASSED`. The stdout SHA-256 is
  `ff9b11443479d5338225ac55649f939b89ab637e5a707549afda11b6b11ed96c`.
  This is generated JavaScript executed by Windows Node, not physical-GPU or
  native-host evidence.

Raw captures and status files retain the Windows output bytes. The earlier
Windows Server 2025 native canary's failure and incomplete LPAC worker evidence
remain separately recorded in [Windows verification](../../contrib/native-hosts/windows/VERIFICATION.md).
This VM run changes none of those findings and does not complete a host task.
