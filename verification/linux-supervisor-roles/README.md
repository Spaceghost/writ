# Driver-launched supervisor channel roles

Example: after `PROVISIONED` (roles 1 -> 101 and 2 -> 102 in the protected
record), the driver calls `writ_supervisor_launch_role(s, 1, channel, input,
...)`. It sends `LINUXSUP1 ROLE 1 0 0 0 -`; Bend finds index 1 in the
installed role map and not yet bound, and replies `ROLE_ADMITTED` with no
containment. Only then does the driver start the program with clone3. The
child gets `input` as descriptor 0 and its channel end as descriptor 3, keeps
1 and 2, and has nothing else. The driver registers the child's pidfs
identity under index 1 in its own role table, and the receiver uses that
table to attribute datagrams. A second launch for index 1, or a launch for 0
or for the unmapped index 3, gets `ROLE_REFUSED` and starts nothing.
`writ_supervisor_serve_one` no longer takes a caller's table.

Current gap: the supervisor now starts every role process and binds its exact
lifetime to the index, but **which program** it starts is still the caller's
argument (`path`, `argv`, `envp`), not part of the protected record. The role
map itself comes from file facts, which do not authenticate the operator.
LH-011's trusted-program binding and an authenticated administrator are
therefore still open. An admitted index stays bound for the interpreter's
lifetime, so a role whose process exits cannot be relaunched without a
restart, and there is no restart continuity. The issuer is still the
synthetic canary, and clock samples are scripted.

## What changed

| Part | Source | Responsibility |
| --- | --- | --- |
| Role admission | [`SupervisorRoleLaunch.bend`](../../hosts/linux/monitor/SupervisorRoleLaunch.bend) | `admit(roles, bound, index)`: `RoleAdmitted` with the index added to the bound set exactly when `C.attribute` names a principal for it under the provisioned map (so zero, unmapped and invalid-map indices are refused) and it is not already bound; `RoleRefused` otherwise |
| Wire | [`SupervisorWire.bend`](../../hosts/linux/monitor/SupervisorWire.bend) | `ROLE <index> 0 0 0 -`, only after `PROVISION`. Replies `ROLE_ADMITTED` or `ROLE_REFUSED`, never requires containment, takes no clock sample and leaves the owner unchanged. The interpreter state retains the bound set. Any other field value is `ERROR` and stops the interpreter |
| Native driver | [`supervisor_owner.c`](../../contrib/native-hosts/linux/supervisor_owner.c), [`.h`](../../contrib/native-hosts/linux/supervisor_owner.h) | `writ_supervisor_launch_role` sends the ROLE frame and launches only on `ROLE_ADMITTED`. The launch reuses the worker path (every signal blocked across clone3; in the child default dispositions, parent-death `SIGKILL`, empty mask). The descriptors are moved above 3 with `F_DUPFD` before `dup2` to 0 and 3, then `close_range(4, ~0)`. The pidfd is registered with `writ_roles_add` in the supervisor's own table and owned until `writ_supervisor_release`. A close-on-exec status pipe reports whether `execve` succeeded, so success means the program is running. `ROLE_REFUSED` returns `EPERM` without fail-stop. Any other reply, a reply with an effect or requiring containment, or after admission a clone3 failure, a child that fails before or in `execve` (reaped, its errno returned) or a registration failure is fail-stop. `writ_supervisor_serve_one(s, fd, reply)` attributes through that table |
| Tests | [`SupervisorRoleLaunchTests.bend`](../../hosts/linux/monitor/SupervisorRoleLaunchTests.bend), [`supervisor-owner-test.c`](../../contrib/native-hosts/linux/supervisor-owner-test.c), [`supervisor-owner-fake.mjs`](../../contrib/native-hosts/linux/supervisor-owner-fake.mjs) | Bend admission and wire checks. In the native test, roles 1 and 2 are now this binary re-executed with `--role` by the driver, and the third sender is a process the test starts itself. The malformed peer answers ROLE with `ROLE_ADMITTED`, except `SERVED` for index 7 and an `S1` effect for index 8 |

The driver decides nothing about roles. It does not compare the index with
the map, does not track which indices are bound, and does not choose whether
to launch: it launches exactly when Bend replies `ROLE_ADMITTED`. Its own
refusals before sending are resource and state facts: not provisioned or
failed (`EPERM`), a negative descriptor (`EBADF`), and a full table
(`ENOSPC`, eight roles). After admission, a failed launch is fail-stop,
because Bend would otherwise count an index as bound that no process holds.

A contained owner still admits a role launch. Revocation stays available
after containment, and a role process is how an issuer revokes. Admission
does not change the owner.

## What ran

