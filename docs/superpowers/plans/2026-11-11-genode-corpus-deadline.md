# Complete the native Genode corpus within a bounded diagnostic deadline

Branch: `lane/genode-corpus-deadline`, based on
`09ed0bb83e348e437e25e830de5495ace09f39eb`.

## Example and current gap

The first native Genode CI run after the website/core-count integration,
[43084126793](https://github.com/Spaceghost/writ/actions/runs/43084126793),
loaded the correct reviewed count of 3072. It reached 2679 passing core
assertions, after the 24-check allocator marker, before its 600-second QEMU
deadline. It did not reach the complete core summary or the mount corpus.
This is an incomplete native result, even though hosted core, Windows Node,
and native filesystem workflows passed on the same master revision.

## Scope and decisions

- Use the established plan, task brief/report, independent review, progress
  ledger, and UTC activity log in an isolated worktree. Leave the active
  Windows branch and other lanes alone.
- Raise only the full-corpus diagnostic boot deadline from 600 to 1200 seconds.
  Keep the 40-minute CI job limit, all three boots, the reviewed count, final
  success/failure gates, VM interrupt budget, allocation bounds, and production
  service behavior unchanged. Completion must be demonstrated by a fresh run.
- Retain the failed transcript and capture the successful run's exact source,
  environment, timings, memory counters, configs, artifact identity, and hashes.
  If the larger bound exposes a real failure, investigate it rather than
  treating a timeout change as qualification.
- Update the native verification record and matching traceability with the
  precise result. No protected-host or durable-publication task is completed.

## Tasks

1. Preserve the baseline failure, implement the bounded diagnostic change,
   and run the complete native Genode workflow on the isolated lane.
2. Obtain independent review, record actual results and limitations, validate
   OpenSpec 1.16.0, and refresh the tracked source manifest.
3. Integrate into current master and push normally under the user's existing
   authorization, preserving any intervening work. Verify the remote result.
