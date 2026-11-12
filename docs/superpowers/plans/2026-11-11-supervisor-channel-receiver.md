# Supervisor Channel Receiver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Receive local supervisor administrative records with per-message kernel sender identity, and attribute each one in Bend to a provisioned role, never to a principal named in the bytes.

**Architecture:** A native C module under `contrib/native-hosts/linux/` receives one bounded `SOCK_SEQPACKET` record. It translates the kernel's `SCM_PIDFD` into one of: "retained role N", "unknown sender", or a malformed-record reason. A Bend module maps that fact to an `Issuance.Principal` through the supervisor-provisioned role map, or to a denial. The C side decides nothing about authority. Wiring the receiver into a running supervisor and its Bend pipe is the next plan, not this one.

**Tech Stack:** C11 with Linux 6.9+ (pidfs) and glibc, Bend 2.0.39, OpenSpec 1.16.0.

**Spec:** `openspec/changes/add-linux-host/local-supervisor-profile.md`, "Candidate administrative transport: source constraints". The transport was selected in board question 24 (`docs/superpowers/records/questions/q24.answers.jsonl`), based on `verification/linux-channel-identity/README.md`. Read both before starting.

Records: `docs/superpowers/records/2026-11-11-supervisor-channel-receiver/`, holding `progress.md`, briefs, reports, reviews and `activity.log`, per the board convention. Branch: `lane/supervisor-channel-receiver`.

## Global Constraints

- Restricted profile: 64-bit `ino_t`, `SO_PASSPIDFD`/`SCM_PIDFD`, and pidfds on pidfs (`PID_FS_MAGIC` 0x50494446). If any is missing, refuse setup. Never fall back to UID, PID or socket possession.
- Compare sender identity only by pidfs `st_dev`/`st_ino` against pidfds the supervisor retained from `clone3(CLONE_PIDFD)`. Never compare numeric PIDs.
- One bounded record per receive. Reject `MSG_TRUNC`, `MSG_CTRUNC`, a control header claiming more than the returned bytes, a missing, duplicate or negative pidfd, any `SCM_RIGHTS`, and any other control message. Close every installed descriptor on every path, and use `MSG_CMSG_CLOEXEC`.
- The native code translates facts only. It makes no grant, role-permission, revocation, clock or label decision (AGENTS.md, contrib/native-hosts/AGENTS.md).
- Bend attaches `from` only from the retained role map. A principal-shaped value in the payload never changes it (LH-011).
- Tests use only the test's own disposable processes and private sockets: no privilege, no host-wide probing, no mount, no VM (q23 scope). Scratch goes under `~/tmp`, and generated files and binaries stay outside the checkout.
- New Bend checks update `utils/verification/core-check-count.txt` after review (utils/verification/README.md).
- Payload limit `WRIT_CHANNEL_PAYLOAD_MAX` = 4096 bytes; role table limit `WRIT_CHANNEL_ROLES` = 8.

## Review Focus

- A sender that was retained, exited and was reaped while its record was queued. The expected result is `WRIT_FROM_ROLE` for that role, or `WRIT_SENDER_ERROR`; it must never match another role. Owned by Task 2, `reaped_role_sender`.
- Two role table entries naming the same lifetime, or the same index twice. The table must be refused at construction, not resolved at receive time. Owned by Task 2, `duplicate_role_rejected`, and Task 1, `invalid_role_map_denies`.
- A zero-length record. It is accepted as a payload of length 0 and attributed normally. Owned by Task 2, `empty_record_attributed`.
- Ordinary role records interleaved with malformed ones. A rejected record must not consume or corrupt the next good record. Owned by Task 2, `reject_then_accept`.
- Exhausting the role table (more than 8 roles). Adding returns an error and the table is unchanged. Owned by Task 2, `role_table_full`.

---

### Task 1: Bend channel attribution

**Files:**
- Create: `hosts/linux/monitor/LocalChannel.bend`
- Create: `hosts/linux/monitor/LocalChannelTests.bend`
- Modify: `Tests.bend` (register `LocalChannelTests`, following the existing `LinuxSessionLossTests` registration)
- Modify: `utils/verification/core-check-count.txt`

**Interfaces:**
- Produces, in `LocalChannel.bend`. The `ChannelReject` constructor order mirrors the C enum in Task 2.
  - `type ChannelReject`: `MissingSender{} | DuplicateSender{} | PayloadTruncated{} | ControlTruncated{} | UnexpectedRights{} | UnexpectedControl{} | SenderError{}`
  - `type ChannelFact`: `FromRole{role: Nat} | UnknownSender{} | Malformed{reason: ChannelReject}`. This classifies the sender only; payload decoding is separate.
  - `type RoleMap`: `NoRoles{} | Role{index: Nat, principal: I.Principal, rest: RoleMap}`. It is supervisor-provisioned, and indices must be unique.
  - `type ChannelDenial`: `InvalidRoleMap{} | UnknownRole{} | UnattributedSender{} | MalformedRecord{reason: ChannelReject}`
  - `type Attribution`: `Attributed{from: I.Principal} | Denied{reason: ChannelDenial}`
  - `def valid_roles(map: RoleMap) -> Bool`: indices are unique and nonzero.
  - `def attribute(map: RoleMap, fact: ChannelFact) -> Attribution`: public entry point. Check the map's validity first, then the fact.

