# Linux session credential binding: synthetic model evidence

A worker launched with a modeled process start time of 917 cannot pass its
input barrier by replacing both frame credentials with the same PID and a
start time of 999. Before this change the same synthetic decoded frame returned
`DeliverInputs`. The monitor now retains the framed launch credential with the
exact session returned by the same successful Launch, checks it at Barrier,
and clears the records on successful restart. These are modeled broker facts,
not native authentication or a live canary/registry authority bridge.

Executed in an isolated worktree based on `fa795b7` with Bend 2.0.39, Node
v26.10.0, clang 23.1.1 and OpenSpec 1.16.0. Scratch binaries, generated C and
JavaScript, and the worktree were outside the source package, under `~/tmp`.
The [Bend input inventory](bend-inputs.sha256) lists all 143 tracked or new
Bend files in the tested worktree, including the new synthetic test driver.
A later comment-only correction to `LinuxHost.bend` has an explicit
[implementation-token comparison](comment-token-check.txt), with its
[reproduction script](comment-token-check.py.txt).

- `bend Tests.bend`: [complete output](tests-bend.txt), including the 16 new
  binding checks and the existing suite's final success.
- `bend Tests.bend -o tests.js && node tests.js`: full output identical to the
  Bend suite by `cmp`; generated executable JavaScript, not GPU execution.
- `bend hosts/linux/monitor/LinuxCredentialBindingTests.bend -o binding.js &&
  node binding.js`: [16 focused checks](focused-node.txt), including traversal
  through 4096 synthetic records.
- The same focused driver generated as a native CPU executable and ran all
  [16 checks](focused-native.txt). The full native suite build uses clang
  `-O3`; its [observed compiler command](native-clang-command.txt) is distinct
  from earlier `-O0` runs. The [full-suite `-O3` attempt](native-o3-incomplete.txt)
  did not finish within its wall-time limit and produced no executable; a
  separately bounded [static `-O0` fallback](native-o0.txt) built and ran the
  full suite with one CPU thread and GPU disabled; its output matched the Bend
  and Node outputs. [C regenerated from the exact final tree](native-c-comparison.txt)
  was byte-identical to the frozen native input. `-O0` changes optimization-dependent calling conventions
  and does not replace the incomplete `-O3` result.
- `bend PROOF.bend`: [ordinary proof check](proof.txt) passed; no new security
  law or proof is claimed. The first `--verdict` attempt reported the
  [missing Lean 4.34.0 executable](verdict-unavailable.txt). After restoring
  the documented kernel under `~/tmp`, the [kernel verdict](verdict.txt) passed;
  its SHA-256 was `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`,
  matching the previously verified build. The `/bin/false` kernel
  [negative control](verdict-negative.txt) exited 1 without a verdict. This is
  an infrastructure control, not a malformed-proof rejection test.
- `openspec validate --all --strict --no-interactive`: 45 passed, 0 failed.

An [initial attempt](mjs-not-a-test.txt) generated `.mjs` and ran it with
`node`. The module exported its functions but produced no output and did not
invoke `main`; it was an invalid verification attempt and is not counted as a
pass. The executable `.js`
runs above are the actual Node evidence.

Repeated Launch is not replay protection. The native broker must independently
acquire truthful credentials, bind the session to the process lifetime and
endpoint, mediate effects and preserve stop effects at restart. The modeled
credential lookup has no new session cap and uses a tail-recursive accumulator;
existing identity lookups and runtime resources still limit capacity. No native
peer probe, kernel isolation test, protected host qualification, or GPU run is
claimed.
