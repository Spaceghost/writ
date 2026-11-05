### Task 7: Full verification, records and host preconditions (task 2.2)

Run:
- `bend Tests.bend -o ../writ-build/tests.js && node ../writ-build/tests.js > verification/tests-js.txt`;
- `bend Tests.bend -o ../writ-build/tests-native && ../writ-build/tests-native +RTS --threads 4 --gpu off > verification/tests-native.txt`. This is a CPU run with `--gpu off`, and the record says so. The two files must be byte-identical, with the same PASS count;
- `bend PROOF.bend > verification/proofs.txt`;
- one attempt at `bend PROOF.bend --verdict`, appended verbatim to `verification/kernel-verdict.txt` (a missing Lean kernel is recorded as NOT VERIFIED, as before);
- `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive > verification/openspec-validation.txt`.

Update `VERIFICATION.md`:
- an Issuance row in the suite table, the new Facade count, and the new total;
- the "counting both forms yields N" sentence;
- the proof-scope list (the new laws, each with its one-line rationale and limits, or "tested, not proved").

Update the count in `README.md` at line 114, and the current-tree count gates (`utils/nix/writ.nix`, `WRIT_CORE_EXPECTED` in the Genode workflow, and the `build-and-run.sh` message) to the new total.

Add a "Remaining host preconditions" section to `docs/GRANT-ISSUANCE.md`: transport identity verification, signature verification for off-host approvals, durable and serialized state, per-use projection rebuilding, enablement and capability negotiation in a host adapter, and the host-corpus rebaseline (Unikraft and Genode gates still at 782). Run `git diff --stat master` to confirm that the don't-touch list holds. Check box 2.2.

Acceptance: both backends pass with the same new total; `ALL PROOFS CHECK`; OpenSpec strict passes; every record agrees with the runs. All seven boxes are checked, each citing its evidence, and the change is not archived (the controller decides on landing).
