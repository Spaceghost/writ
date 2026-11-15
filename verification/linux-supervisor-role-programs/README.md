# Supervisor role programs pinned by the protected record

Example: the protected record (version 2) pins role 1 to the SHA-256 of
`/opt/writ/roles/source-approver`. The driver is asked to start role 1 with
`writ_supervisor_launch_role(s, 1, channel, input, dirfd, "source-approver",
...)`. It resolves the name beneath `dirfd` with `openat2` (no symlink, no
escape), takes `fstat`, copies the regular file into a memory file, seals it
against writes, shrinking, growth and further seals, and then hashes the
sealed bytes by reading the memory file back. It then
sends `LINUXSUP1 ROLE 1 0 0 0 <mode, links, owner, euid, digest>`. Bend
admits only a regular, singly linked file owned by root or the supervisor's
user, writable by no group or other user, whose digest equals role 1's pin.
The driver then executes exactly that sealed copy with
`execveat(memfd, "", AT_EMPTY_PATH)`; the path is never executed. A
group-writable or hard-linked copy of the same program, a different program, a
FIFO or a symlink is refused, and a refusal binds nothing.

Current gap: the record decides which program each role runs, but the record
itself is still accepted on file facts. Its writer is trusted, not
authenticated, and so the pins are only as good as that file's protection.
(Record version 3 is now signed by a pinned operator key; see the
[record signature record](../linux-supervisor-record-signature/README.md).)
A digest names bytes, not an author or a build. The program's own libraries
and interpreter (the dynamic loader, shared objects) are not pinned. An
admitted index stays bound for the interpreter's lifetime, the issuer is
still the synthetic canary, and clock samples are scripted. LH-011 therefore
remains a reviewed-only gap.

## What changed

| Part | Source | Responsibility |
| --- | --- | --- |
| Record | [`SupervisorProvision.bend`](../../hosts/linux/monitor/SupervisorProvision.bend) | Version 2 adds, after the placements, a program count and per program the role index and eight big-endian SHA-256 words. Consistency (`ProgramsInvalid`): every role has exactly one program and there are no others. Version 1 is refused (`RecordVersion`). The installed and adopted bootstrap carries the programs beside the role map |
| Admission | [`SupervisorRoleLaunch.bend`](../../hosts/linux/monitor/SupervisorRoleLaunch.bend) | `admit(roles, launches, facts, index)` checks, in order: the index is provisioned (`RoleUnprovisioned`), not yet bound (`RoleAlreadyBound`), the file is protected (`ProgramUnprotected`), and the digest is the pin (`ProgramMismatch`). Only an admission binds the index |
| Wire | [`SupervisorWire.bend`](../../hosts/linux/monitor/SupervisorWire.bend) | `ROLE <index> 0 0 0 <hex>`: the argument must be exactly twelve little-endian words (mode, links, owner, euid, digest) or the reply is `ERROR` and the interpreter stops. `PROVISION` installs the programs; an interpreter provisioned any other way launches nothing |
| Native driver | [`supervisor_owner.c`](../../contrib/native-hosts/linux/supervisor_owner.c), [`.h`](../../contrib/native-hosts/linux/supervisor_owner.h), [`sha256.c`](../../contrib/native-hosts/linux/sha256.c), [`.h`](../../contrib/native-hosts/linux/sha256.h) | Resolves and seals the program and reports its facts and digest; it compares nothing. An unresolvable, unreadable or oversized (over 64 MiB) program fails before anything is sent and is not fail-stop. On admission it executes the sealed copy. A reply admitting a file that is not regular, and every failure after admission, is fail-stop as before |
| Tests | [`SupervisorRoleLaunchTests.bend`](../../hosts/linux/monitor/SupervisorRoleLaunchTests.bend), [`SupervisorProvisionTests.bend`](../../hosts/linux/monitor/SupervisorProvisionTests.bend), [`supervisor-owner-test.c`](../../contrib/native-hosts/linux/supervisor-owner-test.c) | The SYNTHETIC canary pins role 1 to SHA-256("abc") and role 2 to SHA-256(""). The native test writes the same record with both pins replaced by the digest of a private copy of its own binary, which is the role program |

The driver decides nothing about programs. It does not know the pins, does
not compare digests and does not judge the file's mode, links or owner. The
memory file is sealed before it is hashed, and the digest is read back from
the sealed file, so the bytes Bend judged are the bytes executed, whatever
happens to the file on disk afterwards. A role program must be an ELF
executable: an interpreter script cannot run from a close-on-exec memory
file, so an admitted script fails in `execveat` (`ENOENT`), which is
fail-stop.

## What ran

| Run | Result |
| --- | --- |
| [`SupervisorRoleLaunchTests.bend`](../../hosts/linux/monitor/SupervisorRoleLaunchTests.bend) | [12 checks](role-checks.txt) |
| [`SupervisorProvisionTests.bend`](../../hosts/linux/monitor/SupervisorProvisionTests.bend) | [8 checks](provision-checks.txt), extended for the programs section |
| `SupervisorApprovalTests`, `SupervisorOwnerTests`, `SupervisorWireTests` | 11, 16 and 8 checks, unchanged |
| Native driver test (gcc, Makefile flags with `-Werror`) | [60 cases](native-run.txt), exit 0; [20 repeats](native-repeat.txt) |
| clang build with `-Werror` | builds and passes |
| [Mutants](mutant-results.txt) ([diffs and outputs](mutants/)) | 15 of 16 Bend and 9 of 10 C mutants fail; the survivors are below |
| `bend Tests.bend` | [differs from `b3bb2245`](suite-diff-against-master.txt) by the new and renamed checks only; `check_core.py` verifies 3281, see the [suite tail](suite-tail.txt) |
| Native CPU suite (`clang -std=c11 -O0`, `+RTS --threads 4 --gpu off`) | [byte-identical](native.txt) to the Bend run; no GPU test is claimed |
| Full suite as JavaScript under QuickJS 2026-06-04 with the Genode corpus's 512 KiB stack | [passes](quickjs-run.txt) |
| `bend PROOF.bend`, and `--verdict` with the Lean-built BendTT | [`ALL PROOFS CHECK`](verdict.txt); no law mentions role programs |

