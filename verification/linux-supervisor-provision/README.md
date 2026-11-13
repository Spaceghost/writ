# Supervisor provisioning from a protected record

Example: the operator writes a 168-byte provisioning record to a file only the
supervisor's user can change (mode `0600`, one link). The record names the
issuer root (live stamp 1/2/3, five directory authorities, four placements)
and two channel roles: role 1 is principal 101 and role 2 is principal 102.
The native driver resolves the file beneath its directory without following
any symlink and sends
`LINUXSUP1 PROVISION 33152 1 1000 1000 01000000…` (`st_mode`, `st_nlink`,
`st_uid`, the supervisor's effective user ID, then the bytes) to the
interpreter. The interpreter replies `PROVISIONED`. From then on a revoke from
role 1's process is attributed to 101 and applies, and one from role 2's
process is refused. The same record in a group-writable file, under a second
hard link, as a FIFO, or with a different live stamp is refused. The driver
then stops: it sends nothing further, kills the interpreter and launches no
worker. A symlink to the record, a path through a symlinked directory, and a
path that leaves the directory are never resolved.

Through the driver's API, workers are registered only as it launches them,
and only after `PROVISIONED`. Worker 1 is started with `clone3`
(`CLONE_PIDFD`) and `execve`. Every signal is blocked across `clone3`, so
none of the supervisor's handlers can run in the child. The child then gets
default signal dispositions, parent-death `SIGKILL`, an empty mask and only
descriptors 0 to 2. The driver owns its pidfd, and that pidfd is what the
later drain kills.

Current gap: the record installs the **role-index-to-principal map** and must
match the issuer root, but the issuer that runs is still the **synthetic canary
issuer**. Its approvals were made by trusted in-process construction, not
submitted through the channel. The root match is a consistency check, not
authority: the canary root is public, so anyone can build a matching record,
and the file facts are the only gate. File ownership and mode are local facts.
They do not authenticate the operator who wrote the record, and any process
running as the supervisor's user can rewrite it. Which process holds which
role index is still registered by the caller (`writ_roles_add`). Clock samples
are still scripted.

## What changed

| Part | Source | Responsibility |
| --- | --- | --- |
| Provisioning policy | [`SupervisorProvision.bend`](../../hosts/linux/monitor/SupervisorProvision.bend) | Checks the file facts, decodes the record and checks it for consistency, then adopts it only when its issuer root is exactly the retained issuer's root. Only after that is the role map the owner's |
| Wire | [`SupervisorWire.bend`](../../hosts/linux/monitor/SupervisorWire.bend) | An interpreter started with `unprovisioned` has no role map. Its first frame must be `PROVISION`. A refusal replies `PROVISION_REFUSED`, requires containment and stops the interpreter. Any other first frame, and any second `PROVISION`, is `ERROR` |
| Test module | [`SupervisorDriverModule.bend`](../../hosts/linux/monitor/SupervisorDriverModule.bend) | `initial()` holds the synthetic canary issuer and no role map |
| Native driver | [`supervisor_owner.c`](../../contrib/native-hosts/linux/supervisor_owner.c), [`.h`](../../contrib/native-hosts/linux/supervisor_owner.h) | `writ_supervisor_provision` forwards facts and bytes. `writ_supervisor_launch_worker` starts and registers a worker after `PROVISIONED`, and refuses with `EPERM` before that or after a fail-stop. `writ_supervisor_release` closes the pidfds the driver owns. `writ_supervisor_add_worker` now exists only in the test build. The struct's fields stay public, so "only by launch" holds for the API, not against code that writes the struct |
| Tests | [`SupervisorProvisionTests.bend`](../../hosts/linux/monitor/SupervisorProvisionTests.bend), [`supervisor-owner-test.c`](../../contrib/native-hosts/linux/supervisor-owner-test.c), [`supervisor-owner-fake.mjs`](../../contrib/native-hosts/linux/supervisor-owner-fake.mjs) | Bend checks over the canary root. The native test writes its records to a private directory under `$TMPDIR`. The malformed peer answers `PROVISION` with `PROVISIONED` so that its other replies are still reached |

The driver still decides nothing. It does not compare the file's owner with
its own user, inspect the mode, or parse the record. It only does three things
for resource safety:

- it resolves the name with `openat2` as `O_PATH`, with `RESOLVE_NO_SYMLINKS`,
  `RESOLVE_NO_MAGICLINKS` and `RESOLVE_BENEATH`. A symlink anywhere in the path
  is refused with `ELOOP`, and a path out of the directory with `EXDEV`. The
  `O_PATH` descriptor opens nothing for I/O, so a FIFO, device or terminal is
  never opened;
- it takes the facts from that descriptor, and reopens and reads only a regular
  file, through `/proc/self/fd`, so it reads the same inode;
- it refuses a file larger than the 4096-byte record bound (`EFBIG`) before
  sending anything.

Each of these, and any reply other than `PROVISIONED`, is fail-stop.

### Record layout and checks

The record uses little-endian U32 words, in this order:

1. the version (1);
2. the live stamp (three words);
3. the roles, as a count and then (index, principal) pairs;
4. the authorities, as a count and then (kind, principal, domain) triples;
5. the placements, as a count and then (kind, object, version, domain)
   quadruples.

Nothing may follow, and the whole record is at most 4096 bytes. Bend refuses,
in this order:

1. a file that is not regular, has more than one link, is owned by another
   user, or is group- or other-writable;
2. a record that is oversized, has a byte above 255, is misaligned, has the
   wrong version, is truncated or has trailing words, uses an unknown kind, or
   names a zero principal;
3. a role map that is invalid (a zero or duplicate index) or empty, or a role
   whose principal holds no authority in the record's own directory;
4. ambiguous placements;
5. a record whose live stamp, directory or placements (in order) differ from
   the retained issuer's root. A state without a joint issuer is refused as
   well.

## What ran

| Run | Result |
| --- | --- |
| [`SupervisorProvisionTests.bend`](../../hosts/linux/monitor/SupervisorProvisionTests.bend) | [8 checks](provision-checks.txt) |
| [`SupervisorWireTests.bend`](../../hosts/linux/monitor/SupervisorWireTests.bend) | [8 checks](wire-checks.txt), unchanged |
| Native driver test (gcc, Makefile flags with `-Werror`) | [41 cases](native-run.txt), exit 0; [20 repeats](native-repeat.txt) all pass |
| clang build with `-Werror` | builds |
| [Mutants](mutant-results.txt) ([diffs and outputs](mutants/)) | all 23 Bend mutants fail; 19 of 21 C mutants fail, and the two survivors are listed below |
| `bend Tests.bend` | [differs from `ddc51b99`](suite-diff-against-master.txt) only by the nine new lines; `check_core.py` verifies 3258 (3250 + 8), see the [suite tail](suite-tail.txt) |
| Native CPU suite (`clang -std=c11 -O0`, `+RTS --threads 4 --gpu off`) | [byte-identical](native.txt) to the Bend run; no GPU test is claimed |
| `bend PROOF.bend`, and `--verdict` with the Lean-built BendTT | [`ALL PROOFS CHECK`](verdict.txt); no law mentions provisioning |

The [commands](commands.txt) and the [environment](environment.txt) are
recorded. The receiver needs `SO_PASSRIGHTS`, so Linux 6.16 or newer; the test
exits 77 on older kernels. This test is not part of any CI lane.

## Cases

The new native cases:

| Case | Observed |
| --- | --- |
| `protected_record_provisioned` | the `0600` canary record: `PROVISIONED`, sequence 1, no containment; every later case in that scenario runs on its role map |
| `group_writable_record_refused` | a `0620` record: `PROVISION_REFUSED`, fail-stop, interpreter killed, no worker launchable (`EPERM`) |
| `linked_record_refused` | the record under a second hard link: refused the same way |
| `fifo_record_refused` | a FIFO whose write side the test holds open: not opened for reading (a read would fail with `EAGAIN`), facts forwarded, refused |
| `foreign_root_record_refused` | a record whose live stamp differs from the issuer's: refused. Different directories and placements are refused in Bend only |
| `symlink_record_not_followed` | a symlink to the canary record: `ELOOP`, nothing sent, fail-stop |
| `intermediate_symlink_not_followed` | the canary record through a symlinked directory: `ELOOP`, nothing sent |
| `record_outside_directory_refused` | the canary record named through `..`: `EXDEV`, nothing sent |
| `oversized_record_not_sent` | a 4097-byte file: `EFBIG`, nothing sent, fail-stop |
| `control_before_provision_fail_stop` | unprovisioned: launching is refused (`EPERM`); a revoke before `PROVISION` gets `ERROR` from the interpreter, and the driver fail-stops |
| `second_provision_fail_stop` | a second `PROVISION`: `ERROR`, fail-stop |
| `frame_provision_exact` | exact frames; a link count beyond 32 bits saturates; 4097 bytes are refused and 4096 framed |
| `launch_registers_worker` | after `PROVISIONED`, launching worker 4 registers its pidfd as owned by the driver; worker 0 and a duplicate are refused (`EINVAL`) and the registry is unchanged |
| `launched_worker_clean` | the re-executed worker has parent-death `SIGKILL` and only descriptors 0 to 2, although the test holds one without close-on-exec. `SIGPIPE` is at its default although the test ignores it, and the mask is empty although the test blocks `SIGUSR2` |
| `launch_exec_failure_visible` | `execve` of a missing program: the child exits 127 |

The native refusals observe only `PROVISION_REFUSED`, because the wire carries
no reason; which check refused is shown by the Bend checks. The earlier driver
cases all still pass, now after provisioning and with a launched worker 1:
- `idle_channel_not_forwarded` now expects sequence 7, because `PROVISION` is
  the first frame;
- `unregistered_worker_fail_stop` now renumbers the registered worker instead
  of emptying the registry;
- `interpreter_loss_fail_stop` also checks that no worker can be launched
  after the fail-stop.

The Bend checks cover:

- the canary record, which installs roles 1 → 101 and 2 → 102 over exactly the
  canary issuer root, and whose encoding is the hex the C test writes;
- each file fault, refused before decoding;
- the byte and word faults;
- the consistency faults;
- adoption, which a different live stamp, directory or placement list refuses,
  as does a state without an issuer;
- the provisioned wire sequence `PROVISIONED`, `REVOKE_REFUSED`,
  `REVOKE_APPLIED`, `DRAIN_STEP S1`, `DRAIN_COMPLETE`;
- the wire refusals.

Every process, socket, file and descriptor in the native test is created by
the test. It requests no privilege, signals only its own children, mounts
nothing, probes nothing host-wide and starts no VM. Its record directory is
removed at exit, including after a failure.

Mutant notes:
- `euid-is-owner` survives. It sends the file's owner in place of the
  supervisor's effective user ID, which an unprivileged test cannot tell
  apart, because it can only create files it owns. The foreign-owner refusal
  is checked in Bend.
- `signals-unblocked-across-clone` survives. Blocking signals across `clone3`
  closes a race window between `clone3` and the reset of dispositions in the
  child, and no deterministic test can land a signal in that window, so it is
  reviewed only.

## Not established

- **Operator authentication:** owner, mode and link count are local facts.
  A process running as the supervisor's user can rewrite the record, and
  nothing proves which person wrote it. The foreign-owner refusal is checked
  in Bend only.
- **Issuer installation:** the record must equal the retained issuer's live
  stamp, directory and placements, but the
  approvals and grants the issuer holds are the synthetic canary's. Approval
  submission through the channel is the next step.
- **Role and session binding:** the channel's role processes are still
  registered by the caller (`writ_roles_add`), not launched by the driver, and
  no worker lifetime or session is bound to a principal (LH-011).
- **Roles sharing a principal:** two role indices may name the same
  principal. The profile allows one person to hold both roles when both were
  deliberately provisioned.
- **Clock and restart:** no host time base, and no continuity across a restart.
  A restarted supervisor would provision again from the file. Launched workers
  die with the launching thread (parent-death `SIGKILL`), but nothing reconciles
  their state after a restart.
- **Qualification:** no host qualification.

These remain reviewed-only gaps under LH-011 to LH-017.
