# rclone contribution tasks

These tasks cover the bounded local contribution only. Existing production
adapter and durable-publication tasks remain separate and unchanged.

## 1. Bend reference

- [x] 1.1 Add canonical bounded wire parsing and token-authenticated loopback dispatch.
- [x] 1.2 Add authoritative private ingress, immutable versions, real payload digests, and exact in-memory request receipts.
- [x] 1.3 Route managed copies through the existing Writ facade and retain its artifact and inherited policy.
- [x] 1.4 Add scoped metadata, listings, policy views, and receipt inspection without plaintext reads.

## 2. rclone adapter

- [x] 2.1 Add a separate pinned Go module implementing rclone interfaces and bounded transport.
- [x] 2.2 Enforce terminal denials, version preconditions, SHA-256 reporting, and the supported feature subset.

## 3. Evidence and documentation

- [x] 3.1 Run Bend model, parser, and digest checks on JavaScript and native CPU; run Go transport checks and real CLI integration checks.
- [x] 3.2 Document commands, limits, trust assumptions, and traceability; validate OpenSpec strictly and record unchanged core regression evidence.

Acceptance evidence: [contribution verification](../../../../contrib/rclone/VERIFICATION.md)
and [requirement traceability](../../../traceability/rclone-contrib-remote.md).
