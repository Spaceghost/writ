# Optional rclone remote traceability

This contract covers the bounded local reference in `contrib/rclone/`, not a
qualified host platform or production storage service. Counts and captured logs
are in its [verification record](../../contrib/rclone/VERIFICATION.md).

| Requirement | Implementation | Evidence and limits |
| --- | --- | --- |
| RC-001 | Independent `contrib/rclone/go/go.mod`; Bend `Authority`, `Model`, `Application`, `Server` | Root 638-check suites run independently on both CPU backends; source inventory finds no root Go module or new core import |
| RC-002 | `Wire.parse`, `Transport.read`, `Application.accept`, `Model.valid_path` | `WireTests` 19 parser/framing checks; `WireBoundaryTests` 14 large-input checks; `ApplicationTests` wrong-token denial for reads and writes with complete state preservation |
| RC-003 | `Model.put`, `Authority.imported_policy`, `Digest.digest_hex` | `Tests` private-only ingress, immutable version/ID behavior, maximum import and digest; `DigestTests` 25 binary/vector/boundary checks; `Integration` real 64 KiB upload with independently known SHA-256 |
| RC-004 | `Authority.authorize_copy` through `DataOS.commit_from_capability`; `Model.copy_intent` | `Tests` accepted copy, retained policy, exact plan/artifact association, stale versions, revoked registry, public denial; `Integration` actual rclone managed copy and same-size update |
| RC-005 | `Application.dispatch` OPEN denial; Go `Object.Open`, `Fs.Copy`, terminal errors | `ApplicationTests` Open and unsupported operations preserve state; Go `TestNineFieldEnvelopeAndDenial` and `TestOpenNeverReturnsAReader`; `Integration` cat, public copy, forced manual fallback, and delete failures with empty stdout |
| RC-006 | `Model.immutable_request`, `same_request`, `save`, replay dispatch | `Tests` exact replay, changed payload/path/version/request-ID scope, replay after overwrite, full-body retry, and no receipt on denial; README/PROTOCOL state that restart discards every receipt |
| RC-007 | Model capacity/path checks; Presenter metadata; bounded Transport; Go response parser | `Tests` exact object/storage/version/directory limits; `ApplicationTests` redacted metadata and 512-entry maximum listing; Go tests cover response bounds, complete listing, missing END, stalled peer, and malformed response; token-holder metadata audience is an explicit host assumption |
| RC-008 | README, PROTOCOL, verification record, separate CLI entry point | Build and examples exercised; content/provenance comparison reviewed against pinned rclone implementation; fixed authority, memory-only storage, absent plaintext mount/restore, and unqualified host scope explicitly disclosed |

The authority helper uses a service-owned fixed standing profile and
transaction-local logical time. Its adversarial registry test establishes that
the existing final gate checks that supplied current registry; it does not
implement an external revocation feed. No test here establishes durable replay,
multi-user subject authentication, arbitrary worker confinement, physical GPU
isolation, or a native Genode/Windows port.
