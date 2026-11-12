# S3 desktop app traceability

Contract: [SDO requirements](../changes/add-s3-desktop-overlay/specs/s3-desktop-overlay/spec.md).
Profile: authenticated local workspace owner, ordinary local files and real S3
storage. This is not a protected desktop or multi-organization issuer.

| Requirement | Implementation | Executable evidence | Remaining qualification |
| --- | --- | --- | --- |
| SDO001 | `Model` records; broker S3 import, `keep`, native snapshots and `syncWorking` | `Smoke.mjs`: metadata-only browse, real ordinary file, normal save, fresh-instance reconstruction, exact-ETag import | Multi-file FUSE/Cloud Files placeholders and native overlay icons are unimplemented. |
| SDO002 | `Authority.authorize`, `DataOS.commit_from_capability`, `Model.reserve`, inherited full `OutputPolicy` | `AuthorityTests.bend`, `ModelTests.bend`; native denial with zero destination payload, allowed copy/provenance, refused second copy, current-rule restore, disabled source | Owner assertions do not establish external grant issuance, residency or desktop confinement. |
| SDO003 | `app.mjs` bounded authenticated loopback API, `ui/*`, DPAPI/private configuration | `BrowserSmoke.mjs`: connection, copy/refusal, edit, restrictions, restore, Activity, origin checks, no secrets; native status/credential checks. Packaged Edge/Windows and Chrome/Linux workflows and installed launchers pass in run `43152175554`. | Real external-provider account testing and arbitrary-editor confinement remain separate. |
| SDO004 | Bend reserve/confirm; native private stage, conditional catalog, immutable object and readback | Native competing clients, process termination/recovery, exact import and local-removal preservation; canonical catalog mutation rejected | Power-loss, malicious storage authentication, automatic pruning and user conflict-resolution choices unqualified/unimplemented. |
| SDO005 | Existing generator and platform packagers; `Lifecycle.mjs`; `S3Fixture.py` on each OS | Repeated generated/native/package byte comparison, bundled Node tests, actual SeaweedFS checks, native launcher and uninstall probes. Tag run `43153009821` passes; Preview.4 installers, portable packages and evidence pass anonymous download, checksum and source checks. Linux public assets match the packages exercised on Fedora. | These ordinary-folder packages do not qualify remote OS placeholders or a protected host. |

Detailed results are in [the execution record](../../verification/s3-desktop-overlay/README.md).
Existing Cloud Files/FUSE and Windows tray/directory-sync qualification remains
separate and must continue passing. Pure model tests do not replace native gates.
