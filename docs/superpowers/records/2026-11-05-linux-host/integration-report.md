# Linux model integration candidate

A synthetic broker frame names a worker and the process credential the monitor
expects. The Linux adapter decodes that description and invokes the shared
monitor checks; the facts are fixtures, not authenticated native observations.
The partial native broker and launcher remain unfinished and unqualified. Their
identity, confinement, failure and cleanup evidence is still missing, and Linux
host task 1.2 remains open.

This isolated integration candidate combines master `1a86884` with Linux lane
`7561f6e`. Later master updates from `bddf411` record a hosted nelibc
observation and a historical branch audit; they change no test inputs. The only textual merge conflict was the source manifest, regenerated
from the combined files. It adds the 118-check Linux model module to the
previous 1,942-check suite; no OpenSpec acceptance task is closed. The Linux
source/trust inventory distinguishes the partial broker from the public WritFS
canary. Known identity and setup gaps are in
[task-2-synthetic-report.md](task-2-synthetic-report.md).

The combined Bend and generated Node suites each pass 2,060 checks, with
byte-identical output SHA-256
`c655abd826c42113d23cc2dae7a5795b971aa176251610398522a4f944740076`.
The host QuickJS harness passes all 2,060 checks, exit 0, 19,944 ticks and
16,089,224 peak live bytes, with no exception. The ordinary proof check reports
`ALL PROOFS CHECK`; no Lean kernel verdict is claimed. OpenSpec strict validation passes 44/44. The full optimized native CPU
suite, run with four threads and GPU disabled, also passes with output matching
Bend byte for byte.
These model/backend checks are not native Linux identity, confinement, GPU,
or Genode guest evidence.

The executable Nix assertion and Genode workflow now expect the 2,060 current
checks. Workflow filters include the newly imported Linux monitor sources.
The prior recorded 1,942-check CPU and Genode results are historical and must
not be relabeled as 2,060-check outcomes. The updated Nix and Genode checks
have not yet been observed on this integration candidate. An offline Nix JS
check started rebuilding many uncached toolchain dependencies and was stopped
by the integration agent to avoid an extensive unrelated build; it did not
reach the test. Offline evaluation of the `tests-js` derivation succeeded; this
is not a build or test result.
