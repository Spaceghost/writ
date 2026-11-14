# Supervisor approval submission through the channel

Example: after `PROVISIONED`, the process registered as role 1 (principal 101,
the read authority for domain 5 in the record) sends one 128-byte datagram on
the supervisor channel: a `LINUXSUP` control payload, tag 2, holding a
source-read approval for source 10v4 in read domain 5, serial 900, valid until
200. The receiver reports the sender's role; the driver forwards the
datagram unchanged. Bend attributes it to principal 101 and submits it through
`Iss.submit_source` as 101. The issuer accepts it as approval 16 and the reply
is `APPROVAL_ACCEPTED` with no containment. The same bytes from role 2
(principal 102) are `APPROVAL_REFUSED`, because the record's issuer field
claims 101 and the issuer checks that claim against the attributed principal.
Role 2's own destination-write approval for write domain 6 is accepted. When
role 1 then revokes approval 16, the existing revoke path applies it and
requires containment.

Current gap: approvals now reach the issuer only as the channel role's
attributed principal, but the issuer they join is still the **synthetic canary
issuer**, with its earlier approvals and grants built in-process. The
submitting role does not learn the new approval's id: the channel is one-way,
and the reply goes to the driver, not to the role. Which process holds which
role is still registered by the caller (`writ_roles_add`), the record's role
map is not an authenticated operator, and the clock samples are scripted.
Registration of a grant from submitted approvals is not carried on the
channel.

## What changed

| Part | Source | Responsibility |
| --- | --- | --- |
| Approval body codec | [`SupervisorApproval.bend`](../../hosts/linux/monitor/SupervisorApproval.bend) | Turns body words into the fields of an `Iss.SourceApproval` or `Iss.WriteApproval` and back. Structure only: too few or too many words, or a manifest shorter than its count, is a length fault, and an unknown kind word is a kind fault |
| Control channel | [`SupervisorOwner.bend`](../../hosts/linux/monitor/SupervisorOwner.bend) | Tags 2 (`SubmitSource`) and 3 (`SubmitWrite`) beside tag 1 (`Revoke`); the payload bound is now 1024 bytes. A decoded approval is submitted as the attributed principal. `ApprovalAccepted` and `ApprovalRefused` require no containment. On a poisoned, stale, failed or contained owner nothing is submitted and the outcome is `Contained` |
| Joint owner | [`LinuxHost.bend`](../../hosts/linux/monitor/LinuxHost.bend) | `joint_submit` calls `Iss.submit_source` / `Iss.submit_write` at the issuer's current revision and the sampled time, retains the new issuer and leaves every other joint component, including the phase, unchanged. It submits only on an active owner with a current retained clock and revision room |
| Wire | [`SupervisorWire.bend`](../../hosts/linux/monitor/SupervisorWire.bend) | Outcomes `APPROVAL_ACCEPTED` and `APPROVAL_REFUSED` |
| Native driver | [`supervisor_owner.c`](../../contrib/native-hosts/linux/supervisor_owner.c), [`.h`](../../contrib/native-hosts/linux/supervisor_owner.h) | Accepts the two outcomes as control replies. It parses no payload and decides nothing |
| Tests | [`SupervisorApprovalTests.bend`](../../hosts/linux/monitor/SupervisorApprovalTests.bend), [`supervisor-owner-test.c`](../../contrib/native-hosts/linux/supervisor-owner-test.c) | Bend checks over the joint owner's running stage; the native test sends the same bytes from owned processes |

Every authority decision is the existing Issuance one: the issuer claim must
be the attributed principal (`Unauthenticated`), the directory must name that
principal as the authority for the claimed domain (`NotAuthority`), the object
must be placed in that domain (`WrongDomain`), and the scope, rights, lifetime
and serial must hold. The new code adds no rule. The approval's `issuer` field
is a claim; the principal always comes from the receiver's sender fact and the
provisioned role map.

Submission is not cleanup. Revocation stays available on a contained owner
because it only restricts; submission stores new approval material, so on a
poisoned, stale, expired or contained owner it is not attempted.

### Body layout

Little-endian U32 words after the three header words (version 1, tag, body
length in words):

1. version, serial, issuer claim, object, object version, domain;
2. the scope: stamp graph, policy and authority, invocation, source count N
   and N (object, version) pairs, destination object and version, eight code
   words, kind (1 Copy, 2 Transform, 3 Summarize), output type, write domain,
   subject;
3. rights, valid until.

For a source approval the object is the source and the domain a read domain;
for a write approval the destination and a write domain. A one-source body is
29 words; the 1024-byte bound leaves room for 113 sources.

## What ran

