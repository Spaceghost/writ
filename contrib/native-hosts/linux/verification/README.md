# Linux native canary evidence

A real Linux FUSE mount passed the bounded public-canary profile on
2026-11-04. This verifies the fixed worker and native boundary described in
[the contribution](../README.md). It does not qualify arbitrary applications,
protected production data, persistent audit, or a complete Linux host.

## Exact execution

| Item | Recorded value |
| --- | --- |
| Source commit | `a66c03e5249d3e507694dbe11070a27aa8024d81` |
| Source tree | `bb800e0950d579028a560d4868809c69e7aebd5a` |
| Workflow run | [41776660115](https://github.com/Spaceghost/writ/actions/runs/41776660115), attempt 1, **success** |
| Native job | [126398486561](https://github.com/Spaceghost/writ/actions/runs/41776660115/job/126398486561), **success** |
| Runner | Ubuntu 24.04.5 LTS, image `ubuntu24 20261026.354.1` |
| Kernel | `7.0.0-1017-azure`, x86_64 |
| FUSE | libfuse `3.14.0`, Ubuntu package `3.14.0-5build1` |
| Worker controls | Landlock ABI 8 observed; ABI 3 required; namespaces, seccomp and `no_new_privs` checked from kernel state |
| Runtime/toolchain | Node 22.23.4; pinned Bend 2.0.39; GCC 13.3.0 for bindings; clang 19.1.1 for generated native Bend |
| Canary | 29 bytes; SHA-256 `085bced4db355be6b54ddac3fbf9c54087140d4ebb33b6847a386ac0d6c6a98a` |
| CI artifact | ID `13296764680` |
| Artifact SHA-256 | `52429e5548efa8939724fea670fc7f14e4197c317fe0d2de721c08a630d62715` |

The artifact was downloaded, its SHA-256 verified, and the native evidence below
retained verbatim. These files preserve the exact native assertions, requester
events, setup refusal, host versions, compiler commands and source/build hashes.
The captured runner paths identify the tested build; they are not local commands
to replay against this checkout. The common model/core outputs are recorded
[separately](../../VERIFICATION.md), avoiding duplicate copies here.

| Retained file | Contents |
| --- | --- |
| [environment.log](run-41776660115/environment.log) | Source commit, runner image, kernel, OS, installed packages, compiler, FUSE and Node versions |
| [source-and-build-sha256.txt](run-41776660115/source-and-build-sha256.txt) | Exact native source, generated policy and executable hashes |
| [native-build.log](run-41776660115/native-build.log) | Native binding and probe compilation commands |
| [native-transport.log](run-41776660115/native-transport.log) | Ten real C-to-Bend pipe assertions, including malformed peers and timeout |
| [native-revocation.log](run-41776660115/native-revocation.log) | Mounted reads, repeated outsider denials, fixed-worker effects, revocation and owned cleanup |
| [native-policy-failure.log](run-41776660115/native-policy-failure.log) | Mounted observations followed by actual interpreter termination and denied service |
| [native-broker-crash.log](run-41776660115/native-broker-crash.log) | Actual broker SIGKILL, retained child lifetime checks, abandoned FUSE connection and owned unmount |
| [setup-refusal.log](run-41776660115/setup-refusal.log) | Deliberate missing-control refusal before input loading or Bend admission |

## Observed behavior

| Case | Evidence from the real native run |
| --- | --- |
| Ownership and admission | Memfd write/resize attempts fail; pre-admission access is denied; Bend completes the capability-to-commit gate before the first successful read. |
| Native actor binding | FUSE supplies UID/GID/PID, checked against the retained reader lifetime. A separate same-UID process is refused open, stat and listing both before and after the admitted reader populates lookup/attribute paths. The harness requires corresponding actor-0 Bend denial events. |
| Read and handles | Mounted bytes equal the sealed input; range, EOF, duplicate-descriptor reads and the single-entry directory listing pass. |
| Worker effects | Native probes refuse writes, shared/private mappings, IPv4/IPv6/Unix sockets, exec/fork, tracing, cross-process memory, signals, shared memory, new memfds, `io_uring`, outside/proc paths, stdout, descriptor sending, ioctl, sendfile and `copy_file_range`. Same-UID tracing of the reader is also refused. |
| Revocation | Existing and duplicated descriptors, new opens and metadata fail after Bend revocation. Retained handles close and Bend reaches STOP. |
| Interpreter crash | Killing the actual private Node interpreter causes existing/new reads and metadata to fail with EIO. There is no interpreter restart or replay. |
| Broker crash | The external probe pins reader/policy lifetimes, kills the real broker with SIGKILL, observes both processes exit, receives ENOTCONN from the abandoned FUSE mount, and removes that owned mount. |
| Missing control | Requesting unsupported Landlock ABI `4294967294` exits 1 before input loading or Bend admission. The workflow checks this refusal and verifies owned resource cleanup. |

The deliberate missing-control case prints `FAIL native worker ready` and
`LINUX NATIVE CANARY CHECK FAILED` before the outer harness verifies the expected
refusal. Those lines are retained, not hidden. Other mounted cases must succeed;
the workflow has no native capability skip or weaker fallback.

The same job passed 70 shared mount-model assertions in each of the JavaScript
and native CPU backends, nine shared bridge probes, ten C pipe-transport
assertions, and **782 core assertions plus 41 HostBinding vectors per backend**.
The two core outputs are byte-identical. Ordinary `PROOF.bend` checks passed for
the six selected laws and explicitly printed the `--verdict` qualification;
this job did not run Lean kernel verification or a physical GPU. Model/proof
checks are separate from the mounted native observations above.

## Historical successes

Each prior result remains evidence for its exact source. Later upstream core
additions do not change a historical run's assertion count.

| Run | Exact source | Recorded result |
| --- | --- | --- |
| [41772025934](https://github.com/Spaceghost/writ/actions/runs/41772025934) | `648ced71a08cd93a733e7d5f4173fc1ff0d612a0` | First passing complete Linux native canary workflow; 638 core assertions per backend |
| [41774496202](https://github.com/Spaceghost/writ/actions/runs/41774496202) | `35c5665efef64420b73fe84d6d198f17e1fec891` | Passing native canary workflow after the initial HostBinding integration; 764 core assertions and 40 vectors per backend |
| [41776660115](https://github.com/Spaceghost/writ/actions/runs/41776660115) | `a66c03e5249d3e507694dbe11070a27aa8024d81` | Passing native canary workflow after the refreshed integration; 782 core assertions and 41 vectors per backend; artifact evidence retained above |

## Preserved failures and corrections

[Selected original failure output](prior-failures.log) retains timestamps and
native results from both failed jobs. Common model/core assertions, package
installation and command echoes are omitted from these focused excerpts.

- [Run 41770442545](https://github.com/Spaceghost/writ/actions/runs/41770442545),
  job `126378652240`, source `944fe2ba571b01d9762d9c2154d24ade77fb13a2`:
  real reads passed, but directory listing failed. The Linux `O_TMPFILE`
  constant includes `O_DIRECTORY`; treating every included bit as a creation
  flag incorrectly rejected read-only directory opens. The filter and FUSE
  flag checks now mask only the temporary-file creation bit. Review also found
  that non-traversable temporary ancestors could make foreign-caller probes
  fail before reaching FUSE. The fixture now has traversable trusted ancestors
  and requires actual actor-0 denial events from Bend.
- [Run 41771484394](https://github.com/Spaceghost/writ/actions/runs/41771484394),
  job `126381951527`, source `9f3a49d57b97ec71cc65cb76d8e0d43912fb234a`:
  mounted revocation and interpreter-death cases passed, but the final shell
  assertion failed because `rg` was unavailable on the runner. It now uses
  available `grep -F`. This run remains a failed workflow and predates the
  broker-crash/warm-cache probes.

The successful runs exercise these corrections together with broker-crash and
repeated foreign-caller checks. The scope and unresolved product work remain
in the [native-host canary contract](../../../../openspec/specs/native-host-canary-mounts/spec.md)
and the [broader Linux host contract](../../../../openspec/changes/add-linux-host/proposal.md).
In-memory event capture is not durable audit, and mediated revocation cannot
erase bytes a worker already observed.

## Later combined model run

[Run 42308676909](https://github.com/Spaceghost/writ/actions/runs/42308676909)
passed the existing public-canary workflow on source `73a8055`, with 2,065
core checks in each backend. Its [retained evidence](run-42308676909/README.md)
includes the expected unsupported-setup refusal and does not qualify the
separate Linux protected-worker profile.
