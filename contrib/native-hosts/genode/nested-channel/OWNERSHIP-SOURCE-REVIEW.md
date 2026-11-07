# PID-namespace ownership: source review and remaining proof

Suppose an isolated test forks a worker that creates a new session and another
PID namespace. A future supervisor needs to retire both, even if the original
command exits first, without signaling an unrelated process. An invocation's
PID namespace can provide a stronger lifetime boundary than a process group;
the installed host, unchanged Bubblewrap and the evidence here do **not** yet
prove the boundary is exclusive or safe to use. This is design-only: no
namespace, test workload, signal, Genode run or Linux identity probe was run.

## Inspected sources and scope

- Bubblewrap `v0.13.0` annotated tag `52d23329a689f64a8b601f8b999affb69b9339ac`
  resolves to commit `719a4fd474d44b26906bcf2b1b0fb6eddd8d56d0`.
  [bubblewrap.c](https://github.com/containers/bubblewrap/blob/719a4fd474d44b26906bcf2b1b0fb6eddd8d56d0/bubblewrap.c)
  and [bwrap.xml](https://github.com/containers/bubblewrap/blob/719a4fd474d44b26906bcf2b1b0fb6eddd8d56d0/bwrap.xml)
  were fetched read-only; SHA-256 values are respectively
  `534295b804fa3f5ddeb3ae275ce5a2113d468c72ec0a74fdad6003e0a67ee4ef`
  and `2cb77df2f4be0b2a0302bb2f0a260fdb4d9e1299b76481ea66ed34c40f5be1da`.
  The installed `bwrap --version` reported 0.13.0; its hash and limited
  provenance are in the [first design](PID-NAMESPACE-DESIGN.md). Neither
  version text nor this inspection establishes that binary's source identity.
- Upstream Linux `v7.2.9` annotated tag `bd50482a9c7a6eb91468f1064a346a75e677e692`
  resolves to commit `5fce161649b4d779d1b76d9fcd52dc77779774b8`.
  [kernel/pid_namespace.c](https://github.com/gregkh/linux/blob/5fce161649b4d779d1b76d9fcd52dc77779774b8/kernel/pid_namespace.c)
  and [kernel/exit.c](https://github.com/gregkh/linux/blob/5fce161649b4d779d1b76d9fcd52dc77779774b8/kernel/exit.c)
  were fetched read-only; their SHA-256 values are respectively
  `067409e5c66295932476311a8b3d18b10f1f9279be246be74a9aa1fec09e5873`
  and `ecca06ee0bf8e50177e955788f183798fc7f82add2f609f8f961a30b31440595`.
  The local kernel reports `7.2.9-1-MANJARO`; this does not establish that the
  installed kernel, configuration or patches match the upstream source.

## Bubblewrap identity and the startup gap

With `--unshare-pid`, no imported `--pidns`, and the cited source, Bubblewrap
uses `raw_clone` with `CLONE_NEWPID`; the resulting child is the new PID
namespace init. The parent reports that clone result as `child-pid` in
`--info-fd` and/or `--json-status-fd`. This is a source-specific conditional
identity, not a general promise that every reported child is PID 1. Imported
PID namespaces and different versions take different paths. A reported integer
alone is not a retained process identity; PID reuse and a dying/reaped monitor
must be excluded before opening a pidfd for it.

`--userns-block-fd` makes the parent publish `--info-fd` and then wait before
releasing the child via an eventfd; in this mode the user namespace mapping is
expected from the outside. On the child side the eventfd read occurs before
`handle_die_with_parent`. The child itself retains an eventfd descriptor:
parent death does **not** imply EOF, and a blocked child can remain. The read
return is not checked, so a read error or interruption may continue setup. The
parent's userns-block read and the later child's `--block-fd` read also ignore
return values. Neither an EOF/error nor `--die-with-parent` alone establishes
fail-closed startup. The latter uses `PR_SET_PDEATHSIG`; the source does not
show a post-registration parent-liveness check at this early gate.

The `--sync-fd` is retained by Bubblewrap's namespace init in the ordinary
non-`--as-pid-1` path, while the workload closes it. It can help detect the init
closing the FD, but it does not by itself prove all tasks are gone: descriptors
can close during exit before a namespace is fully retired. The initial command
exit event and outer monitor exit can precede namespace init retirement. Do not
infer cleanup from `--sync-fd`, status JSON, command success, or timeout alone.

## Conditional kernel retirement and nested namespaces

[Linux PID namespace semantics](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)
fix a process's PID namespace at creation. A process can create children in a
same or descendant namespace but cannot move itself to an ancestor namespace;
`setsid` does not change PID namespace. In the cited upstream 7.2.9 code,
`find_child_reaper` invokes `zap_pid_ns_processes` as the last namespace-init
thread exits. The latter disables new PID allocation, sends SIGKILL to remaining
members and waits, including for externally parented tasks. Its comment states
the intended invariant that reaping init means all processes in that namespace
are gone. Nested-namespace tasks also have PIDs in the ancestor namespace.

That is a **conditional source argument**, not observed kernel behavior. It
requires an exact verified kernel/configuration and correct init identity;
ptrace, nested namespace, task lifetime and wait semantics need independent
review on that actual kernel. A task in uninterruptible sleep or an externally
parented zombie can delay retirement indefinitely. A timeout, missing or
unverifiable wait, or inability to reap the exact init is incomplete even if
SIGKILL was delivered. No global process scan, name kill or unrelated VM action
is a remedy.

## Candidate ownership architecture; not implemented

A candidate for independent design review is a tiny native **guard init** in a
fresh outer PID namespace, started by the supervisor with `clone3` using
`CLONE_NEWUSER | CLONE_NEWPID | CLONE_PIDFD` so the parent receives the init
pidfd atomically. The unprivileged user-namespace and mapping prerequisites need
separate validation; there must be no privileged fallback.
The guard would start Bubblewrap only as its descendant, and Bubblewrap may
create its own nested PID namespace. All workload descendants, including those
in inner PID namespaces and new sessions, would still have membership in the
outer namespace. Use of a small native lifecycle helper is a proposed packaging
boundary; no policy, grants or release decision belongs there.

This is not yet an ownership proof or permission to implement/run it:

1. The single-threaded parent must retain the exact guard pidfd and direct-child
   relationship. No integer PID or status JSON may be promoted into authority.
   Before spawning the guard, it would also obtain a pidfd for itself to pass to
   the child. The child must install `PR_SET_PDEATHSIG` and check the inherited
   parent pidfd for prior parent exit before forking or executing anything; a
   failing or ambiguous check exits without launching. This is a proposed
   race-closure, not proven code. Verify `PR_SET_PDEATHSIG` behavior, parent
   **thread** lifetime, permission/credential changes that clear it, PID 1
   signal semantics, and all pipe/FD ownership and races against the exact
   kernel. The guard must not change credentials or exec while relying on the
   parent-death setting. No child-side setup may fork before the handshake.
2. Parent and guard must complete a bounded readiness handshake before any
   workload forks. Closed descriptors, partial messages, failed user mappings,
   failed namespace/mount setup, lost parent, timeout or failed pidfd operations
   are incomplete; a failed handshake must not silently fall back. A crash of
   the supervisor or guard before/after each step must not leave an untracked
   process. This needs design and fault tests, not a claim about the current
   Bubblewrap gate.
3. A retained pidfd could identify the exact guard for the cleanup signal;
   `waitid(P_PIDFD, ...)` on the supervisor's own direct child could potentially
   observe its reaping after the kernel's namespace teardown. This wait applies
   to the guard, a direct child of this supervisor, not to Bubblewrap's own
   separately parented inner init. Successful signal delivery, pidfd readability
   and reaping are distinct observations; require the exact guard reap. Validate the
   upstream invariant and pidfd/wait ordering against the exact running kernel,
   including guarded PID 1 threads, nested namespaces and uninterruptible tasks.
   No numeric PID/PGID fallback is acceptable. The test's outcome remains
   incomplete on timeout or any unverified cleanup even if a signal was sent.
4. **Exclusive membership remains unresolved.** The proposed guard's newly
   created user namespace has an owner UID in the parent's user namespace. A
   same-UID outside process in that parent user namespace has capabilities in
   the owned child user namespace. If it can obtain the guard's user- and PID-
   namespace handles and passes the kernel and LSM access checks, it may enter
   the child user namespace, acquire its capabilities, use `setns` on the
   descendant PID namespace, and fork a child into that PID namespace. PID
   `setns` requires the relevant `CAP_SYS_ADMIN` checks both in the caller's
   current user namespace and in the user namespace owning the target PID
   namespace. Access to `/proc/<pid>/ns/*` has separate ptrace/LSM checks;
   none of this proves an actual injection succeeded. See
   [user_namespaces(7)](https://man7.org/linux/man-pages/man7/user_namespaces.7.html),
   [setns(2)](https://man7.org/linux/man-pages/man2/setns.2.html) and
   [namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html).
   Namespace teardown could kill that externally injected, unrelated child.
   A private
   PID namespace, random name, status pipe, hidden path or writable cgroup is
   not proof of exclusion. If a foreign process could join, killing init could
   kill that unrelated process. Require a separately verified isolation/trust
   boundary excluding injection for the entire lifetime, including startup
   before any child-side dumpability changes; otherwise do not send a signal
   or claim completion. The host kernel and its administrator are trusted;
   fully privileged hostile host principals can override a user sandbox and
   are outside this candidate's protection. Same-UID unprivileged principals
   are not assumed away. No no-injection boundary is established here.
5. The mount/descriptor policy in the [first design](PID-NAMESPACE-DESIGN.md)
   must also rule out host process creation via writable sockets, external
   services, inherited descriptors or privileged helpers; PID namespace
   membership covers only tasks born into that namespace tree. A source-level
   argument about the kernel does not establish effect confinement, a protected
   Writ worker, or authentication of a requester.

## Review gates and synthetic tests

Before even a namespace-only experiment, independently review the precise native
launcher, dependency and kernel identities, no-injection threat boundary, all
lifetime and failure paths, mount/FD policy, bounded runtime and cleanup. The
preexisting OS preflight remains read-only and always returns incomplete. Do
not call it an executable supervisor, and do not run or alter the separately
withheld Linux identity probe.

If a future candidate satisfies those prerequisites, the synthetic-only tests
in [the first design](PID-NAMESPACE-DESIGN.md#synthetic-lifecycle-test-plan-not-executed)
must additionally cover each atomic-clone/handshake boundary: supervisor death
before guard setup, after parent-death registration, during mappings and before
workload fork; interrupted/failed/closed gates; guard death; nested PID init;
externally parented synthetic child where supported; `setsid`; wrapper early
exit; PID reuse attempts; unavailable pidfd or clone3; and forced teardown
with a deliberately unresponsive synthetic child. An invocation-owned outside
sentinel must survive and be identified by its own retained handle. Record raw
outcomes and mark every uncertainty incomplete. Tests must never discover or
signal unrelated host processes, touch shared Genode caches, or start Genode.
