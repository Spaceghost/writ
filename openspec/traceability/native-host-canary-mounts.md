# Native host canary mount traceability

Contract: [native-host-canary-mounts](../specs/native-host-canary-mounts/spec.md).
Implementation and scope: [native contribution](../../contrib/native-hosts/README.md).
Execution: [common and native records](../../contrib/native-hosts/VERIFICATION.md).

The profile is one immutable public fixture, one retained native reader lifetime
and read-only observation. The fixed local standing policy is not an external
issuer. This table separates executable checks from reviewed mechanics and
broader product gaps. Earlier failed native runs remain in the platform records.

| Requirement | Bend/source mapping | Named evidence and limits |
| --- | --- | --- |
| NM001 Shared Bend decisions | `MountAuthority.authorize`, `Mount.dispatch`; private generated-module calls in Node/QuickJS | `check_full_capability_commit_admits_reader`, retained receipt checks, 69 shared decision vectors; per-host execution records identify the actual runtime. Native source inventories identify ABI/resource/probe code; general machine-code Bend portability is not claimed. |
| NM002 Exact immutable public input | `Mount.initialize`, shared `Sha256.digest_hex`; Linux sealed memfd, Windows frozen buffer, Genode private ROM copy | `check_actual_sha_256_binds_init_bytes`, `check_different_payload_changes_seal`, `check_full_64_kib_payload_accepted`, `check_payload_byte_cap_enforced_before_hashing`, `check_init_cannot_replace_registered_bytes`; native exact-byte reads and Linux sealing probes. Independent original-path mutation is reviewed from retained-buffer ownership, not claimed as a universal source-version transaction. |
| NM003 Full commit before observation | `MountAuthority.descriptor` calls `DataOS.commit_from_capability`; `Granted` retains session, ledger and intent | `check_complete_commit_and_origin_policy_retained`, `check_source_seal_matches_retained_intent`, `check_public_destination_refused_by_full_gate`, `check_revoked_registry_refused_at_commit`, duplicate-admission and pre-admission metadata tests. No fresh issuer, time feed or public-record authentication is inferred. |
| NM004 Native identity and metadata | `Mount.admitted`, `metadata_checked`, per-host process/session binding and fixed-name ABI handling | Model actor/stat/list/open denials; Linux real same-UID caller denials before/after warm lookup; Windows actual token/PID/lifetime and wrong-process probes; Genode stranger/forged-prefix sessions, exact names and foreign handles. PID recycling itself is not forced by the fixture; lifetime checking is reviewed. Windows retained read context is not fresh per-read PID authentication. |
| NM005 Bounded handles and revocation | `has_capacity`, `open_limit`, `find_handle`, `read_count`, `close`, `revoke`, `dispatch_budget` | Shared closed/foreign/root handles, range/EOF, counter limits and terminal phase tests; native retained-handle revocation and cleanup. Genode raw RPC/packet tests exercise malformed descriptors and the 32-handle limit. No claim of erased plaintext or unrestricted mappings is made. |
| NM006 Private canonical transport | `Mount.parse`; Node bounded input; native pipe readers; Genode `Policy::parse/command` | Nine real Node subprocess tests; Linux native malformed/sequence/timeout probes; Windows native fake-peer and bounded real-Bend probes; Genode in-process strict replies and poisoned runtime. The worker has no generic monitor-dispatch route. |
| NM007 Native presentation evidence | Windows WinFsp callbacks, Linux libfuse callbacks, Genode File_system RPC/packet streams and libc/VFS | Each platform's native record links actual reads and denials, pinned source and OS/base. Passing compilation or the common model alone is never counted as mounted support. Native Genode CI passes the 782-core corpus, all 69 mount vectors and 24 allocator assertions, plus 56 filesystem-session and eight libc/VFS assertions. Linux CI also passes with the 782-check core. Windows mounted reads and revocation pass within an overall failed workflow; confinement is reported separately. |
| NM008 Scope confinement and cleanup claims | Per-host launch/resource inventory and fixed native probes; explicit refusal/teardown paths | Linux configured kernel controls, real interpreter/broker death and missing-control refusal; Windows separately recorded LPAC/WFP and ordinary-process controls, with byte-worker network/clipboard/COM evidence incomplete; Genode explicit supervisor routes and diagnostic-client limits. Windows' no-data diagnostic helper has a different profile and does not qualify the byte worker. The standalone `writfs-init-diagnostic` shares launcher checks but has a different executable, package, process and handles; its initializers and `init-report-framing` synthetic test are not Windows acceptance evidence. The standalone [Windows run 42313767360](../../docs/superpowers/records/2026-11-06-windows-init/run-42313767360/README.md) reproduced initializer errors without fixture data; it supplies no byte-worker confinement evidence. Cleanup only removes resources owned by the fixture. Durable audit, production enrollment, arbitrary applications and broader host gates remain pending. |

## Evidence interpretation

The 69 pure vectors produce 70 PASS lines through `MountTests.main` because it
also verifies that its exported count matches the test list. After integrating
master `58cdbfa4c239de048467bd838e636fe2eab490c6`, the local JavaScript and
native CPU core runs separately produce 782 PASS lines and 41 HostBinding
vectors, with byte-identical outputs. Its six ordinary laws do not prove the
C/C++ bindings, native confinement, issuer or durable publication. The prior
638-core and 764-core native snapshots remain historical evidence for their
exact sources. Linux run 41776660115 and native Genode run 41776659987 provide
separate native CI evidence of the integrated 782-check core.

Windows run 41778041710 is retained as an overall failure despite passing
mounted-read and revocation checks. Its byte-worker network, clipboard and COM
probes remain incomplete. The separate no-data LPAC helper, with registry-read
capability and Win32k enabled, passes seven configured diagnostic probes both
with and without WFP; that result does not replace the byte worker's missing
qualification.

The native canary contribution does not complete `add-portable-host-contract`,
`add-windows-host`, `add-linux-host`, `add-genode-host`,
`add-genode-capability-adoption`, the machine-code runtime proposals, or the
WritFS namespace/issuer/durable-publication changes. Their task lists retain
their independently established evidence and remaining gaps.