- [ ] **Step 1: Write the failing tests in `LocalChannelTests.bend`**, each a `Test.check`, using synthetic fixtures marked as such: role 1 → `I.Principal{101n}` (source), role 2 → `I.Principal{102n}` (destination).
  - `provisioned_role_attributes`: `attribute(map, FromRole{1n})` is `Attributed{I.Principal{101n}}`.
  - `unknown_role_index_denies`: `FromRole{9n}` gives `Denied{UnknownRole{}}`.
  - `unknown_sender_denies`: `UnknownSender{}` gives `Denied{UnattributedSender{}}`.
  - `malformed_denies_each_reason`: each of the 7 `ChannelReject` values gives `Denied{MalformedRecord{same reason}}`.
  - `invalid_role_map_denies`: a map with index 1 twice, or index 0, gives `Denied{InvalidRoleMap{}}` even for `FromRole{1n}`.
  - `attributed_source_submits`: `I.submit_source`, called with `from` taken from `Attributed`, accepts. Reuse the source-approval fixture pattern from `LocalSupervisorTests.bend`.
  - `destination_role_cannot_submit_source`: the same approval with `from` from role 2 is rejected with `NotAuthority`, and the state is unchanged.
  - `payload_principal_is_ignored`: `attribute` takes no payload, so this test documents (with a comment) that a record whose decoded body names principal 101 but arrives from role 2 is attributed to 102.
- [ ] **Step 2: Run `bend hosts/linux/monitor/LocalChannelTests.bend`.** Expected: it fails because `LocalChannel.bend` doesn't exist.
- [ ] **Step 3: Implement the types and `valid_roles`/`attribute` in `LocalChannel.bend`.** Use named helper defs per AGENTS.md, and comment on authority direction: the map is supervisor state and the fact is a native observation.
- [ ] **Step 4: Run the focused tests (all PASS), then `bend Tests.bend`.** Check that the sorted list of previous check names is unchanged plus the new ones. Then run `bend PROOF.bend`, which must print `ALL PROOFS CHECK`.
- [ ] **Step 5: Build natively** (`bend Tests.bend -o X/tests.c`, then clang `-O0 -static`), run it, and require output byte-identical to the Bend run.
- [ ] **Step 6: Update `core-check-count.txt`** to the reviewed count, and run `python3 utils/verification/check_core.py` on the log.
- [ ] **Step 7: Commit:** "Attribute supervisor channel facts to provisioned roles".

### Task 2: Native supervisor channel receiver

**Files:**
- Create: `contrib/native-hosts/linux/supervisor_channel.h`, `contrib/native-hosts/linux/supervisor_channel.c`
- Create: `contrib/native-hosts/linux/supervisor-channel-test.c`
- Modify: `contrib/native-hosts/linux/Makefile`: add target `$(OUT)/supervisor-channel-test`.
- Modify: `contrib/native-hosts/linux/README.md`: add an inventory row.
- Remove: none. `channel-identity-test.c` stays as the q23 evidence.

