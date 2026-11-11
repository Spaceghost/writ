# Task 1 report: fresh native completion

Implementation: `7edf561433c04419e3102fc0878e0f72ef3162a6`.
Native run: [43091571073](https://github.com/Spaceghost/writ/actions/runs/43091571073),
job `130769690057`, completed successfully on 2026-11-11 at 20:09:00 UTC.

The previous run at `09ed0bb` timed out after 2679 of 3072 core assertions.
Its downloaded artifact digest was verified and its failed serial transcript,
environment, sanitizer output and ordinary-proof output were preserved. It did
not emit the final source/build manifest or copied configuration, because the
first boot never completed.

Only `run_genode_until`'s full-corpus diagnostic bound changed, from 600 to
1200 seconds. A fresh build used the unchanged pinned Bend, Genode, compiler,
QuickJS and QEMU inputs, then passed all three native boots:

- 24 host allocator assertions under ASan, UBSan and leak detection; the same
  24 allocator assertions on native Genode libc.
- All 3072 core assertions and their final summary/exit gates, followed by all
  69 mount checks, including the 64 KiB boundary.
- 56 raw filesystem assertions (44 reader, six stranger, six forged-label),
  and eight ordinary libc/VFS assertions.
- Zero live and reserved allocations after interpreter teardown. Peak tracked
  reservation was 69,195,528 bytes under the unchanged 134,217,728-byte limit.
- Ordinary Bend proof checking: `ALL PROOFS CHECK`. No independent kernel
  verdict, physical GPU execution or complete protected-host result is claimed.

Guest core time was 520,850 ms; mount time was 73,822 ms. Their 594,672 ms sum
is close to the old 600-second deadline. The successful run was faster than the
failed baseline; this demonstrates completion and motivates runner headroom,
not a code speedup or proof that the faster run itself required over 600 seconds.

The [native manifest](../../../../contrib/native-hosts/genode/evidence/ci-7edf561-success.json)
records exact source/tree, run/job/artifact identity, per-file hashes and
transcript normalization. The ZIP matched GitHub's published SHA-256
`9fa95d2fee7c91b457dfa7bc0569fea0d987c4cbd9cea2333247340e171bda87`.
All three supervisor configs and source/generated-script/binary/ISO hashes
were retained. Authored Bend, production runtime and native probe sources are
unchanged from the candidate; later changes only record documentation/evidence.
