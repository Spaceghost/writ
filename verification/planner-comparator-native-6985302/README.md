# Historical combined-preview native CPU capture

The previously reported optimized native CPU run for combined source
`6985302b7bbbd6ffaf2afcd7790c42f3a564f4c0` was described as using Bend
2.0.39, clang 23.1.1 and `+RTS --threads 4 --gpu off`. The available raw
[run log](run.log) contains 2,223 PASS lines and `ALL LIBRARY TESTS PASSED`;
it is byte-identical to the previously retained Bend/Node capture, SHA-256
`600b77f04ccc713259ac6637a91851acda87f71ba937ad971da4392d5e11fa9f`.
The available raw [build log](build.log) contains the compiler update notice.
The original command invocation, compiler process observation, separate stderr
and process exit statuses were not retained in these logs; the commands and
outcome above are the earlier report, not independently attested by the logs.

The [109-file Bend source list](bend-source-sha256.txt) is copied exactly from
source `6985302`, where it was recorded for the combined preview. Each entry
was checked against the corresponding file in that Git tree, and its entries
cover all tracked `.bend` files there. The list SHA-256 is
`1ba4f0ad9b9f282b35cf9095a52498909f94d925203209c6c2777a95bd6c6d39`.
The earlier record reported that these inputs also verified after the native
run; that observation does not attest to the compiler process.

The existing `/tmp/writ-planner-both-6985302-native` executable was observed
later when preserving this record and had SHA-256
`a2c0e23dbb275f64f60513ea6fe2e9afe99c44d0261db1b4b105b200508aaaa8`.
No contemporaneous binary hash is available to establish that the currently
observed file is the one run. The executable and generated sources are not
included here. This historical CPU result is not a GPU test, a planner
admission or authentication result, or protected-host qualification. It does
not cover the later high-word test regression.
