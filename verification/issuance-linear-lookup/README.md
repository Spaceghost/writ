# Linear stored-approval lookup

Registration and every `current` revalidation look up each cited approval by
id. `find_stored` must return the one record under that id, or nothing when the
id is absent or held by two records, so list order never picks which record
answers. The previous form compared each record and then scanned the rest of
the list for a duplicate at every position. The JavaScript and native backends
evaluate eagerly, so that scan ran even after the answer was known: one lookup
did quadratic work in the length of the approval list.

`find_stored` now folds the list once into a `Matches` count (none, exactly one
record, or ambiguous) and returns the record only for exactly one. The answer
is the same for every list: with a matching head, both forms return it only
when no later record holds the id, and with a non-matching head both return the
answer for the tail. No security law, gate order or denial reason changed, and
`approval_exists` is unchanged for its other caller, `valid`.

## Checks

- Six new direct lookup checks in `IssuanceTests.bend`
  ([output](lookup-checks.txt)): an empty list, an absent id, a unique id at
  the first and last position, an id held by the first and a later record, an
  id held by two later records, and a unique id beside another id's duplicate.
- Mutants: keeping the [first](mutant-first-match-wins.diff) or the
  [last](mutant-last-match-wins.diff) of two matches instead of reporting
  ambiguity fails the new lookup group run alone (a scratch copy of
  `IssuanceTests.bend` whose `main` calls only `lookup()`, run with `bend`;
  [first](mutant-first-match-wins-lookup.txt),
  [last](mutant-last-match-wins-lookup.txt)) and the existing check
  "GI-003 an approval id stored twice ... denied MissingApproval" in the full
  Issuance group ([first](mutant-first-match-wins-issuance.txt),
  [last](mutant-last-match-wins-issuance.txt)).
- `bend Tests.bend`: [the output](suite-diff-against-master.txt) differs from
  master `49237593` only by the six new lines and the Issuance summary;
  `check_core.py` verifies the reviewed count of 3226 (3220 + 6), as shown in
  the [suite tail](suite-tail.txt).
- `bend PROOF.bend` and the Lean-built BendTT [verdict](verdict.txt) report
  `ALL PROOFS CHECK` (kernel SHA-256
  `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`). No law
  mentions the lookup; the verdict does not prove it.
- The native CPU suite (`clang -std=c11 -O0`, `+RTS --threads 4 --gpu off`)
  output was [byte-identical](native.txt) to the Bend run on the earlier base
  `414f91a6` (rebasing onto `49237593` changed no lookup code). No GPU test is
  claimed.

## Time

On the host QuickJS replica of the Genode prelude (QuickJS 2026-06-04, no JIT,
the interpreter class Genode runs), two back-to-back pairs on a loaded
32-core machine took 19.4 s and 37.5 s on master against 12.8 s and 24.2 s
with this change, about 34% less in each pair. Host Node with its JIT changed
little (about 6.5 s either way). This is not a Genode run, and load varied
between pairs, so only the paired ratio is meaningful.
