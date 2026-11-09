# WIP: synthetic Rendezvous owner (not qualified for merge)

**Historical WIP at commit 503c3b8.** That boxed candidate passed 42 focused
checks on Bend and generated Node, but its native focused C generation failed
with `arity over 247`. Its full-tree native generator separately aborted under
an 8 GiB virtual-memory limit; that abort is not an arity verdict and produced no full
native result. Its delivery, containment and authority behavior remained
unqualified. The user-facing host is not changed by this WIP branch.

The exact failing [actual issue probe](actual-issue-probe.bend.txt) and
[output](actual-issue-native-failure.txt) use the source at that commit. A separate
self-guarding single-stage issue experiment also fails: see its
[patch](issue-attempt.patch.base64), [probe](issue-attempt-probe.bend.txt), and
[output](issue-attempt-native-failure.txt). That experimental patch is evidence,
not part of the candidate. The independently reviewed self-guarding dispatch
attempt generated C in isolation; no inference about the full issue path follows.
The historical [boxed focused Bend](boxed-focused-bend.txt) and
[Node](boxed-focused-node.txt) outputs match. The [focused native failure](boxed-focused-native-failure.txt)
and [full generator abort](boxed-full-native-abort.txt) are preserved.


A synthetic issuer, selected Rendezvous and Running Negotiation session are
retained with LinuxHost's state. A newly launched worker is actually dispatched;
the selected provider's current registry opens the Frontend descriptor and
`P.issue_result` returns the exact recorded root slot. Each Barrier checks the
retained selection, exact provider grant and root lineage, worker session and
incarnation, current reader authority, broker facts and shared admission before
`DeliverInputs`. The standalone Linux model retains its existing trusted
snapshot interface; no worker frame selects or changes the retained mode.

Any accepted issuer revocation, invalid or expired current state, clock failure
or direct R-mode retirement requires sticky whole-instance containment. The
issuer update is retained first. After the host contains the instance, trusted
drain calls return each actual shared `StopEffects` once and retain their
history. Incomplete drain and restart cannot reopen the instance. This is a
required external host obligation; this model neither performs nor proves
native containment. R-mode diagnostic replies redact subject/session details;
a line-only LINUXMON1 consumer cannot carry the typed effects or obligations.

The selected provider grant is exact. Reader projections are rebuilt for the
reader subject and can be satisfied by another current same-scope grant; they
do not prove continuity of the original reader grant. The model does not
revalidate a committed ledger, budget, sample/evidence expiration or original
graph, and does not perform a Copy. Inputs are synthetic trusted in-process
records; there is no authenticated live issuer feed, trusted native clock,
continuous expiry timer, durable recovery or exclusive real-host profile.
The separate native Mount dispatcher is not mediated here. A real host must
prevent access to generic and Mount bypasses and prove the whole profile before
claiming enforcement. Shared ancestry now stops fixed-point walks, but neither
all traversal nor cleanup is proven bounded in resources or time.

Before the later boxing changes, [focused checks](focused-bend.txt) covered exact issue lineage, selected
worker dispatch, valid delivery, stale or missing reader authority, different
same-scope reader grant, direct helper guards, generic snapshot substitution,
clock poison and deadline, metadata redaction, issuer revocations, multi-root
stop history, terminal counters and partial cleanup. [Generated Node](focused-node.txt)
matched. The earlier [full Bend](tests-bend.txt) and [generated Node](tests-node.txt) output
matched, with 2,975 `PASS:` lines and 53 other `PASS` lines.

On the same pre-box tree, [ordinary proof](proof.txt), [pinned Lean verdict](verdict.txt), the expected
[false-kernel negative](negative.txt), and [OpenSpec 1.16.0 strict](openspec.txt)
completed. The two existing nonprivileged native [handoff](handoff-mock.txt)
and [retirement](retire-mock.txt) mocks passed; they do not mount FUSE or
probe native identity. The [healthy shared-revoke control](healthy-revoke-trap.bend.txt)
traps at terminal Nat capacity on [Bend](healthy-trap-bend.txt) and
[Node](healthy-trap-node.txt), while guarded terminal cases deny or require
containment. A first whole-Step control exhausted its bounded process and is
preserved as [source](trap-full-step.bend.txt), [log](trap-bend-full-step.log)
and [status](trap-bend-full-step-status.txt); it did not establish the intended
overflow. The earlier [exploratory full run](preliminary-full-bend.log) overlaps
source edits and is explicitly [not final evidence](preliminary-full-status.txt).

The [pre-box Bend input hashes](pre-box-bend-input-sha256.txt) identify the earlier source,
not the current candidate. The repository source manifest identifies the currently delivered
tree; [commands and limits](commands.txt) distinguish the experimental runs. No GPU, VM,
identity probe, FUSE mount, protected-host acceptance or recovery claim is made.

The readable Bun abort logs have trailing whitespace normalized; the exact
original bytes are preserved in the adjacent `.base64` files. The experimental
unified diff is base64-encoded so its required blank context lines remain exact.

A later [staged continuation refactor](../linux-joint-owner-staged/README.md) records new checks; this historical record remains unchanged as evidence of the earlier failures.
