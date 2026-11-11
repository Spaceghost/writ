# Core verification tooling

The reviewed complete core count lives in `core-check-count.txt`. Nix and the
Genode workflow consume the same file. When intentionally adding or removing
checks, review the named tests, run the complete suite, and update this file in
the same contribution. Never set the expected count from the output being tested.
Historical platform records retain the counts and revisions actually observed.

From the repository root, with pinned Bend 2.0.39 and Python 3:

```sh
mkdir -p ../writ-build
bend Tests.bend > ../writ-build/core.log 2>&1 &&
  python3 utils/verification/check_core.py ../writ-build/core.log
bend PROOF.bend
python3 -m unittest discover -s utils/verification -p 'test_*.py'
```

The producer's exit status and the log check are both required. The checker
requires the reviewed number of `PASS:`/`PASS ` records, no `FAIL` record and
exactly one success marker at the end. It rejects incomplete or concatenated
runs. It validates text structure; it does not authenticate a log or prove that
the expected tests executed. For native CPU output, invoke the native test
binary successfully, then check its log with the same command.

`Writ core checks` runs on GitHub-hosted pull-request runners. It exercises the
bundled JavaScript backend, ordinary Bend proofs, and OpenSpec structure. Native
host, native CPU, physical GPU and independent kernel verdicts retain their
separate workflows and evidence requirements. No new runtime dependency is
introduced into the Bend library.
