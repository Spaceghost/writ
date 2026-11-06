# Linux native public canary CI run 42312512646

[Workflow run](https://github.com/Spaceghost/writ/actions/runs/42312512646)
executed exact source `61ab2a453915c4162e7ba726b9dfd6f1759f3410` on the
recorded Ubuntu runner. The **existing public WritFS canary**, separate from
the proposed protected-worker host, passed its native mount/revocation,
transport, interpreter-failure and broker-crash cases. Its full core
JavaScript and native CPU outputs each have 2,285 PASS lines, match each other
and the local Bend capture byte-for-byte, and have SHA-256
`bac0e2b581c8f4ad7eae2812e34177cbe97f35ed3f87e2d352da119aaa19f67a`. The
mount model JS and CPU output logs match with 70 PASS lines and SHA-256
`f378302f40f49d45202b171b807a5fc9ff3a5b0a84f05bfc8f70c58909e014f6`.
Ordinary proofs report `ALL PROOFS CHECK`, without a Lean kernel verdict.

`setup-refusal.log` is the intentional unsupported-Landlock setup case. Its
`FAIL` lines are retained: setup refused before input loading or Bend
admission, and it is not a successful protected setup. The successful
workflow verifies that expected refusal; it does not qualify protected-worker
identity, confinement, durable storage, recovery, or a GPU.

Text captures normalize terminal escapes, carriage returns and trailing
whitespace. `artifact-raw-sha256.txt` identifies the original downloaded
files; the eight relative tracked source hashes in `source-and-build-sha256.txt`
match commit 61ab2a4 (generated build paths are recorded separately).
`environment.log`, that source/build inventory, `ci.json` and
`artifact-metadata.json` retain runner, source, binary and workflow identity.