| Run | Result |
| --- | --- |
| [`SupervisorRoleLaunchTests.bend`](../../hosts/linux/monitor/SupervisorRoleLaunchTests.bend) | [7 checks](role-checks.txt) |
| `SupervisorApprovalTests`, `SupervisorOwnerTests`, `SupervisorWireTests`, `SupervisorProvisionTests` | 11, 16, 8 and 8 checks, unchanged |
| Native driver test (gcc, Makefile flags with `-Werror`) | [54 cases](native-run.txt), exit 0; [20 repeats](native-repeat.txt) |
| clang build with `-Werror` | builds and passes |
| [Mutants](mutant-results.txt) ([diffs and outputs](mutants/)) | all 8 Bend and all 12 C mutants fail |
| `bend Tests.bend` | [differs from `e998f161`](suite-diff-against-master.txt) by the seven new checks and their summary line only; `check_core.py` verifies 3276 (3269 + 7), see the [suite tail](suite-tail.txt) |
| Native CPU suite (`clang -std=c11 -O0`, `+RTS --threads 4 --gpu off`) | [byte-identical](native.txt) to the Bend run; no GPU test is claimed |
| Full suite as JavaScript under QuickJS 2026-06-04 with the Genode corpus's 512 KiB stack | [passes in 23 s](quickjs-run.txt); the new checks use only short lists |
| `bend PROOF.bend`, and `--verdict` with the Lean-built BendTT | [`ALL PROOFS CHECK`](verdict.txt); no law mentions role launch |

The [commands](commands.txt) and the [environment](environment.txt) are
recorded. The first native CPU generation stopped at the backend's
continuation arity limit (247) in `malformed_stops`, which is now split into
one-case helpers like the wire tests'. The receiver needs `SO_PASSRIGHTS`, so Linux 6.16 or newer; the test
exits 77 on older kernels. This test is not part of any CI lane.

## Cases

New native cases:

| Case | Observed |
| --- | --- |
| `launched_roles_clean` | roles 1 and 2, launched after `ROLE_ADMITTED`, are in the driver's table under their indices with the driver's pidfds; each role process reports parent-death `SIGKILL`, exactly descriptors 0 to 3, and sockets at 0 and 3 (an inheritable test descriptor is closed) |
| `role_launch_refused` | second launches of 1 and 2, the unmapped 3 and 0: `ROLE_REFUSED`, `EPERM`, one reply each, nothing started (no other holder of the command socket), not fail-stop |
| `role_launch_bad_descriptor` | a negative channel descriptor: `EBADF`, nothing sent or started |
| `test_spawned_sender_denied` | a process the test started itself on the same channel: `CHANNEL_DENIED` |
| `peer_role_wrong_outcome` | `SERVED` for ROLE: fail-stop, interpreter killed, nothing started |
| `peer_role_effect` | `ROLE_ADMITTED` carrying `S1`: fail-stop, nothing started |
| `peer_role_contains` | `ROLE_ADMITTED` requiring containment: fail-stop, nothing started |
| `role_exec_failure_fail_stop` | role 5 admitted by the malformed peer, program missing: -1 with the child's `ENOENT`, child reaped, not registered, fail-stop |

Changed cases: `protected_record_provisioned` now expects sequence 3 (PROVISION
and two ROLE frames), `idle_channel_not_forwarded` 9 and
`second_provision_fail_stop` 4. `control_before_provision_fail_stop` and
`interpreter_loss_fail_stop` also require that a role launch is refused with
`EPERM`, with nothing sent and nothing started. The existing revoke, approval,
clock and drain cases now run against driver-launched role processes.

The Bend checks cover:

- each provisioned index admitted once and recorded;
- zero, unmapped, and empty-map or duplicate-map indices refused as
  unprovisioned;
- a bound index refused, whether it is first in the bound set or not;
- the exact LINUXSUP1 replies for ROLE 1, 2, 1, 3 and 0, followed by a revoke
  still attributed through the map;
- admission on a contained owner, with the drain unaffected;
- ROLE before PROVISION, and ROLE with any other field set, reply `ERROR` and
  stop the interpreter;
- after PROVISION, the installed map decides.

An independent review of the diff found no policy decision in C and the
descriptor shuffle correct for inputs equal to 0 to 3 or to each other. It
found that a child failing after admission (a missing program) was reported
as a launched role whose index could never be launched again; the status pipe
and `role_exec_failure_fail_stop` were added for that, and for its finding
that a containing ROLE reply was accepted, `peer_role_contains`. Release is
documented as end of life only. The role process checks that descriptors 0
and 3 are sockets, not which is which; the revoke and approval cases show 3 is
the channel and the `q` reply that 0 is the command socket.

Every process, socket and file in the native test is created by the test. It
requests no privilege, signals only its own children, mounts nothing, probes
nothing host-wide and starts no VM.

## Not established

- **Trusted program:** the program a role runs is the caller's argument, not
  part of the protected record; nothing checks what it is.
- **Operator authentication:** the role map comes from file facts, which do not
  authenticate the operator (LH-011).
- **Worker session binding:** no worker lifetime or session is bound to a
  principal.
- **Relaunch and restart:** an admitted index is never released, so an exited
  role cannot be relaunched in the same interpreter; nothing survives a
  restart.
- **Issuer, clock and id feedback:** the issuer is the synthetic canary, clock
  samples are scripted, and a submitting role is not told a new approval's id.
- **Qualification:** no host qualification.

These remain reviewed-only gaps under LH-011 to LH-017.