| Run | Result |
| --- | --- |
| [`SupervisorApprovalTests.bend`](../../hosts/linux/monitor/SupervisorApprovalTests.bend) | [11 checks](approval-checks.txt) |
| [`SupervisorOwnerTests.bend`](../../hosts/linux/monitor/SupervisorOwnerTests.bend) | [16 checks](owner-checks.txt); the oversized case now uses 1028 bytes |
| [`SupervisorWireTests.bend`](../../hosts/linux/monitor/SupervisorWireTests.bend), [`SupervisorProvisionTests.bend`](../../hosts/linux/monitor/SupervisorProvisionTests.bend) | 8 and 8 checks, unchanged |
| Native driver test (gcc, Makefile flags with `-Werror`) | [46 cases](native-run.txt), exit 0; [20 repeats](native-repeat.txt) |
| clang build with `-Werror` | builds |
| [Mutants](mutant-results.txt) ([diffs and outputs](mutants/)) | 19 of 21 Bend mutants and both C mutants fail; the two Bend survivors are listed below |
| `bend Tests.bend` | [differs from `51f76edb`](suite-diff-against-master.txt) only by the twelve new lines; `check_core.py` verifies 3269 (3258 + 11), see the [suite tail](suite-tail.txt) |
| Native CPU suite (`clang -std=c11 -O0`, `+RTS --threads 4 --gpu off`) | [byte-identical](native.txt) to the Bend run; no GPU test is claimed |
| `bend PROOF.bend`, and `--verdict` with the Lean-built BendTT | [`ALL PROOFS CHECK`](verdict.txt); no law mentions approval submission on the channel |

The [commands](commands.txt) and the [environment](environment.txt) are
recorded. The receiver needs `SO_PASSRIGHTS`, so Linux 6.16 or newer; the test
exits 77 on older kernels. This test is not part of any CI lane.

## Cases

New native cases, in one provisioned scenario with worker 1 launched:

| Case | Observed |
| --- | --- |
| `source_role_submission_accepted` | role 1 (101) submits its read-domain-5 approval: `APPROVAL_ACCEPTED`, no containment, worker alive |
| `other_role_submission_refused` | role 2 (102) sends the same bytes: `APPROVAL_REFUSED`, no containment |
| `unregistered_submission_denied` | an unregistered process sends them: `CHANNEL_DENIED` |
| `write_role_submission_accepted` | role 2 submits its write-domain-6 approval: `APPROVAL_ACCEPTED` |
| `submitted_approval_revoked` | role 1 revokes approval 16: `REVOKE_APPLIED` with containment |

The Bend checks cover:

- the test writer's bytes equal the native test's, and decoding then encoding
  returns the same bytes for both kinds, a three-source Copy manifest and a
  Transform plan;
- short, long, miscounted and unknown-kind bodies, and the kind, length, tag
  and size faults at the control layer (1024 bytes reach decoding, 1025 are
  too long);
- each role's own approval accepted as id 16, with the issuer revision and next
  id advanced by one, the clock at the sample, the portable state unchanged and
  no containment;
- a role submitting another principal's approval, or claiming a read or write
  domain it does not control: refused, with only the clock moved;
- the lifetime judged at the sampled time: at sample 111 an approval valid
  until 111 is refused and one valid until 112 accepted;
- replays of a fixture serial and of a just-accepted serial: refused;
- approval 16 revocable by role 1, not by role 2;
- nothing submitted on an unavailable or regressing sample, after the grant's
  expiry, or after a revoke has contained the owner;
- `LinuxHost.joint_submit` called directly: an active owner whose retained
  clock is past the grant's expiry, and an issuer at the 2^48 - 1 revision
  bound, submit nothing and require containment;
- the LINUXSUP1 sequence `APPROVAL_ACCEPTED`, `APPROVAL_REFUSED`,
  `APPROVAL_ACCEPTED`, `REVOKE_APPLIED`.

Every process, socket and file in the native test is created by the test. It
requests no privilege, signals only its own children, mounts nothing, probes
nothing host-wide and starts no VM.

Mutant notes:
- `phase-unchecked` survives. It drops `active_phase` from `joint_submit`'s
  guard, but `retained_clock_current` already requires an active phase
  (through `joint_sample_current`), so the mutant is equivalent. The conjunct
  is kept to match `joint_revoke`.
- `submitted-when-contained` survives. It submits on the owner's containment
  path too, but there the state is already failed or poisoned, so
  `joint_submit`'s own guard contains it and nothing is stored. The owner-level
  refusal and the joint guard are two layers; tests show only that together
  they hold.
- `counter-unchecked` fails by aborting the run: without the revision bound,
  the terminal-revision check overflows a Bend Nat.

## Not established

- **Authenticated issuer:** the issuer is still the synthetic canary, and its
  earlier approvals and grants were built in-process.
- **Id feedback:** the submitting role is not told the accepted approval's id;
  revoking it needs that id from elsewhere (here, the fixture's known next id).
- **Submission volume:** a provisioned role can submit any number of distinct
  serials. Every step re-validates the issuer, and that validation is
  quadratic in the stored approvals, so a flood slows later revokes, frames
  and drains. There is no quota or pruning. Accepting without containment also
  rests on nothing here registering grants from stored approvals.
- **Refusal reasons:** the wire and `ApprovalRefused` carry no reason; the
  refusals in the tests follow from Issuance's gate order (`Unauthenticated`,
  `NotAuthority`, `Replay`, `Expired`), but no check pins which gate refused.
- **Registration over the channel:** a grant from submitted approvals is not
  requested through the channel.
- **Role and session binding:** role processes are still registered by the
  caller, and no worker lifetime or session is bound to a principal (LH-011).
- **Operator authentication:** the role map comes from file facts, which do not
  authenticate the operator.
- **Clock and restart:** samples are scripted; submitted approvals do not
  survive a restart.
- **Qualification:** no host qualification.

These remain reviewed-only gaps under LH-011 to LH-017.
