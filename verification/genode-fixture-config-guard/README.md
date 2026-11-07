# Public Genode fixture exact-argument guard: offline controls

A guarded public fixture compares each complete `install_config` argument with
one independently recorded fixed reference before forwarding it. It does not
inspect an installed configuration, select a subject, alter the legacy shim, or
establish an authenticated actor, confinement or Genode host qualification.
The [design](../../openspec/changes/add-genode-host/public-fixture-config-guard-design.md)
records exact boundary and remaining trust assumptions. The original public
[route-control retry](../genode-route-retry-42361441863/README.md) remains
separate historical evidence; no guarded Genode/QEMU run occurred here.

The fixed [positive argument](../../contrib/native-hosts/genode/nested-channel/writ_guard_positive.args)
(1,709 bytes, SHA-256 `9832324d540f478108e0df4063468163702be4b2716ffb0663e59e35fe7e577e`)
and [negative argument](../../contrib/native-hosts/genode/nested-channel/writ_guard_negative.args)
(1,667 bytes, SHA-256 `bb05c8aef62045425f71da1fee373b06e9b8539adc457592fdb50266856fe48c`)
were extracted from their independently retained raw ZIP config members by
removing the one installer-added final LF, not from a guarded invocation. The
negative fixture is the 3,525-byte exact archived `actual.run`, SHA-256
`175a8e32cceaa6c4d38498a95e7754fc4fe5438ad0960a2ebadccb2f808e0c6e`.
The preparer checks these fixed hashes at staging. This relies on the trusted
reviewed checkout, overlay and tool process; a same-UID actor can alter inputs
or substitute a path after checks. Reference `open`/`read` is not protected
against FIFO, symlink or concurrent replacement and is not time-bounded by the
16 KiB byte cap. Only an independently bounded outer supervisor can bound such a
stall. The preparer does not authenticate the process or any actor.

In the isolated working tree, before the candidate commit, Tcl 8.6.16 ran:

```sh
timeout 30s tclsh contrib/native-hosts/genode/nested-channel/test-fixture-config-guard.tcl
```

It [exited 0](tcl.exit) with [28 named PASS controls](tcl.log). The two
[stderr messages](tcl.stderr) are deliberate negative controls: synthetic
installer failure and changed fixture policy. The tests source the actual Writ
boot helper and both fixed entry points but replace build, installation, image
construction and launch with Tcl stubs. They verify a positive path, the
negative fixture's late-marker same-spawn continuation, exact forwarding,
refusal of changed policies, prefix, route, arity and size, per-call checking,
installer error propagation and pre-install/image/launch refusal for a mutated
fixture. Stub `puts` reproduces the expected one LF; it is not actual installed
file readback. Stub output is not Genode evidence.

The [overlay preparation](overlay.stdout) was subsequently run from clean
source commit `69aecaa73aeee0745eac1ae8e042c3f88e262272` using Bend 2.0.39:

```sh
timeout 120s contrib/native-hosts/genode/nested-channel/prepare-overlay.sh \
  /tmp/writ-genode-nested-overlay.configguard69aecaa \
  /home/jadams/.local/share/writ-toolchains/bend-2.0.39/bend/bin/bend
```

It [exited 0](overlay.exit) with [empty stderr](overlay.stderr). The captured
[environment](overlay-environment.txt), [128 source-input hashes](overlay-source.sha256)
and [16 staged-file hashes](overlay-staged.sha256) identify the observed
inputs, including both fixed guarded entry points and references. Those hashes
were verified again after preparation. The generated monitor C's
[SHA-256](generated-c.sha256) is recorded; the file and external overlay stay
outside the checkout. Preparation did not build, boot or run Genode, and the
hashes do not establish process attestation or eliminate staging races.

Python 3.14.7 separately ran, under the same 30-second bound:

```sh
timeout 30s python3 contrib/native-hosts/genode/nested-channel/test-fixture-config-references.py
```

It [exited 0](references.exit) with [18 named checks](references.log) and
[empty stderr](references.stderr). They independently compare fixed pins,
reject mutated bytes and mutated pins, compare both argument vectors against
raw archived ZIP entries, verify the exact archived negative fixture and confirm
that the negative argument only removes the specified route. These tests never
regenerate expected bytes. The recorded [test input hashes](input-sha256.txt)
identify the observed sources and raw ZIPs; matching them does not constitute
process attestation. `bash -n` and ShellCheck also passed for the updated
preparation script. OpenSpec validation and the source manifest are recorded by
the delivered tree, not as a host test.
