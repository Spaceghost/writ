# Writ requirements and implementation coverage

This document maps Writ's design requirements to the Bend 2 library. All authored
implementation, tests, examples, and proofs use Bend 2. Correct enforcement takes
priority over initial throughput.

**Status vocabulary:** implemented means executable library behavior; modeled
means protocol/state semantics without the corresponding operating-system
effect; deferred means code is not included. These are not deployment claims.

## 1. Governing rules

1. Every protected read participates in an approved operation with an approved
   destination write. Read and write authority remain separate.
2. The plan binds the full ordered source manifest and versions, destination,
   operation identity and kind, invocation, and current authority/policy epochs.
3. Copies and derived data retain all contributing origins. Transforming bytes
   does not remove confidentiality, integrity, operation, or payment restrictions.
4. Control over a destination or intermediate bucket cannot amplify origin rights.
5. Every required origin must approve a negotiated transformation. A successful
   sample is evidence about a candidate, never permission to drop restrictions.
6. A final write requires current authority and independently checked constraints.
   A denied transition preserves the supplied authoritative state.
7. The capability POSIX interface comes first; S3 and hosted transformation
   languages follow the same authority path when their adapters are implemented.

The governing rule is **no amplification**: control of an intermediate bucket
does not grant authority to widen its origins' permissions. No declassification
or endorsement exception has been added.

## 2. Traceability

| ID | Requirement | Implementation and evidence | Status and boundary |
| --- | --- | --- | --- |
| B01 | All system logic and verification in Bend 2 | `DataOS`, `Core`, `Transfer`, `Dlm`, `Frontend`, `Negotiation`, `Ledger`, `Backplane`, GPU wrappers, examples, tests, and proofs; 28 `.bend` files | Implemented for this library. Compiler/runtime, drivers, and host facilities remain external dependencies. |
| B02 | Data and operations are the programming model | `Core.Graph` represents type domains, data/control dependencies, and effects; `Transfer.Plan` binds exact source versions to an operation and destination. `CoreTests` checks types, propagation, cycles, and actual sink effects. | Implemented finite constraint model. Whole-program extraction from arbitrary hosted languages is deferred. |
| B03 | Read-security and write-security are separate domains | `Transfer.ReadDomain`, `WriteDomain`, `ReadGrant`, and `WriteGrant`; `Transfer.admit` matches both against the same complete scope. `TransferTests` exercises domain, manifest, version, operation, and expiry mismatches. | Implemented admission. Neither domain derives from possession of the other. |
| B04 | Cannot mint a read without an approved write | `Frontend.checked_plan` calls `Transfer.admit` even for a read request. `FrontendTests`: "read request still requires destination write approval". Missing either grant denies operation admission. | Effective-read pairing is implemented. Grant issuance and token registration are external; there is no authenticated minting API in this package. See section 3. |
| B05 | ROT13, copying, summaries, and transformations cannot launder data | `Transfer` joins labels and retains origin records; `Core` propagates data/control dependencies; `Backplane` checks the combined output against the actual destination. `TransferTests`: "ROT13 or summary cannot clear confidentiality"; `BackplaneTests` rejects forged labels and additional control influence. | Implemented over the complete authoritative manifest/graph. There is no byte-similarity detector or semantic claim that a named summary is harmless. |
| B06 | Owning a typed bucket cannot widen inherited rights | `Transfer.required_origins` rejects erased origin labels or amplified operation rights; output rights are intersected. `Backplane.WriteIntent` retains origins, labels, schema, and operation limits. | Implemented decisions and output metadata. The storage adapter must persist and reload those facts without accepting caller replacements. |
| B07 | Conditions can include payment | `Transfer.PaymentWitness` binds each required origin payment to the plan's invocation, operation, destination, quote, and expiry. `Ledger` reserves and consumes the reader's negotiated budget. `TransferTests`, `LedgerTests`, and `NegotiationTests` cover scope, missing payment, replay, and revocation. | Implemented prerequisites and accounting model. Witness authentication and real settlement are external. Source payment obligations and execution reservations are separate checks. |
| B08 | Use the Jif decentralized label subsystem | `Dlm.flows` checks owner-sensitive confidentiality and integrity, delegation closure, joins/meets, and authority epochs. `DlmTests` covers the two flow directions and malformed authority. | Implemented finite DLM fragment: top, bottom, and up to 30 named principals. Compound/dynamic principals and the Jif compiler are not included. |
| B09 | Massively parallel GPU type/policy calculation | `GpuLibrary.solve`, `label_batch`, and `transfer_batch` call Bend device-requesting paths; balanced work trees expose independent work. `PropertyTests` compares both graph producers against a separate closure oracle. | GPU-directed source is implemented. Native CPU fallback and JavaScript were tested; physical GPU execution, device compilation, and performance were not verified. |
| B10 | Independent verification backplane | `Core.verify` checks original graph facts and every constraint independently of the producer's sweep. `Backplane.commit` combines current authority, provenance, schema, effect, DLM, budget, and ledger checks. | Implemented. Algorithmic independence does not isolate monitor memory from a compromised runtime or driver. |
| B11 | Multiparty transformation negotiation and reauthorization | `Negotiation` fixes code, checks a fresh challenge, gates protected samples, checks all origin approvals, reserves the reader's budget, and rechecks authority at start; `Backplane` rechecks it at commit. `NegotiationTests` rejects missing owners, stale evidence, skipped stages, and revoked budgets. | Implemented state machine for one candidate per session. Running samples, comparing competing candidates, and scheduling executors are deferred. |
| B12 | Unpredictable sample challenges | `Negotiation.random_nonce` obtains eight U32 words through Base's random effect; challenge records must be bound to the plan and issued after candidate pinning. `sample_permit` must precede protected execution. Tests reject an old nonce paired with a fresh duplicate challenge ID. | Challenge generation helper and evidence checks are implemented. The trusted host must generate/register fresh challenges and confine sample execution; there is no sample executor here. |
| B13 | Mount a capability through a POSIX character-device interface | `Frontend.mount/open/dup/attenuate/close/checked_plan` model subject-bound tokens, handles, rights, revocation, and exact plan resolution. `DataOS.commit_from_capability` connects the descriptor to final commit. `FrontendTests` has 70 checks; `FacadeTests` has 10. | Modeled. These are Bend records, not OS file descriptors, a kernel character device, a mounted filesystem, or a complete POSIX ABI. |
| B14 | State machines with possible AI/Trealla proposals | Immutable requests, revisions, and guarded transitions govern `Negotiation`, `Ledger`, and `Frontend`. All authorization decisions are deterministic given trusted state. | Implemented state machines. AI/Trealla may later propose plans or evidence; their adapters and runtimes are deferred and gain no authority from proposing. |
| B15 | POSIX first, S3 afterward | Both belong behind `DataOS.commit_from_capability` and the backplane's scoped output intent. | Ordering recorded. Neither a live POSIX adapter nor an S3 server is included. |

