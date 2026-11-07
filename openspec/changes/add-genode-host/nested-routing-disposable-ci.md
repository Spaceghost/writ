# Public nested Genode fixture on a disposable CI VM: proposed amendment

A public synthetic R request could run under nested Genode `init` on a fresh
GitHub-hosted VM, while the user's existing local VMs and shared Genode cache
are untouched. A failed route, incomplete build or timeout would be retained
as such. This is a **design only**: no workflow change, CI dispatch, Genode run
or negative control is performed here. The [first-slice plan](nested-routing-first-slice.md)
and [fixture](../../../contrib/native-hosts/genode/nested-channel/writ_bend_monitor_nested_accept.run)
remain experimental; no protected host is qualified.

## Narrow scope change

For a dedicated disposable VM running *only this public synthetic fixture*,
VM disposal is a fallback containment boundary if in-guest cleanup cannot be
verified. This revises the prior requirement for a reviewed local descendant
supervisor **only for this dedicated disposable CI environment**; that local
requirement still applies on shared machines. It does not establish that all
children exited, that VM disposal occurred at a particular instant, that data
was erased, or that the environment is a production security boundary. Record
unverified cleanup explicitly; no process-name, broad PID/PGID or global kill is
acceptable. GitHub documents a fresh image per job and a new VM for standard
multi-CPU hosted runners; the single-CPU `ubuntu-slim` runner is a container on
a shared VM and is not acceptable for this plan. See [runner selection](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job).

This is conditional on a trusted runner provider and reviewed workflow and
inputs. The dedicated VM must run no other user workload and contain no user
secrets or protected data, but a GitHub-hosted job is **not token-free**:
GitHub creates a job `GITHUB_TOKEN`, and actions/platform services may use
runtime credentials. An action may access the token through the GitHub context
without an explicit input. See [GITHUB_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token)
and [token usage](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token).
Minimize permissions to `contents: read`; do not request write or OIDC tokens,
reference user secrets, pass credentials to the fixture, persist checkout
credentials, or print the environment. Keep public fixture data, logs and
artifacts separate from credentials. These measures do not prove the VM, its
network, dependencies, runner services or same-user subprocesses are unable to
access every platform credential. Public source/toolchain trust, provider and
action integrity, and platform credential isolation remain explicit risks.

## Exact branch-only change to the existing workflow

The proposed future implementation changes only the existing
[WritFS Genode workflow](../../../.github/workflows/writfs-genode-native.yml),
not a new workflow or a default acceptance route. Review its then-current
source before implementing. Its current push filter includes `master` and
`writfs-native-hosts-ci`; `workflow_dispatch` is also enabled. The experimental
branch is proposed as `lane/genode-nested-public-ci`.

- Add to the existing `base-hw` job the guard
  `${{ !(github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/lane/genode-nested-public-ci' && github.repository == 'Spaceghost/writ') }}`.
  It suppresses that existing job only for the experimental branch's manual
  dispatch in that repository; master push, forks and other existing invocations retain their
  previous behavior. Check this again against the final workflow and tests.
- Add two separately named jobs, positive and negative, each guarded by
  `${{ github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/lane/genode-nested-public-ci' && github.repository == 'Spaceghost/writ' }}`.
  Each uses its own standard hosted `ubuntu-24.04` **VM**, not `ubuntu-slim`,
  a self-hosted runner, job container or shared host. Each is public-only and
  starts from independently provisioned inputs. The branch push itself is not
  included in the current push branch filter; this proposal does not dispatch it.
- Use the already pinned `actions/checkout` commit in the existing workflow,
  with `persist-credentials: false`, and check out the full fixed fixture
  source `c14f125454e279011589b9527069161241419171` in each job. Verify the
  exact HEAD, clean worktree and source manifest before build. This avoids a
  self-referential source hash in the separately committed workflow amendment.
  Record both that fixture source SHA and the actual workflow/run SHA and ref;
  an independently reviewed exact workflow commit and job definitions must be
  checked against the run metadata. If current master later advances, do not
  silently attribute this run to it or change the fixed source without review.
- The branch-name guard does **not** pin the workflow commit. Before any
  dispatch, compare the remote branch head and workflow file to the exact
  independently reviewed workflow commit; a mismatch or unavailable check
  stops the run. GitHub's [dispatch API](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event)
  takes a branch or tag ref, so a pre-dispatch comparison alone is not atomic
  with resolving that ref. This branch strategy additionally requires trusted
  control of the branch and no concurrent writer between verification and
  dispatch. Confirm those conditions before dispatch, or use a separately
  reviewed immutable-ref mechanism with an appropriately revised job guard.
  A post-dispatch run-SHA check documents attribution but cannot undo execution
  of a moved branch; if exact workflow identity cannot be assured, do not run.
- `permissions: contents: read` is retained. No repository or environment
  secrets are referenced, no write/`id-token` permission is granted, and
  fixture subprocesses receive only a reviewed minimal environment and public
  paths. This is credential minimization, not a claim that the Actions runner
  or platform holds no credential. Third-party actions must remain pinned and
  independently reviewed; do not add `pull_request_target` or arbitrary input.

No workflow code is supplied or approved by this note. The actual change must
be reviewed before any run, including branch-guard and pin behavior. The
existing workflow's `build-and-run.sh` exercises a different WritFS base-hw
path; its successful run would not exercise this nested channel.

## Reproducible inputs and setup obligations

