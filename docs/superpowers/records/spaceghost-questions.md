# Questions for Spaceghost

This repository copy tracks questions from the board (q1, q6, q17 and q18). A [recovered q18 answer](questions/q18.answers.jsonl) is recorded as submitted by Josh with `from: spaceghost` on 2026-11-05. Its explicit answers and the remaining questions are distinguished below; the record itself remains the source for the full text.

## 1. Genode: where should the monitor run? (q1, 2026-11-04)

The Genode port has one Bend monitor component per channel set, with the shim's `Writ_channel` service binding one descriptor per session from the parent's route subject (`hosts/genode/monitor/Monitor.bend`, `hosts/genode/effects/Channel.md`). The recovered q18 answer selects the monitor one level up, with clients under a nested init, as the reference layout. The previously described implementation runs the monitor beside the clients under one init; this choice does not itself implement or qualify the nested layout.

## 2. The buckets runtime (q6, 2026-11-04)

You described "a datacentric Rust of sorts, not a programming language, but buckets and code for the buckets as a runtime built to be cache-friendly and speedy when typed". The Genode channel lane built one concrete piece of that shape: fixed-width record slots a client appends to and reads from, with the monitor's loop as the only code attached (`hosts/genode/effects/Channel.md`, `hosts/genode/monitor/Monitor.bend`). Josh ruled that nothing is drafted before a brainstorm with you. The recovered answer supplies direction for that conversation, but does not record that the brainstorm occurred or settle a complete design:

- Typing depends on the bucket's mode: the answer names the bucket for typed mode, the type for `anytype`, and the record or fields for `notype`; it also mentions files in S3-compatible buckets. Width and representation still need discussion.
- Code authorship is determined by cryptographic signing; the answer describes possible execution by the bucket owner, the system on behalf of the source-data and bucket owners, or the data owner. Execution still needs permissions, and computing near the data is preferred.
- Buckets are runtime constructs, not durables; they are view-like, need not live in the main storage system, and may later be materialized from disk. The answer compares payment rules to HTTP and S3 bucket configuration; concrete query and payment semantics remain to be worked out.
- Put as much policy as possible in Bend; use runtime mechanisms to actuate the system rather than implementing Bend policy in the runtime.

## 3. Unikraft: the ingress transport for task 2.1 (q17, 2026-11-05)

Task 2.1 of `add-unikernel-library-runtime` stays open: the `IO.print` twin is missing, and the ingress subject is set by scaffolding (COM2 over a Unix socket; the client could forge it; UL-008 unmet). Josh ruled on 2026-11-05 that the transport decision is yours before any proposal. The recovered q18 answer defers the choice until the portable host contract fixes the subject shape; it does not select a transport. The two shapes seen so far:

- A virtio channel (virtio-console or virtio-serial) where the host side labels each port and the guest reads the subject from the port, never from the frame. Needs a virtio driver in the image (none today) and a host-side harness that owns the labels.
- A descriptor-driven COM2 where the subject is attached outside the guest by the harness that opens the socket, and the guest's frame carries only the record. Smaller change; the subject's authenticity then rests on the harness, which is outside the trusted base statement in `verification/unikernel-appliance-rules.md`.

Evidence for the current state: `docs/UNIKERNELS.md` (Open list), `hosts/unikraft/INVENTORY.md`, `verification/unikernel-channel-qemu.txt`. The change is held from archive until 2.1 is built.

## 4. Other recovered answers and outstanding q18 items

The recovered answer confirmed the original three-lane bucket, which the later q18 notes say had already landed. It says Spaceghost has the Windows machine and will run Windows lanes from written plans. That answer is not access to the machine, a completed run, or host qualification. Drift's bootable-kernel timing is unknown, so planning should not assume a date.

The recovered answer contains no veto fields for q18 item 7's single-use-approval and effective-subject rulings. The absence of checkbox fields is not an affirmative approval or a veto; preserve the existing laws and their stated review status. It also contains no selections for items 8–10: who approves audit read/export grants, whether the approved rendezvous quote is a ceiling or exact, and whether the Linux broker should later converge with the mounted-view canary. The controller notes adding those items appear after the answer in the JSONL file, but their 14:32–14:36Z timestamps precede the answer's 17:26Z timestamp. The missing selections leave those decisions open. The separate q19 choice of synthetic Linux identity cases does not resolve the convergence question or qualify the host.
