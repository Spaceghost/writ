# Questions for Spaceghost

Open items that need Spaceghost's call, collected from the board questions (q1, q6, q17). The brief document shared earlier carries the same list; this file is the repository copy so nothing depends on a chat link.

## 1. Genode: where should the monitor run? (q1, 2026-11-04)

The Genode port has one Bend monitor component per channel set, with the shim's `Writ_channel` service binding one descriptor per session from the parent's route subject (`hosts/genode/monitor/Monitor.bend`, `hosts/genode/effects/Channel.md`). Two layouts are possible: the monitor as a child of the same init that routes the clients, or the monitor one level up with the clients confined under a nested init. The second keeps the route subjects out of the clients' reach by construction; the first is what runs today. Which layout is the reference one for the capability profile?

## 2. Which changes come next? (q6, 2026-11-04)

Twenty-four changes under `openspec/changes/` have no task started. Josh wants the next buckets chosen in a brainstorm with you rather than by the controller. The candidates that build on what exists: the host changes (`add-genode-host`, `add-linux-host`, `add-windows-host`, `add-drift-kernel-host`, `add-portable-host-contract`) and the runtime ones (`add-freestanding-bend-runtime`, `validate-physical-gpu-execution`). The policy-side changes (`add-addressable-views`, `add-authenticated-grant-issuance`, `add-controlled-disclosure`, and the rest) stand on their own.

## 3. Unikraft: the ingress transport for task 2.1 (q17, 2026-11-05)

Task 2.1 of `add-unikernel-library-runtime` stays open: the `IO.print` twin is missing, and the ingress subject is set by scaffolding (COM2 over a Unix socket; the client could forge it; UL-008 unmet). Josh ruled on 2026-11-05 that the transport decision is yours, together with items 1 and 2, before any proposal. The two shapes seen so far:

- A virtio channel (virtio-console or virtio-serial) where the host side labels each port and the guest reads the subject from the port, never from the frame. Needs a virtio driver in the image (none today) and a host-side harness that owns the labels.
- A descriptor-driven COM2 where the subject is attached outside the guest by the harness that opens the socket, and the guest's frame carries only the record. Smaller change; the subject's authenticity then rests on the harness, which is outside the trusted base statement in `verification/unikernel-appliance-rules.md`.

Evidence for the current state: `docs/UNIKERNELS.md` (Open list), `hosts/unikraft/INVENTORY.md`, `verification/unikernel-channel-qemu.txt`. The change is held from archive until 2.1 is built.
