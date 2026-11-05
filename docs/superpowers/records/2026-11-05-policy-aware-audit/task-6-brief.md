### Task 6: Documentation, traceability and full verification for section 1

1. Write `docs/AUDIT.md`. It leads with this plan's worked example and the current gap: section 1 is modeled in Bend, while durable required audit, denial-append failure, verifiable history, queue bounds and every host wiring are not implemented. It then covers:
   - the event field table with each field's sensitivity, noting that identifiers and digests are not automatically public;
   - the excluded material;
   - the ownership and label rules (influences, the fail-closed label, outcome-independent policy);
   - the supported views and query limits (`max_page()`, work in visible events, cursor binding, no totals and no sort);
   - the export capability contract (three channels, releasable-view metrics, no ambient grant, no fallback);
   - the trusted inputs and who supplies them on a real host;
   - the residual timing, scheduling and traffic-volume channels, stated plainly, without any constant-time claim.
   
   It names the public entry points, and links the spec, the traceability file and `openspec/specs/decentralized-labels/spec.md`.
2. Write `openspec/traceability/policy-aware-audit.md` in the shape of `grant-issuance.md`. It opens by saying the change is proposed, section 1 is modeled, and no host adapter or acceptance scenario is implemented. It has one row for each of AU-001 to AU-009, giving functions, exact named checks (verbatim), laws and the coverage boundary. Mark these explicitly:
   - AU-004 and AU-006 are "not implemented (section 2, depends on add-durable-publication)";
   - AU-005 is "partial: recording preserves the decision (laws); append failure not modeled";
   - AU-009 is "partial: query work bounded; append queue not modeled";
   - "grant issuance for event-read and export grants" is a reviewed-only gap.
3. Run:
   - `bend Tests.bend -o ../writ-build/policy-aware-audit/tests.js && node ../writ-build/policy-aware-audit/tests.js > ../writ-build/policy-aware-audit/tests-js.txt`;
   - `bend Tests.bend -o ../writ-build/policy-aware-audit/tests-native && ../writ-build/policy-aware-audit/tests-native +RTS --threads 4 --gpu off > ../writ-build/policy-aware-audit/tests-native.txt`. This is a CPU run, not a GPU test. The two captures must be byte-identical (`cmp`);
   - `bend PROOF.bend`;
   - one `bend PROOF.bend --verdict` attempt. A missing Lean kernel is recorded verbatim as NOT VERIFIED;
   - `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`.
4. Write `verification/policy-aware-audit.txt` with:
   - the commands, Bend version and date;
   - the `Audit:` summary line and the total ("1428 plus N = M", as this tree prints it);
   - the `cmp` result and the proof and verdict lines;
   - each new law with its one-line rationale and limits, or "tested, not proved";
   - what was not exercised: durability, crash injection, history verification, any native host, transport authentication, and GPU.
5. Copy the captures into the record directory. Do not overwrite the shared `verification/*.txt` files.
6. Run `git diff --stat master` and show that only the touch list changed, and that `LAWS.bend`/`PROOF.bend` show additions only.
7. Update the `tasks.md` first line as ruled. Boxes 1.1 to 1.4 are checked, each citing its section and laws, and 2.1 to 3.2 stay unchecked.

Acceptance:
- Both backends pass with the same total.
- `ALL PROOFS CHECK`, and OpenSpec strict passes.
- Every traceability row cites existing check names verbatim.
- The evidence file matches the captured runs.
- No count pin moved.
- The change is not archived.

## Questions only Josh or Spaceghost can answer

1. `openspec/ROADMAP.md` orders audit "After durable state". This plan rules that section 1 may land first, because it appends nothing. Is landing a modeled audit section ahead of `add-durable-publication` acceptable, or should the lane wait?
2. Who is the authority for an event-read or export grant: each stream owner approving through an Issuance-style directory, or the monitor alone? Section 1 rules that the monitor installs them and records the gap. The answer decides the shape of a later grant-issuance step for audit.
3. Metrics count only events releasable to the export sink, so they undercount by design. This plan rules it that way. Is that acceptable to operators, or should a metric that any hidden event would affect be withheld entirely?
