# Task 1 re-review: fix round 1 (8dafe74)

Reviewer (task reviewer, security), 2026-11-05. Scope: `git diff 60dc1fe 8dafe74`
and the "Fix round 1" section of task-1-report.md, checked against
task-1-review.md. This is a scoped re-review, not a full review.

Result: **ALL CLOSED.** No new defect. Two cosmetic nits are listed at the
end; they are not blocking.

| Finding | Status | Evidence |
| --- | --- | --- |
| I1, Barrier not bound to its session | CLOSED | See I1 below. |
| I2, StaleLaunch never exercised across a restart | CLOSED | See I2 below. |
| I3, INVENTORY.md fact list and obligations | CLOSED | See I3 below. |
| Box 1.1 (controller ruling) | CLOSED | tasks.md:7 is `- [ ]`. Its parenthetical reads "Model half delivered: ...; the box is checked when Tasks 2 and 3 land the native pins." |
| m1, snapshot divergence and `Checked` | CLOSED | See m1 below. |
| m2, replayed Launch | CLOSED | See m2 below. |
| m3, the replay bypasses dispatch | CLOSED | The test header and a new LH-010 traceability row both state the boundary. |
| m4, check labels | CLOSED | The two Usage checks are now `PH-007 ...` and the Emission check is `LH-009 ...`. |
| m5, gid | CLOSED | `Credential{uid, gid, pid, start}`; `credential_equal` compares gid; new check `... another gid PeerMismatch` (the implementer's M03b kills it). |
| m6, `checked_as` | CLOSED | It now also requires `W.Ref.equal(P.entry_ref(identity, entry), input_ref())`. |

## Detail

**I1.**
- New adapter `Rejection` `SessionMismatch`. `session_check` uses
  `I.session_at` and requires exactly one session whose caller equals
  `F.Caller{fact.subject, fact.token}`. It is combined with `launch_check`
  through `first_of` on the Barrier path, adds no transition, and adds no
  contract `Error`.
- My original foreign-subject probe (subject 99, the client's token, a
  self-consistent uid/gid 2000 / pid 5555 credential), rewritten on my own
  scratch copy for the new `Credential` arity: now Untranslated
  SessionMismatch, state equal to the input, no effect.
- Four new named checks cover another subject, another token, the client
  session, and unknown session 9.
- My mutant M32 (remove `session_check`) and M33 (`session_caller_is`
  ignores the caller) are both KILLED.
- Still as designed and documented (header and INVENTORY obligation 3): a
  Barrier with a transferred endpoint admits, because the endpoint is fixed
  at Launch.

**I2.**
- `restarted()` runs `H.restart` to successor 7. The stale incarnation is now
  5, which matches no session, profile, or successor id.
- Three new checks: Launch after the restart is StaleLaunch, Launch with the
  successor opens a session, and Barrier after the restart is StaleLaunch.
- My X1 (`current_incarnation` returns `linux_incarnation()`) and X2 (returns
  `linux_worker_v1()`) are both KILLED by `LH-002 LH-008 after a restart a
  Launch carrying the previous incarnation's launch record is refused
  StaleLaunch ...`.

**I3.**
- The "Facts the broker reports" table covers every `LinuxFact` field plus
  `Barrier.session`, `Barrier.request`, `Usage`, `Emission`, and
  `FromWorker.session`.
- Rows marked Task 2, 3, or 4 cover the session generation, the Landlock
  rights / `no_new_privs` / privilege drop, and the resolved handle.
- Each row gives the contract destination (a transition, "compared only", or
  "dropped") and why the fact is not authority.
- The bold statement "None of the facts below is an authority fact" is
  present, followed by eight broker obligations, including attribution, the
  barrier credential, a single snapshot, nothing on `Checked`, and one Launch
  per generation.

**m1.** The header now says the snapshot is the only request admission
reads, and that a divergence admits at most an entry the session already
holds. It also says `Checked` authorizes no broker action in section 1.

**m2.** The header says a repeated Launch opens another session and the
broker issues one Launch per launch-record generation (Task 2). The same rule
is broker obligation 6.

**Effect rule unchanged.** The only `admit_worker` call is still on the
Barrier arm (LinuxHost.bend:462). Non-comment lines construct no `Admitted`,
`DeliverInputs`, `Step`, or publish value.

## Runs

| Check | Result |
| --- | --- |
| `bend Tests.bend` (JS) | exit 0, 1519 PASS, 0 FAIL, `LinuxHost: 91 checks passed`, `ALL LIBRARY TESTS PASSED`; no prior PASS line missing, none duplicated |
| Linux vector replay | `grep '^LINUX VECTOR ' \| cut -c7-` is cmp-identical to `verification/portable-host-vectors.txt` (on-disk SHA-256 `37816dd7d768c21e730f780cbc98b66cadbba087c972d18e731b670219caf24f`) |
| `VECTOR PH-` / `VECTOR GA-` captures | still identical to their files |
| `bend PROOF.bend` | `ALL PROOFS CHECK`, identical to `verification/proofs.txt` |
| LAWS/PROOF | `git diff master -- LAWS.bend PROOF.bend` is empty |
| OpenSpec 1.16.0 strict | 44 passed, 0 failed |
| Mutants (my scratch copy) | M32, M33, X1, X2 killed; baseline 91/91 |
| Not run | the native backend (the report also did not rebuild it this round; its last native run is 1511) and `--verdict` (no Lean) |

Files changed in 8dafe74 are the touch list plus records. Note that 8dafe74
also committed task-1-review.md, which the review had left uncommitted.

## Nits (optional, not blocking)

- `openspec/traceability/linux-host.md:18` still describes the fixture
  credential as "uid 1000, pid 4242, start 917". It should add gid 1000.
- `LinuxHostTests.bend` `restart_ok` uses `I.first_slot()` as a session id.
  The value is right (1), but the name is wrong. A literal `1n` with a comment
  would be clearer.
