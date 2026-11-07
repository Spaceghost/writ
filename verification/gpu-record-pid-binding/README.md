# GPU record checker: synthetic file-only controls

A record can name PID 111 in its compute-apps log while claiming PID 222's
utilisation as the long-run pmon evidence. The checker formerly accepted that
record, and accepted an incorrect reported pmon maximum. The later checker
requires a matching, canonical positive PID in each field and an exact
recomputed maximum above zero for runs of at least 10,000 ms. It requires one
PID token per field and compares log PID text exactly. These extra PID and
maximum checks do not gate shorter runs: their pmon maximum may be `-`, and
their sampler logs must still be present and hash correctly.

Digit-only `wall_ms` accepts leading zeroes and is classified without a shell
integer conversion; arbitrary-length values cannot silently skip long-run
checks. The positive PASS count is checked as a decimal string for the same
reason. The checker accepts only the single `+RTS --gpu VALUE -RTS` block
emitted by `observe.sh`, with `on` or a canonical positive integer from 1 to
999999 in `GB` or `MB`; `off`, default, duplicate and out-of-block options fail.
This conservative subset starts above the runtime's 16 KiB minimum and avoids
an oversized numeric conversion. It intentionally rejects external v1 records
with multiple runtime options or other valid sizes, including fractional and
leading-zero forms. A syntactically accepted size does not establish available
device memory or actual option execution.

`observe.sh` passes workload arguments after this block, and Bend's runtime
scans later arguments for additional RTS delimiters. A later block can override
the GPU setting. Because the v1 record flattens arguments with `$*`, it cannot
recover their original boundaries. The checker therefore refuses any `+RTS`,
`-RTS` or `--RTS` substring anywhere in the recorded workload field, including
benign substrings within one argument. This is a conservative refusal rule,
not authenticated reconstruction of arbitrary original arguments.
For new captures, `observe.sh` also refuses CR/LF or these delimiter
substrings in its arguments before it starts setup or a workload. The checker
refuses unknown or malformed record-body lines and duplicate or non-final
`gate` fields; a gate may be absent for `--derive`. These restrictions can
reject otherwise benign external v1 inputs and do not authenticate older
flattened records or reconstruct their argv.

The decimal syntax follows the runtime `strtod`/end-pointer and suffix checks
in the previously retained generated `bang.c` from Bend 2.0.39, SHA-256
`dc7f5730a166b8318b13fbd30117feb12d9cf2c9b15162487ec1e432493d3d6c`.
`observe.sh` accepts sized modes ending in a digit before `GB` or `MB`, so it
does not emit a trailing decimal point even though the runtime parser can parse
one. The checker is narrower still: it rejects fractional forms such as `.5GB`.

[controls.py.txt](controls.py.txt) creates synthetic text logs and records in
its own temporary directory and invokes only the file checker. On this host
(Python 3.14.7, `/bin/sh` resolving to GNU bash 5.3.20), the
[current checker](current.log) passed all 50 controls, exit 0. The
[previous checker](before.log), from `5e019c8` with SHA-256
`7d4df17bf05a75ffdd9dfa464ebceb08710ef719a6d924dac3238261dfcc88ab`,
disagreed with 33 expected outcomes and the control driver exited 1. Those
include a valid huge PASS count with shell arithmetic errors on stderr. Each
case checks both `--derive` and the regular checker's exit status.

Reproduce from the repository root:

```sh
python3 verification/gpu-record-pid-binding/controls.py.txt
python3 verification/gpu-record-pid-binding/prelaunch.py.txt
writ_old_checker=$(mktemp)
git show 5e019c82284dbc7dddb1fb7e4c4e931db1d4a09f:scripts/gpu-validation/check-record.sh > "$writ_old_checker"
python3 verification/gpu-record-pid-binding/controls.py.txt "$writ_old_checker" # expected exit 1
rm -f "$writ_old_checker"
```

The [pre-launch controls](prelaunch.log) use a private PATH containing only a
synthetic setup tripwire. They confirm malformed arguments are refused before
setup, while a benign argument reaches the tripwire. They do not invoke
`nvidia-smi`, start the probe or execute GPU work.
`shellcheck` reports no finding for `check-record.sh`; it reports six findings
for `observe.sh`, the same six code/message pairs as the baseline version.
The existing findings include intentional word splitting and were not changed
or presented as a clean shellcheck result.

Separately, the new checker read the old task-2 `a` and `a-long` records and
their already-retained run-local logs and returned `gate: PASS` for each;
their record SHA-256 values were respectively
`ffec01b97a5ceb034845936c1da28b532c1f4bead3e7c009f280ffd153b19074` and
`b0f3e1e5c10046ad11e9891af296277313364c5cfd80489bf94ff7d6c2987012`.
This is a later file-only recheck, not a new GPU measurement, and historical
records and their original checker conclusions are unchanged.
The retained local run directories contained 156 `rts_options` fields: 132
matched the supported device profile and the other 24 were `off` or default
CPU/fallback controls. This is a field-shape survey, not a revalidation of all
78 records or a claim that those files are authenticated.
An independent structural survey of the same 156 blocks found no unknown or
non-field body lines and no duplicate or non-final gate field. That does not
establish that the recorded argv or other facts are authentic.

These checks do not authenticate logs, establish process lifetime or eliminate
PID reuse, prove module identity, check the sanitizer summary count, or prove
what environment the observed target actually received. The device and host
limits in the earlier records still apply. No GPU or protected host was run or
qualified by these controls.