The [commands](commands.txt) and the [environment](environment.txt) are
recorded. The receiver needs `SO_PASSRIGHTS` (Linux 6.16 or newer) and the
driver `MFD_EXEC` memory files; the test exits 77 when the channel profile is
missing. This test is not part of any CI lane.

## Cases

New native cases:

| Case | Observed |
| --- | --- |
| `sha256_vectors` | the FIPS 180-4 digests of "abc", "", the 448-bit message and a million "a"; the canary constant's pins are the "abc" and "" digests |
| `frame_role_exact` | the ROLE frame for mode 0o100755, one link, owner and euid 1000 and the "abc" digest equals the Bend fixture `abc_hex()` |
| `role_program_refused` | role 1 with an unpinned program, a group-writable copy and a hard-linked copy of the pinned program, and a FIFO: `ROLE_REFUSED`, nothing started, not fail-stop, role 1 still free |
| `role_program_not_resolved` | a symlink to the pinned program (`ELOOP`) and a missing name (`ENOENT`): nothing sent or started |
| `role_pinned_program_admitted` | then the protected pinned copy: `ROLE_ADMITTED`, and the role process reports that it runs from `/memfd:writ-role` |
| `role_unregular_admitted_fail_stop` | the malformed peer admits a FIFO: nothing to execute, fail-stop, nothing left running |

Changed cases: `launched_roles_clean` now also requires each role process to
run from its memory file and to find all four seals on it (`F_GET_SEALS`
through `/proc/self/exe`). `role_exec_failure_fail_stop` now launches a
text file that the malformed peer admits; `execveat` fails with `ENOEXEC`.

The Bend checks cover:

- each role's pinned program admitted once, owned by the supervisor's user or
  by root, with or without group and other read and execute;
- a directory, a FIFO, a second link, a foreign owner, and group or other
  write: `ProgramUnprotected`, even with the pinned digest;
- another role's program, a digest differing in its first or last word, and
  any program when no programs were provisioned: `ProgramMismatch`;
- a refusal followed by the right program: admitted;
- the exact wire replies, and `ERROR` for a `-`, short, long or misaligned
  argument;
- records with no programs, a missing, duplicated, stray or extra program:
  `ProgramsInvalid`; a short program entry, a count beyond its entries and a
  trailing word: `RecordLength`; version 1 and 3: `RecordVersion`.

An independent review of the diff found no policy decision in C, and the
SHA-256, the digest byte order, the record parsing and the child's descriptor
handling correct. It found that the first version hashed the copy buffer while
the memory file was still writable, so a process of the same user reopening
the supervisor's memory file through `/proc` could have overwritten bytes
after they were hashed and before the seal. The digest is now read back from
the sealed file, and the seal check above and the `seal-skipped` mutant were
added. It also asked for the ELF-only limit and `vm.memfd_noexec` to be
documented, and noted that `role_unregular_admitted_fail_stop` cannot show
that no child was cloned, only that none is left running.

Every process, socket and file in the native test is created by the test,
including the copies of its binary in its private directory. It requests no
privilege, signals only its own children, mounts nothing, probes nothing
host-wide and starts no VM.

Mutant notes:

- `duplicates-allowed` survives. It accepts a role with more than one program
  entry, but requiring at least one entry per role and as many entries as roles
  leaves no room for a duplicate, so it is equivalent.
- `unregular-admitted` survives. Without the guard the child cannot duplicate
  the missing program descriptor and fails before executing anything, so the
  launch still fail-stops with nothing running. The guard avoids starting that
  child; `role_unregular_admitted_fail_stop` pins the outcome.
- `hash-partial` fails by aborting the run: role 1's launch is refused.

Not exercised: a program owned by root or by another user (the test cannot
create one without privilege; the Bend checks cover both), `vm.memfd_noexec`
set to 2, which forbids executable memory files (`memfd_create` fails with
`EACCES` before anything is sent, so no role can be launched on such a host),
an interpreter script, a program over 64 MiB, and a race against the copy
before sealing.

## Not established

- **Record authenticity:** the pins come from a file accepted on local facts;
  whoever can write that file chooses every role's program.
- **Program provenance:** a digest names bytes, not who built them; shared
  libraries and the dynamic loader are not pinned.
- **Operator authentication and worker session binding** (LH-011).
- **Relaunch and restart:** an exited role cannot be relaunched in the same
  interpreter, and nothing survives a restart.
- **Issuer, clock and id feedback:** the issuer is the synthetic canary, clock
  samples are scripted, and a submitting role is not told a new approval's id.
- **Qualification:** no host qualification.

These remain reviewed-only gaps under LH-011 to LH-017.