## 3. Precise integration obligations

### Read issuance versus read use

The library currently denies **use** of a read when its paired write approval is
absent or out of scope. It does not generate or authenticate source grants.
`Frontend.mount` registers a protocol handle against an existing trusted
capability registry; it is not the protected read and does not call transfer
admission. The handle cannot authorize an operation until `checked_plan` succeeds.

To satisfy the stronger *issuance* rule literally, the eventual authority service
must only register a new effective read grant after checking the paired write
approval for that same immutable plan. It must authenticate both issuing domains,
publish issuance atomically against current revisions, and keep use-time checks
in place for later revocation. Public Bend record constructors cannot enforce
that service boundary by themselves.

### Negotiation and the reader's expense

The implemented order is:

`Proposed → CandidateFixed → Challenged → Sampled → OwnersApproved → Reserved → Running → Committed`

Pinning fixes the candidate identity requested; registered operation approval is
checked by `Transfer.admit` before protected sampling and execution. A passing
sample cannot skip origin approval or the final gate. Tests do not establish
that sampling detects every malicious transform.

The main execution reservation occurs after sampling. Protected sample admission
checks applicable source payment witnesses, but there is no separate sample
compute reservation. If candidate trials must also be paid from the reader's
budget, the future executor must use an explicitly scoped reservation before
each trial. The current main execution hold must not be described as paying for
earlier samples automatically. Competitive candidate selection is also outside
the present one-session state machine. `Plan`, `Session`, and `Binding` currently
have no executor/provider identity field. A future rendezvous service must bind
the selected, authenticated executor to the approved operation and execution
receipt; code identity alone does not identify who ran it.

### POSIX and actual anti-exfil enforcement

A real host must authenticate callers, own the live registries and ledger, derive
the complete data/control source manifest, and confine each worker's effects.
Protected plaintext cannot be handed to a process that retains an unchecked
socket, log, inherited descriptor, shared-memory route, or device access. A
capability filesystem alone does not impose those restrictions.

The trusted executor must bind the actual code/configuration and actual output
bytes to the pinned operation and sealed artifact identity. The write adapter
must expose only that artifact and atomically persist the accepted output,
inherited policy, session, and ledger transition (or an equivalent durable
transaction protocol). The pure library returns an intent; it does not perform
those effects. Physical camera capture is outside the requested machine-mediated
scope, not a reason to weaken the machine-mediated checks.

### Detection and proof scope

The current library detects invalid proposals and state transitions by returning
denials; it does not provide a live exfiltration sensor or durable audit service.
Any future denial/audit output must itself respect the information-flow policy.
The three declared formal laws concern guards and preservation of denied state.
They are not a proof of whole-system noninterference. Bend's checker passed;
independent Lean kernel verification remains unavailable in the recorded setup.

## 4. Verification evidence

The 28 Bend source files match the recorded verification: **638 checks passed
on each of the JavaScript and native CPU backends**. The verification record
distinguishes those results from unperformed physical GPU and independent
proof-kernel validation.

Read `VERIFICATION.md` for execution evidence and `DESIGN.md` for the adapter
contract. The package hash manifest covers the updated documentation as well as
the unchanged tested source.

The DLM reference is Cornell's
[Jif decentralized label model](https://www.cs.cornell.edu/jif/doc/jif-3.0.0/dlm.html).
The finite coverage above describes this implementation, not all of Jif.
