# Candidate invocation boundary: PID namespace, design only

A synthetic test process forks a child that calls `setsid` and waits. The test
supervisor must retire both without signaling a neighboring process or an
unrelated VM. A process-group kill cannot cover that child safely. Observed
writability of the current user's parent `cgroup.procs` does not rule out
migration; it was not attempted and has other prerequisites. No real
supervisor, namespace lifecycle test or Genode run is implemented here.

## Source-backed possibility, not an observed result

A Linux PID namespace might give the invocation a kernel-owned lifetime boundary
independent of cgroup migration. [PID namespace semantics](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)
state that PID membership is fixed at process creation, children can enter
only the same or descendant PID namespaces, and the kernel sends SIGKILL to
remaining namespace processes when its init dies. A `setsid` descendant stays
in its PID namespace. These statements are contingent on the kernel and do not
prove namespace setup, correct targeting, exit completion, or who else joined.

[Bubblewrap](https://github.com/containers/bubblewrap/blob/v0.13.0/README.md)
provides an unprivileged user/mount namespace and an optional PID namespace.
The [0.13.0 command reference](https://github.com/containers/bubblewrap/blob/v0.13.0/bwrap.xml)
describes `--unshare-pid`, `--die-with-parent`, `--new-session`, and status
file descriptors. Its [source](https://github.com/containers/bubblewrap/blob/v0.13.0/bubblewrap.c)
reports the initial command's exit via an event before the namespace init's
reaping loop necessarily finishes. Therefore neither an `exit-code` message
nor the outer monitor's exit is by itself proof that namespace descendants
are gone. `--die-with-parent` is a lifecycle aid, not a replacement for a
verified binding, teardown observation and startup race analysis.

On this host, a read-only `bwrap --version` reported 0.13.0, and
`/usr/bin/bwrap` had SHA-256
`d9498f8b15b1c69e09791badee317d56f33abd359a306d6e96534f136381ad74`.
`kernel.unprivileged_userns_clone` read as 1. These observations do not verify
binary provenance, kernel configuration, namespace creation, LSM permissions,
or future availability. The source tag is a reference, not proof that the
installed binary was built from it. No namespace was created for this record.

## Conditions a future supervisor must prove

1. Create a fresh invocation-owned user and PID namespace before any workload
   can fork; capture startup errors and never fall back to the host namespace.
   Keep the workload blocked until setup and binding are verified. Exact
   Bubblewrap version, handshake, startup-failure and parent-death race behavior
   need source review before assuming any status FD can serve this purpose.
2. Establish the namespace init's *exact* process identity and lifetime via a
   race-resistant kernel handle, acquired before it can exit or be replaced.
   A numeric PID, process group, `child-pid` JSON field, or pathname alone is
   insufficient: the JSON contract does not establish that it names PID 1.
   The trusted handshake must bind that handle to the particular invocation and
   namespace init; how to make this binding remains an open design issue. Do not
   send a signal until it is resolved. PID reuse, early death, missing status,
   malformed, duplicate or conflicting identity-bearing status records,
   timeout, handle mismatch and signaling errors all produce incomplete
   evidence, not a fallback kill. The status protocol normally emits multiple
   JSON lines; a bounded ordered parser must handle documented records and
   ignore unrelated or unknown records as specified, without mistaking an
   unknown record for proof.
3. On a reviewed cleanup path, terminate only that bound init through its
   retained process handle. Confirm its actual termination and independently
   establish what kernel event proves the complete namespace teardown; PID-1
   exit, wrapper exit, a cgroup's `populated 0` and closing a namespace FD must
   not be conflated. Uninterruptible tasks, concurrent forks, nested namespaces,
   reparented children, supervisor death and signals during startup need exact
   source-backed treatment. A timeout remains incomplete even if later cleanup
   succeeds. Never use a global name, a numeric PID/PGID, or a broad kill.
4. Rule out external process injection before claiming exclusive ownership.
   PID namespace entry is privilege-restricted, but same-user principals,
   privileged helpers, inherited namespace descriptors, brokers and runtime
   sockets must be considered. No namespace descriptors or control handles are
   exposed to the workload except what is necessary; no already-running process
   may be imported. If exclusive ownership is unproven, no signal is authorized.
5. Create a restricted mount view from an empty root, with a new namespace-local
   `/proc`, minimal read-only toolchain and source inputs, and only fresh
   invocation-owned writable build/output directories. Do not expose writable
   host `/sys/fs/cgroup`, host `/proc`, host PID-namespace handles, host runtime
   sockets or unrelated shared caches. Close unneeded inherited descriptors;
   avoid host TTY injection and external service brokers. Audit all descriptors,
   mount aliases, symlinks, writable paths, `setns`, user namespaces, capability
   transitions and generated tool execution. This is a proposed observation
   boundary, not a qualified Writ worker or complete security sandbox.
6. Retain exact tool/source hashes, original and generated inputs, command,
   status/control protocol, start/end timestamps, all setup/refusal and retry
   output, timeout, targeted identity evidence and cleanup observations. Fail
   closed if a required kernel, Bubblewrap feature or evidence mechanism is
   unavailable. No privilege escalation or shared-system reconfiguration is
   part of this design.

The [cgroup-v2 documentation](https://docs.kernel.org/admin-guide/cgroup-v2.html)
explains migration and `populated`: an empty current subtree does not prove
that a former descendant did not move away. The
[systemd user-manager documentation](https://www.freedesktop.org/software/systemd/man/256/systemd.exec.html)
says `ProtectControlGroups=` is unsupported for per-user managers. Neither
`systemd-run --user` nor a bare child cgroup is therefore treated as an
established solution here. The read-only `supervisor-preflight.py` reports
observations and always exits incomplete; it does not create, move, launch or
signal anything.

## Synthetic lifecycle test plan, not executed

After source and safety review of a future implementation, run isolated
synthetic tests with no Genode, no user VM, no host process enumeration and
no network. Each test must own all its children and use exact handles:

- normal immediate exit and nested child exit; delayed child after initial
  command exit; verify wrapper exit is not treated as teardown;
- a `setsid` descendant, a double-fork/orphan, and nested PID namespaces;
- simultaneous fork and cleanup, repeated timeouts, supervisor termination,
  startup failure and parent-death timing windows;
- deliberately absent/malformed or delayed status, stale/incorrect identity,
  failed pidfd creation or signal, nonzero exit and unverified cleanup; each
  is incomplete with no fallback numeric or group signal;
- an unrelated *synthetic* sentinel created outside the tested namespace must
  survive every case; it is owned by the test itself, not found by searching
  other processes; verify its identity using its own retained child handle;
- check that attempts to import an external process or access forbidden host
  namespace/cgroup handles fail or else classify the isolation as unsupported;
  check process retirement only using reviewed ownership evidence;
- preserve test command, scoped process identities, separate positive and
  failing controls, cleanup status and raw logs. A setup refusal is not a pass.

Only after these separate tests and independent review could a Genode run and
its own negative control be considered. They cannot establish protected-host
qualification or answer the remaining authority questions.