For each job retain full SHA-256 checks and source identity, not just version
strings:

- Pinned Writ source above and its complete tracked source manifest; preserve
  the exact fixture `.run`, `scripts/genode/writ_bend*.tcl`, `writ_bend.inc`,
  unchanged monitor Bend source/effect twins, client, shim, target makefiles
  and generated C hashes. The existing external overlay preparer requires a
  clean worktree, an absolute Bend path and a fresh direct
  `/tmp/writ-genode-nested-overlay.*` path; each VM must use its own path.
- Bend 2.0.39 Linux archive SHA-256
  `6cf462fd8f70b094a4950ebb709a9c4ffd8f1d1189d9cedf1fd63cd5d041c7ab`,
  with the executable version and hash recorded. The [existing CI](../../../.github/workflows/writfs-genode-native.yml)
  demonstrates this archive pin; it is not evidence for a nested run.
- Genode source tag 26.08 commit `d18ee9e917200b059549e21f2dd9a55bfe61a0eb`
  and official source archive SHA-256
  `df74f96c70c72607d66f5440439680b63683f09edd92809996845f0f29453a74`;
  Genode 25.05 x86 toolchain archive SHA-256
  `6cab8e5f4490399a296a73b01695d5fb055a40f6ac04d61a3f7a7344003eb739`.
  Verify both extracted inputs and the source/archive relationship as recorded
  in [the existing pins](../../../verification/genode-pins.txt); do not assume
  a tag alone authenticates local files. Fresh source, toolchain, libc port,
  overlay, build and outputs belong outside the checkout and use no shared cache.
- The Genode 26.08 `libc.port` pins FreeBSD 12.0 `src.txz` SHA-256
  `0da393ac2174168a71c1c527d1453e07372295187d05c288250800cb152a889b`.
  Its upstream URL in that pinned port uses HTTP. Before implementation,
  review a verified HTTPS acquisition/cache procedure preserving these exact
  bytes and Genode's port checks; do not silently substitute input or alter
  the checked-in port. Record errors if the input cannot be obtained.
- This channel monitor's existing makefile requires host `clang-23`, including
  its matching resource directory. The Writ flake pins a clang 23.1.3 through
  `flake.lock`, while prior Genode host evidence used 23.1.1. Provision an
  independently verified, immutable clang-23 and record binary/resource
  hashes, full version and origin; validate the exact pinned flake-derived
  option or an equivalently pinned artifact before writing the workflow. Do
  not assume the hosted image contains it or claim 23.1.3 was previously run
  on this channel. Pin or record all remaining packages and runner image;
  install Genode's required make, Tcl/Expect, flex, bison and rpcgen in the
  fresh VM. Inability to provision an exact dependency is incomplete.
- Generate a fresh x86_64 **base-linux** build, `BOARD=linux`, `KERNEL=linux`,
  explicit repository order including the overlay and required Genode repos,
  toolchain prefix, explicit bounded jobs and the existing local-expect rule
  narrowed to this one scenario. Do not copy its historical shared absolute
  paths or `-j16`. Preserve the generated configuration, route and quota
  inputs, source/generated hashes, command, compiler paths and build output.

## Separate positive and negative controls

The positive job runs the unmodified reviewed nested-R `.run`: require the
actual nested label and subject, synthetic monitor decision, client result,
exit and exact request/result bytes. A timeout, route/session failure, missing
line, changed label, crash or resource shortage is a failed/incomplete run.

The negative job starts in its **own fresh VM** with the same fixed Writ and
external inputs. After source staging, change only the overlay copy's R client
`expect_decision: 1` to `expect_decision: 2`; verify exactly one match, retain
the unmodified and changed file hashes and a minimal diff. This does not alter
Bend policy or trusted route configuration. The existing client compares the
actual decision with that expectation and exits 1 on mismatch. A valid control
requires the actual expected R `Committed`/decision 1 result and the specific
client mismatch/exit 1 plus the fixture harness's failing result. Retain the
raw nonzero result even if a surrounding check reports that the control was
detected. A download failure, build failure, route refusal, timeout or any
other nonzero exit is **not** a successful negative control and is not a Bend
denial. If the positive run or negative prerequisites cannot complete, report
both actual outcomes without turning the suite green by expectation alone.

## Timeout, logs and limits

Use a job timeout with an earlier bounded build/run deadline and reserve time
for public evidence capture. A deadline limits waiting but cannot prove every
forked descendant terminated. Never kill by global process name or an
unverified PID/PGID; if exact cleanup cannot be verified, record it as unknown
and rely only on the dedicated VM's eventual provider disposal as the fallback.
A hung process, cancelled runner, job-wide timeout or platform failure can
prevent log upload. Bound fixture output and artifact sizes without silently
truncating a passing run; treat output overflow or truncated/missing evidence
as incomplete. Preserve stdout/stderr, exit status, setup failures, timeout,
input and generated-output hashes, exact run/workflow/source IDs, runner image
and configuration, positive/negative distinction and teardown uncertainty.
Use the existing pinned upload action with `if: always()` where execution
reaches it, and retain public logs only; this cannot guarantee upload after a
hard cancellation or VM failure. Missing evidence remains missing, not a pass.

Even a successful run would show only this public synthetic base-linux route
and decision under the observed configuration. It would not prove cleanup,
confidentiality, authenticated identity, malicious-peer isolation, secure
publication, native hardware qualification, or the unanswered host cases.