**Interfaces:**
- Produces, in `supervisor_channel.h`:
  - `#define WRIT_CHANNEL_PAYLOAD_MAX 4096` and `#define WRIT_CHANNEL_ROLES 8`
  - `enum writ_channel_verdict { WRIT_FROM_ROLE, WRIT_UNKNOWN_SENDER, WRIT_MISSING_SENDER, WRIT_DUPLICATE_SENDER, WRIT_PAYLOAD_TRUNCATED, WRIT_CONTROL_TRUNCATED, WRIT_UNEXPECTED_RIGHTS, WRIT_UNEXPECTED_CONTROL, WRIT_SENDER_ERROR };`. The values from `WRIT_MISSING_SENDER` on map 1:1, in order, to Task 1's `ChannelReject`.
  - `struct writ_roles { size_t count; struct { uint32_t index; dev_t dev; ino_t ino; } role[WRIT_CHANNEL_ROLES]; };`. The table retains pidfs identity, not descriptor numbers. The caller keeps its own pidfds open for the role's lifetime.
  - `struct writ_channel_record { enum writ_channel_verdict verdict; uint32_t role; size_t length; unsigned char payload[WRIT_CHANNEL_PAYLOAD_MAX]; };`
  - `int writ_channel_profile_check(void)`: returns 0, or an errno (`ENOTSUP` when there's no pidfs or `SO_PASSPIDFD`). It probes on a private socket pair and on `pidfd_open(getpid())`.
  - `int writ_roles_add(struct writ_roles *, uint32_t index, int pidfd)`: returns 0 on success. Returns `EINVAL` for index 0, a duplicate index, a duplicate lifetime, or a non-pidfs fd, and `ENOSPC` when full; on any error the table is unchanged.
  - `int writ_channel_enable(int fd)`: sets `SO_PASSPIDFD` on the receiving end before any record is queued.
  - `int writ_channel_receive(int fd, const struct writ_roles *, struct writ_channel_record *out)`: returns 0 when one record was consumed (whatever its verdict), or -1 with errno on a syscall failure. It never returns a descriptor to the caller.

- [ ] **Step 1: Write `supervisor-channel-test.c`.** Model it on `channel-identity-test.c`: `clone3(CLONE_PIDFD)` children, `PR_SET_PDEATHSIG`, alarms, exit status 0, 1 or 77, `PASS`/`FAIL` lines. Children register as roles 1 and 2 through `writ_roles_add`; child C is spawned but not registered. Cases, each a `PASS <name>` line:
  - `profile_check_passes`
  - `role_one_attributed`: verdict `WRIT_FROM_ROLE`, role 1.
  - `transferred_endpoint_attributes_receiver_role`: A passes its end to B, and B's record gives role 2.
  - `unregistered_sender_unknown`: C's record gives `WRIT_UNKNOWN_SENDER`.
  - `reaped_role_sender`: queued, then A exits and is reaped; the result is role 1 or `WRIT_SENDER_ERROR`, never role 2.
  - `missing_sender_without_enable`: a socket without `writ_channel_enable` gives `WRIT_MISSING_SENDER`.
  - `rights_rejected`, `payload_truncated` (4097 bytes), `control_truncated`. For `control_truncated`, add an internal test seam: `writ_channel_receive_with_control(fd, roles, out, control_len)`, declared in a `#ifdef WRIT_CHANNEL_TESTING` section of the header.
  - `empty_record_attributed`: length 0 with role 1.
  - `reject_then_accept`: a rights record, then a good record from role 1, gives rejected and then role 1.
  - `duplicate_role_rejected`: the same pidfd under index 3, or index 1 twice, gives `EINVAL` with `count` unchanged.
  - `role_table_full`: a ninth add gives `ENOSPC`.
  - `descriptor_cleanup`: the `/proc/self/fd` count is equal at start and end.
- [ ] **Step 2: Build and run.** Run `make -C contrib/native-hosts/linux OUT=$HOME/tmp/supervisor-channel $HOME/tmp/supervisor-channel/supervisor-channel-test`. Expected: a link failure, because the functions don't exist yet.
- [ ] **Step 3: Implement `supervisor_channel.c`.** Lift the bounded receive and cleanup logic from `channel-identity-test.c` `receive_record`, including the `short_control` handling. Role matching is a linear scan over `count` entries by `dev`/`ino`. Comments state that the module translates facts and does not authorize.
- [ ] **Step 4: Run the test.** Expected: all `PASS` lines and `RESULT PASS`, exit 0; then 20 repeats, all exiting 0. Build with `-Wall -Wextra -Werror -Wconversion -Wshadow`, using both gcc and clang.
- [ ] **Step 5: Run mutants**, recording each diff and its output. Removing the `SCM_RIGHTS` rejection must fail `rights_rejected`. Matching by first-role-always must fail `transferred_endpoint_attributes_receiver_role`. Skipping close of the duplicate pidfd must fail `descriptor_cleanup`. Each mutant must exit 1.
- [ ] **Step 6: Commit:** "Add bounded supervisor channel receiver with per-message sender identity".

### Task 3: Selection record, specification and evidence

**Files:**
- Modify: `openspec/changes/add-linux-host/local-supervisor-profile.md`: in the transport section, state that q24 selected the restricted profile. Keep every listed limit, and add links to Tasks 1 and 2.
- Modify: `openspec/changes/add-linux-host/specs/linux-host/spec.md`: add two scenarios under LH-011:
  - "A transferred administrative endpoint does not carry its role": the receiver attributes the actual sender's retained role, or denies.
  - "An unprovisioned sender is not attributed": the record is denied, and no `from` is attached.
- Modify: `openspec/traceability/linux-host.md`: map the two scenarios to the named tests in Tasks 1 and 2, and keep native host qualification as a reviewed-only gap.
- Create: `verification/linux-supervisor-channel/README.md`, plus captured outputs (focused Bend, full suite, native, test run, repeats, mutants, environment). Lead with the concrete example and the current gap.
- Modify: `VERIFICATION.md` (one paragraph linking the record) and `verification/source-sha256.txt`, which you refresh last.

- [ ] **Step 1: Write the doc and spec changes.** Then run `openspec validate --all --strict --no-interactive`. Expected: every item passes.
- [ ] **Step 2: Write the evidence README.** State plainly what this does not establish: no capable-sender test, no exec decision, no namespace or ptrace isolation, no supervisor wiring or Bend pipe frame, no host qualification. Copy those limits from `verification/linux-channel-identity/README.md`.
- [ ] **Step 3: Refresh the manifest, run `git diff --check`, and commit:** "Record supervisor channel receiver selection and evidence".
