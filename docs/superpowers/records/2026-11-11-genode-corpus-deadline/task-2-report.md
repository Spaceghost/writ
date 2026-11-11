# Task 2 report: evidence and documentation

The complete native result and preserved failure are recorded in
`contrib/native-hosts/genode/VERIFICATION.md`, with separate manifests and
transcripts. Both downloaded ZIP hashes match GitHub's published artifact
digests. All 14 retained artifact-derived files match their manifest hashes.
Native acceptance and the actual guest timings are detailed in task-1-report.md.

The README now names each diagnostic deadline, distinguishes the existing
128 MiB service quota from the existing 256 MiB corpus-test quota, and directs
readers to the source-pinned execution records. NM001/NM007 traceability names
the current 3072-check run while preserving older evidence. No broader host
task was checked off. Final native runtime, probes, run scripts, workflow,
reviewed count and all authored Bend files match tested revision `7edf561`.
Windows, Linux and website sources remain unchanged from `09ed0bb`.

Documentation validation:

```sh
OPENSPEC_TELEMETRY=0 npm exec --yes --package=@fission-ai/openspec@1.16.0 -- \
  openspec validate --all --strict --no-interactive
git diff --check
```

OpenSpec: **45 passed, zero failed**; raw output is retained in
[openspec-validation.txt](openspec-validation.txt). Whitespace checks passed.
The three verbatim supervisor configurations retain Genode's terminal blank
line. Their narrowly scoped evidence `.gitattributes` disables only the
blank-at-EOF diagnostic for those files, preserving the reviewed ZIP bytes;
other whitespace diagnostics remain active.
All 54 local Markdown link targets in the updated native README/verification,
traceability and task-1 report exist. OpenSpec validates document structure,
not native behavior. The independent final review is recorded separately.
